import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const html = readFileSync(new URL('../force-app/main/default/staticresources/Hello.resource', import.meta.url), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
function mount() {
  const sent = [];
  const parent = { postMessage: (message, origin) => sent.push({ message, origin }) };
  let receive;
  const window = { parent, addEventListener: (name, listener) => { receive = listener; } };
  runInNewContext(script, { window, document: { documentElement: { scrollHeight: 68 } } });
  return { sent, parent, receive };
}

test('widget contains the requested single div without external assets', () => {
  assert.equal((html.match(/<div\b/g) ?? []).length, 1);
  assert.match(html, /<div style="border: 1px solid red; padding: 16px;">Hello from LWC<\/div>/);
  assert.doesNotMatch(html, /\b(?:src|href)\s*=/);
});

test('view initializes only with its parent, acknowledges, and reports its size', () => {
  const { sent, parent, receive } = mount();
  assert.equal(sent[0].message.method, 'ui/initialize');
  assert.equal(sent[0].message.params.protocolVersion, '2026-01-26');
  const data = { jsonrpc: '2.0', id: sent[0].message.id, result: { protocolVersion: '2026-01-26' } };
  receive({ source: {}, origin: 'https://attacker.example', data });
  assert.equal(sent.length, 1);
  receive({ source: parent, origin: 'https://host.example', data });
  assert.equal(sent[1].message.method, 'ui/notifications/initialized');
  assert.equal(sent[2].message.method, 'ui/notifications/size-changed');
  assert.equal(sent[2].message.params.height, 68);
  assert.equal(sent[1].origin, 'https://host.example');
  receive({ source: parent, data: { jsonrpc: '2.0', id: 2, method: 'ping' } });
  assert.equal(sent.at(-1).message.id, 2);
  receive({ source: parent, data: { jsonrpc: '2.0', id: 3, method: 'ui/resource-teardown' } });
  assert.equal(sent.at(-1).message.id, 3);
});

test('opaque origins work and unsupported UI versions are not acknowledged', () => {
  const { sent, parent, receive } = mount();
  receive({ source: parent, origin: 'null', data: { jsonrpc: '2.0', id: sent[0].message.id, result: { protocolVersion: 'unknown' } } });
  assert.equal(sent.length, 1);
  receive({ source: parent, origin: 'null', data: { jsonrpc: '2.0', id: sent[0].message.id, result: { protocolVersion: '2026-01-26' } } });
  assert.equal(sent.length, 3);
  assert.equal(sent[1].origin, '*');
});
