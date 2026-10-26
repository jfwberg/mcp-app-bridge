import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';

const html = readFileSync(new URL('../force-app/main/default/staticresources/McpLightningOutHost.resource', import.meta.url), 'utf8');
const source = html.match(/<script>([\s\S]*?)<\/script>/)[1];
function mount(enabled, effectiveOrigin = 'null') {
  const sent = [], logs = [];
  let receive;
  const parent = { postMessage: message => sent.push(message) };
  const element = { addEventListener() {} };
  // Run through diagnostic configuration without loading Salesforce or making network requests.
  const script = source.replace('__MCPAPP_CONFIG_KEY__', '"demo"')
    .replace('requestAnimationFrame(()=>setWidgetHeight(widgetHeight));start();', `configureDiagnostics(${enabled});`);
  runInNewContext(script, {
    window: { origin: effectiveOrigin }, location: { origin: 'https://widget.example' },
    document: { getElementById: () => element, referrer: 'https://host.example/chat?token=secret#secret' },
    parent, URL, crypto: webcrypto, console: { info: (...args) => logs.push(args) },
    addEventListener: (name, listener) => { receive = listener; }, setTimeout() {},
  });
  return { sent, logs, parent, receive };
}

test('origin diagnostics distinguish opaque origins and exclude referrer credentials', () => {
  const { sent, logs, receive, parent } = mount(true);
  assert.equal(sent[0].params.arguments.stage, 'WIDGET_EFFECTIVE_ORIGIN');
  assert.equal(sent[0].params.arguments.message, 'null');
  assert.equal(sent[1].params.arguments.message, 'https://widget.example');
  assert.equal(sent[2].params.arguments.message, 'https://host.example');
  receive({ source: {}, origin: 'https://untrusted.example' });
  assert.equal(sent.length, 3);
  receive({ source: parent, origin: 'https://parent.example', data: {} });
  receive({ source: parent, origin: 'https://parent.example', data: {} });
  assert.equal(sent.length, 4);
  assert.equal(sent[3].params.arguments.stage, 'HOST_MESSAGE_ORIGIN');
  assert.equal(logs.length, 4);
  const loadId = sent[0].params.arguments.loadCorrelationId;
  assert.match(loadId, /^load-[a-f0-9]{32}$/);
  assert.ok(sent.every(item => item.params.arguments.loadCorrelationId === loadId));
  assert.ok(logs.every(item => item[1] === loadId));
  assert.doesNotMatch(JSON.stringify({ sent, logs }), /secret|token|untrusted/);
});

test('separate widget mounts get separate load correlation IDs', () => {
  assert.notEqual(mount(true).sent[0].params.arguments.loadCorrelationId,
    mount(true).sent[0].params.arguments.loadCorrelationId);
});

test('disabled logging emits neither origin tool calls nor console output', () => {
  const { sent, logs, receive, parent } = mount(false);
  receive({ source: parent, origin: 'null', data: {} });
  assert.equal(sent.length, 0);
  assert.equal(logs.length, 0);
});

test('missing effective origin remains distinct from the literal null string', () => {
  const { sent } = mount(true, null);
  assert.equal(sent[0].params.arguments.message, 'unavailable');
});

test('loader uses selected same-org resource, defaults to hosted, and rejects other origins', async () => {
  const definition=source.match(/const loadScript=([^\n]+);/)[1];
  const scripts=[];
  const load=runInNewContext('('+definition+')',{
    URL, document:{createElement:()=>({addEventListener(name,callback){if(name==='load')this.loaded=callback;}}),head:{append(script){scripts.push(script);script.loaded();}}}
  });
  const org='https://example.my.salesforce.com';
  await load(org,org+'/resource/mcpapp__McpLo2Modified?v=2.2.5-origin-1');
  assert.equal(scripts[0].src,org+'/resource/mcpapp__McpLo2Modified?v=2.2.5-origin-1');
  await load(org);
  assert.equal(scripts[1].src,org+'/lightning/lightning.out.latest/index.iife.prod.js');
  await assert.rejects(load(org,'https://other.example/loader.js'),/Invalid Lightning Out loader origin/);
  assert.equal(scripts.length,2);
});
