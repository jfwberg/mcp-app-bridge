import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
const html=readFileSync(new URL('../force-app/main/default/staticresources/McpLightningOutHost.resource',import.meta.url),'utf8');
function mount(){
  const sent=[],listeners=[],elements=new Map();
  const element=id=>{if(!elements.has(id))elements.set(id,{hidden:true,attributes:{},listeners:{},style:{setProperty(){}},setAttribute(k,v){this.attributes[k]=v;},addEventListener(k,v){this.listeners[k]=v;}});return elements.get(id);};
  const parent={postMessage:message=>sent.push(message)};
  const source=html.match(/<script>([\s\S]*?)<\/script>/)[1].replace('__MCPAPP_CONFIG_KEY__','"demo"').replace('requestAnimationFrame(()=>setWidgetHeight(widgetHeight));start();','');
  runInNewContext(source,{crypto:webcrypto,window:{origin:'null'},location:{origin:'https://widget.example'},document:{referrer:'',getElementById:element,documentElement:element('html')},parent,URL,setTimeout:()=>1,clearTimeout(){},addEventListener:(name,listener)=>listeners.push(listener)});
  const receive=(data,source=parent)=>listeners.forEach(listener=>listener({source,origin:'https://host.example',data}));
  const context=params=>receive({method:'ui/notifications/host-context-changed',params});
  return {sent,element,receive,context};
}
test('display toggle follows host modes, requests expand/collapse and restores inline height',async()=>{
  const {sent,element,receive,context}=mount(),button=element('display-toggle');
  context({displayMode:'inline',availableDisplayModes:['inline']});assert.equal(button.hidden,true);
  context({availableDisplayModes:['inline','fullscreen']});assert.equal(button.hidden,false);
  let click=button.listeners.click();assert.equal(sent.at(-1).method,'ui/request-display-mode');assert.equal(sent.at(-1).params.mode,'fullscreen');assert.equal(button.disabled,true);
  receive({id:sent.at(-1).id,result:{mode:'fullscreen'}});await click;
  assert.equal(button.attributes['aria-label'],'Collapse widget');assert.equal(element('html').attributes['data-display-mode'],'fullscreen');
  click=button.listeners.click();assert.equal(sent.at(-1).params.mode,'inline');receive({id:sent.at(-1).id,result:{mode:'inline'}});await click;
  assert.equal(button.attributes['aria-label'],'Expand widget');assert.equal(sent.at(-1).method,'ui/notifications/size-changed');
});
test('host can decline requests, change mode externally, and reject untrusted context',async()=>{
  const {sent,element,receive,context}=mount(),button=element('display-toggle');
  context({displayMode:'inline',availableDisplayModes:['inline','fullscreen']});
  const click=button.listeners.click();receive({id:sent.at(-1).id,result:{mode:'inline'}});await click;assert.equal(button.attributes['aria-pressed'],'false');
  context({displayMode:'fullscreen'});assert.equal(button.attributes['aria-pressed'],'true');
  receive({method:'ui/notifications/host-context-changed',params:{displayMode:'inline'}},{});assert.equal(button.attributes['aria-pressed'],'true');
  context({displayMode:'inline'});assert.equal(button.attributes['aria-pressed'],'false');
  const failed=button.listeners.click();receive({id:sent.at(-1).id,error:{message:'Unavailable'}});await failed;assert.equal(button.disabled,false);assert.match(button.attributes.title,/Try again/);
});
