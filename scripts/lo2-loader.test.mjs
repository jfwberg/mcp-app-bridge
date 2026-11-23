import { readFileSync } from 'node:fs';
import { Script, runInNewContext } from 'node:vm';
import { test } from 'node:test';
import assert from 'node:assert/strict';
const resource=readFileSync(new URL('../force-app/main/default/staticresources/McpLo2Modified.resource',import.meta.url),'utf8');
const local=resource;
const helper=local.split('/* END LOCAL MODIFIED ORIGIN HELPER */')[0]+'globalThis.resolveOrigin=modifiedLo2Origin;})();';
function resolve(effective, requested=null) {
  const context={URL,window:{origin:effective},document:{currentScript:{getAttribute:()=>requested}}};
  runInNewContext(helper,context);
  return context.resolveOrigin();
}
test('packaged local modified loader compiles and contains the intended changes',()=>{
  new Script(resource);
  assert.equal((local.match(/loAppOrigin:modifiedLo2Origin\(\)/g)||[]).length,2);
  assert.ok(!local.includes('loAppOrigin:window.location.origin'));
  assert.ok(!local.includes('sourceMappingURL='),'Local loader must not request the upstream source map');
});
test('uses the inherited effective origin and accepts a matching override',()=>{
  assert.equal(resolve('https://host.example'),'https://host.example');
  assert.equal(resolve('http://localhost:8080','http://localhost:8080'),'http://localhost:8080');
});
test('rejects opaque origins and fake overrides',()=>{
  for(const [effective,override] of [['null',null],['null','https://host.example'],['https://host.example','https://other.example'],['https://host.example','https://host.example/path']])
    assert.throws(()=>resolve(effective,override),/Local modified LO2/);
});

const hostHtml=readFileSync(new URL('../force-app/main/default/staticresources/McpLightningOutHost.resource',import.meta.url),'utf8');
const hostScript=hostHtml.match(/<script>([\s\S]*?)<\/script>/)[1];
test('embedded loader compiles inside the widget script',()=>{
  const combined=hostScript.replace('__MCPAPP_CONFIG_KEY__','"demo"').replace('/*__MCPAPP_EMBEDDED_LOADER__*/',resource+'\nreturn true;\n');
  new Script(combined);
});
for(const enabled of [false,true]) test(`loader fetch is ${enabled?'skipped':'used'} with embedding ${enabled?'enabled':'disabled'}`,async()=>{
  const definition=hostScript.split('\n').find(line=>line.includes('const loadScript='));
  const requests=[];
  const context={URL,loadEmbeddedLoader:()=>enabled,document:{createElement:()=>({addEventListener(name,callback){if(name==='load')this.loaded=callback;}}),head:{append(script){requests.push(script.src);script.loaded();}}}};
  runInNewContext(definition+';globalThis.load=loadScript;',context);
  await context.load('https://example.my.salesforce.com');
  assert.equal(requests.length,enabled?0:1);
  if(!enabled)assert.equal(requests[0],'https://example.my.salesforce.com/lightning/lightning.out.latest/index.iife.prod.js');
});
