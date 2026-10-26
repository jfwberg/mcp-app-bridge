// Rebuild from the inspected upstream file; never silently patch a different release.
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, '.tmp/lo2-inspection/index.iife.prod.js'), 'utf8');
const expectedHash = '1f9faa4fb36ad5cc67e36d3e879f4e4622f3ed646d59480b727b19fd8cd84f86';
if (createHash('sha256').update(source).digest('hex') !== expectedHash) throw new Error('Upstream hash changed; inspect before patching.');
const needle = 'loAppOrigin:window.location.origin';
if (source.split(needle).length - 1 !== 2) throw new Error('Expected exactly two origin assignments.');
const helper = `/* LOCAL MODIFIED Salesforce LO2 2.2.5 origin patch. Not an official Salesforce build.
Upstream SHA-256: ${expectedHash}
Two loAppOrigin assignments are replaced; the unavailable source-map reference is removed.
Upstream license notices retained.
This loader still contacts Salesforce and is not a fully offline runtime. */
(()=>{
const requestedOrigin=document.currentScript?.getAttribute('data-lo-app-origin');
function modifiedLo2Origin(){
  const effective=window.origin;
  const candidate=requestedOrigin||effective;
  let parsed;
  try{parsed=new URL(candidate);}catch{throw new Error('Local modified LO2: no usable effective origin.');}
  if(!/^https?:$/.test(parsed.protocol)||parsed.origin!==candidate||candidate!==effective)
    throw new Error('Local modified LO2: override must equal the real HTTP(S) effective origin.');
  return candidate;
}
/* END LOCAL MODIFIED ORIGIN HELPER */
`;
const patched = source.replaceAll(needle, 'loAppOrigin:modifiedLo2Origin()')
  .replace(/^\/\/[#@]\s*sourceMappingURL=.*$/gm, '');
const output = helper + patched + '\n})();\n';
for (const relative of ['.testdata/lo2/lo2-modified.js', 'force-app/main/default/staticresources/McpLo2Modified.resource']) {
  fs.mkdirSync(path.dirname(path.join(root, relative)), { recursive: true });
  fs.writeFileSync(path.join(root, relative), output);
}
console.log('Wrote identical local modified loader copies for local testing and Salesforce static resource.');
