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
