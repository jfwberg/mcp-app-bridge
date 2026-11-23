<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Salesforce Lightning Out</title>
  <style>
    :root{font-family:Arial,sans-serif;color:#181818;--widget-height:560px}
    *{box-sizing:border-box}html,body{margin:0;min-height:var(--widget-height);background:#fff}
    body{display:flex;flex-direction:column;height:var(--widget-height);min-height:260px;overflow:hidden}
    #status{padding:12px 16px;background:#f3f3f3;border-bottom:1px solid #ddd;font-size:13px}
    #status.error{color:#ba0517;background:#fef1ee}#mount{flex:1;min-height:0;overflow:hidden}
    lightning-out-application,[data-mcpapp-component]{display:block;width:100%;min-height:100%;height:100%}
    #resize-handle{height:14px;flex:0 0 14px;cursor:ns-resize;background:#f3f3f3;border-top:1px solid #ddd;position:relative}
    #resize-handle:after{content:"";position:absolute;left:50%;top:5px;transform:translateX(-50%);width:42px;height:4px;border-radius:2px;background:#747474}
    #resize-handle:focus-visible{outline:2px solid #0176d3;outline-offset:-2px}
    #display-toggle{position:fixed;top:8px;right:8px;z-index:1000;width:30px;height:30px;display:grid;place-items:center;padding:6px;border:1px solid transparent;border-radius:5px;background:transparent;color:#999;cursor:pointer}
    #display-toggle[hidden]{display:none}#display-toggle:hover,#display-toggle:focus-visible{background:#f5f5f5;border-color:#ddd;color:#555}#display-toggle:focus-visible{outline:2px solid #0176d3;outline-offset:2px}#display-toggle:disabled{cursor:wait;opacity:.5}
    #display-toggle svg{width:16px;height:16px;fill:none;stroke:currentColor;stroke-width:1.5;stroke-linecap:round;stroke-linejoin:round}
    html[data-display-mode="fullscreen"],html[data-display-mode="fullscreen"] body{height:100%;min-height:0}
    html[data-display-mode="fullscreen"] #resize-handle{display:none}
  </style>
</head>
<body>
  <button id="display-toggle" type="button" aria-label="Expand widget" title="Expand widget" aria-pressed="false" hidden><svg viewBox="0 0 16 16" aria-hidden="true"><path id="display-icon" d="M6 2H2v4m8-4h4v4M2 10v4h4m8-4v4h-4"/></svg></button>
  <div id="status" role="status">Loading authenticated Salesforce interface...</div>
  <main id="mount" aria-label="Salesforce Lightning Out component"></main>
  <div id="resize-handle" role="separator" aria-label="Resize component height" aria-orientation="horizontal" aria-valuemin="260" aria-valuemax="1200" aria-valuenow="560" tabindex="0"></div>
  <script>
  (()=>{'use strict';
    const CONFIG={configKey:__MCPAPP_CONFIG_KEY__};
    const loadCorrelationId='load-'+Array.from(crypto.getRandomValues(new Uint8Array(16)),byte=>byte.toString(16).padStart(2,'0')).join('');
    const status=document.getElementById('status'),mount=document.getElementById('mount'),resizeHandle=document.getElementById('resize-handle');
    const pending=new Map(),queuedToolResults=[],inputWaiters=[],queuedDiagnostics=[];let sequence=0,widgetHeight=560,mountedComponent=null,inboundMappings=[],allowedInputNames=[],initialComponentInputs={},componentReady=false,inputObserved=false,diagnosticEnabled=null;
    const setStatus=(message,error=false)=>{status.hidden=false;status.textContent=message;status.className=error?'error':'';};
    const detached=value=>JSON.parse(JSON.stringify(value));
    const request=(method,params)=>new Promise((resolve,reject)=>{const id=++sequence;const timeout=setTimeout(()=>{pending.delete(id);reject(new Error(method+' timed out.'));},15000);pending.set(id,{resolve,reject,timeout});parent.postMessage(detached({jsonrpc:'2.0',id,method,params}),'*');});
    const notify=(method,params)=>parent.postMessage(detached({jsonrpc:'2.0',method,params}),'*');
    const displayToggle=document.getElementById('display-toggle'),displayIcon=document.getElementById('display-icon');
    let hostContext={},displayRequestPending=false;
    const updateDisplayContext=context=>{hostContext={...hostContext,...context};const fullscreen=hostContext.displayMode==='fullscreen',modes=hostContext.availableDisplayModes||[];displayToggle.hidden=!modes.includes(fullscreen?'inline':'fullscreen');displayToggle.disabled=displayRequestPending;const label=fullscreen?'Collapse widget':'Expand widget';displayToggle.setAttribute('aria-label',label);displayToggle.setAttribute('title',label);displayToggle.setAttribute('aria-pressed',String(fullscreen));displayIcon.setAttribute('d',fullscreen?'M2 6h4V2m4 0v4h4M6 14v-4H2m12 0h-4v4':'M6 2H2v4m8-4h4v4M2 10v4h4m8-4v4h-4');document.documentElement.setAttribute('data-display-mode',hostContext.displayMode||'inline');};
    displayToggle.addEventListener('click',async()=>{const mode=hostContext.displayMode==='fullscreen'?'inline':'fullscreen';if(displayRequestPending||!(hostContext.availableDisplayModes||[]).includes(mode))return;displayRequestPending=true;displayToggle.disabled=true;try{const result=await request('ui/request-display-mode',{mode});updateDisplayContext({displayMode:result.mode});if(result.mode==='inline')setWidgetHeight(widgetHeight);}catch(error){displayToggle.setAttribute('title','Display mode could not be changed. Try again.');}finally{displayRequestPending=false;displayToggle.disabled=false;}});
    addEventListener('message',event=>{if(event.source===parent&&event.data&&event.data.method==='ui/notifications/host-context-changed'){const previous=hostContext.displayMode;updateDisplayContext(event.data.params||{});if(previous==='fullscreen'&&hostContext.displayMode==='inline')setWidgetHeight(widgetHeight);}});
    const sendDiagnostic=(stage,outcome,message)=>request('tools/call',{name:'log_bridge_diagnostic',arguments:{configKey:CONFIG.configKey,loadCorrelationId,stage,outcome,...(message?{message:String(message).slice(0,255)}:{})}}).catch(()=>{});
    const diagnostic=(stage,outcome='SUCCEEDED',message)=>{if(diagnosticEnabled===null){queuedDiagnostics.push([stage,outcome,message]);return;}if(diagnosticEnabled)sendDiagnostic(stage,outcome,message);};
    const originDiagnostics=[];
    const originOnly=value=>{if(value==null)return 'unavailable';if(value==='null')return 'null';try{const url=new URL(value);return /^https?:$/.test(url.protocol)?url.origin:'unavailable';}catch(error){return 'unavailable';}};
    const recordOrigin=(stage,value)=>{const origin=originOnly(value);originDiagnostics.push({stage,origin});if(diagnosticEnabled===true)console.info('[MCP App Bridge origin]',loadCorrelationId,stage,origin);diagnostic(stage,'SUCCEEDED',origin);};
    recordOrigin('WIDGET_EFFECTIVE_ORIGIN',window.origin);
    recordOrigin('WIDGET_URL_ORIGIN',location.origin);
    recordOrigin('WIDGET_REFERRER_ORIGIN',document.referrer);
    let parentOriginRecorded=false;
    const configureDiagnostics=enabled=>{diagnosticEnabled=enabled===true;const queued=queuedDiagnostics.splice(0);if(diagnosticEnabled){for(const item of originDiagnostics)console.info('[MCP App Bridge origin]',loadCorrelationId,item.stage,item.origin);for(const item of queued)sendDiagnostic(...item);}};
    addEventListener('message',event=>{if(event.source!==parent)return;if(!parentOriginRecorded){parentOriginRecorded=true;recordOrigin('HOST_MESSAGE_ORIGIN',event.origin);}const message=event.data||{};if(message.id!=null&&pending.has(message.id)){const item=pending.get(message.id);pending.delete(message.id);clearTimeout(item.timeout);message.error?item.reject(new Error(message.error.message||'MCP request failed.')):item.resolve(detached(message.result));return;}if(message.method==='ui/notifications/tool-input')dispatchComponentInputs(message.params&&message.params.arguments||message.params);if(message.method==='ui/notifications/tool-result')dispatchToolResult(message.params);});
    const setWidgetHeight=height=>{widgetHeight=Math.max(260,Math.min(1200,Math.round(height)));document.documentElement.style.setProperty('--widget-height',widgetHeight+'px');resizeHandle.setAttribute('aria-valuenow',String(widgetHeight));notify('ui/notifications/size-changed',{height:widgetHeight});};
    let dragY=0,dragHeight=widgetHeight;
    resizeHandle.addEventListener('pointerdown',event=>{dragY=event.clientY;dragHeight=widgetHeight;resizeHandle.setPointerCapture(event.pointerId);});
    resizeHandle.addEventListener('pointermove',event=>{if(resizeHandle.hasPointerCapture(event.pointerId))setWidgetHeight(dragHeight+event.clientY-dragY);});
    resizeHandle.addEventListener('keydown',event=>{const step=event.shiftKey?100:25;if(event.key==='ArrowUp'||event.key==='ArrowDown'){event.preventDefault();setWidgetHeight(widgetHeight+(event.key==='ArrowDown'?step:-step));}if(event.key==='Home'){event.preventDefault();setWidgetHeight(260);}if(event.key==='End'){event.preventDefault();setWidgetHeight(1200);}});
    const loadEmbeddedLoader=()=>{/*__MCPAPP_EMBEDDED_LOADER__*/return false;};
    const loadScript=(origin,loaderUrl)=>new Promise((resolve,reject)=>{if(loadEmbeddedLoader()){resolve();return;}const script=document.createElement('script');const url=new URL(loaderUrl||origin+'/lightning/lightning.out.latest/index.iife.prod.js');if(url.origin!==origin){reject(new Error('Invalid Lightning Out loader origin.'));return;}script.src=url.href;script.async=true;script.addEventListener('load',resolve,{once:true});script.addEventListener('error',()=>reject(new Error('The Lightning Out library could not be loaded.')),{once:true});document.head.append(script);});
    const eventPayload=detail=>{if(typeof detail!=='string')return detached(detail||{});try{return JSON.parse(detail);}catch(error){return {value:detail};}};
    const routeEvent=async(mapping,event)=>{event.stopPropagation();try{const result=await request('tools/call',{name:'bridge_event',arguments:{configKey:CONFIG.configKey,loadCorrelationId,mappingKey:mapping.key,payload:eventPayload(event.detail)}});const hostMessage=result&&result._meta&&result._meta['mcpapp/hostMessage'];if(hostMessage)await request('ui/message',hostMessage);}catch(error){setStatus(error&&error.message||'The component event could not be delivered.',true);}};
    const attributeName=name=>name.replace(/([A-Z])/g,'-$1').toLowerCase();
    const applyComponentInputs=inputs=>{for(const [name,value] of Object.entries(inputs||{})){if(!allowedInputNames.includes(name))continue;mountedComponent[name]=detached(value);const attribute=attributeName(name);if(value===false||value==null)mountedComponent.removeAttribute(attribute);else mountedComponent.setAttribute(attribute,typeof value==='string'?value:JSON.stringify(value));}};
    const observeInputs=inputs=>{inputObserved=true;initialComponentInputs={...initialComponentInputs,...detached(inputs||{})};while(inputWaiters.length)inputWaiters.shift()();};
    const dispatchComponentInputs=inputs=>{observeInputs(inputs);dispatchToolResult({structuredContent:{configKey:CONFIG.configKey,componentInputs:inputs||{}}});};
    const bootstrapFrom=value=>{if(typeof value==='string'){try{return bootstrapFrom(JSON.parse(value));}catch(error){return null;}}if(!value||typeof value!=='object')return null;if(value.frontdoorUrl&&value.orgOrigin)return value;if(value['mcpapp/bootstrap'])return value['mcpapp/bootstrap'];if(value['mcpapp/bootstrapError'])return {error:value['mcpapp/bootstrapError']};if(value._meta&&value._meta['mcpapp/bootstrap'])return value._meta['mcpapp/bootstrap'];if(value._meta&&value._meta['mcpapp/bootstrapError'])return {error:value._meta['mcpapp/bootstrapError']};return value.result?bootstrapFrom(value.result):null;};
    const waitForInputs=milliseconds=>inputObserved?Promise.resolve():new Promise(resolve=>{let settled=false;const finish=()=>{if(settled)return;settled=true;resolve();};inputWaiters.push(finish);setTimeout(finish,milliseconds);});
    const toolResultFrom=value=>{if(!value||typeof value!=='object')return null;if(value.structuredContent)return value;return value.result?toolResultFrom(value.result):null;};
    const dispatchToolResult=params=>{const result=toolResultFrom(params&&params.result||params);if(!result)return;const content=result.structuredContent;if(!content)return;const appliesToComponent=!content.configKey||content.configKey===CONFIG.configKey;if(content.componentInputs&&appliesToComponent)observeInputs(content.componentInputs);if(!componentReady||!mountedComponent){if((content.mcpappCommand||content.componentInputs)&&appliesToComponent)queuedToolResults.push(result);return;}if(!appliesToComponent)return;if(content.componentInputs)applyComponentInputs(content.componentInputs);const command=content.mcpappCommand;if(!command)return;const mapping=inboundMappings.find(item=>item.key===command.mappingKey);if(!mapping)return;mountedComponent.dispatchEvent(new CustomEvent(mapping.eventName,{detail:JSON.stringify(detached(command.payload||{})),bubbles:true,composed:true}));};
    const start=async()=>{try{
      const initialized=await request('ui/initialize',{protocolVersion:'2026-01-26',appCapabilities:{availableDisplayModes:['inline','fullscreen']},appInfo:{name:'mcpapp-bridge',version:'1.0.0'}});updateDisplayContext(initialized.hostContext||{});notify('ui/notifications/initialized',{});diagnostic('UI_INITIALIZED');
      const bootstrapResult=await request('tools/call',{name:'bootstrap_lightning_out',arguments:{configKey:CONFIG.configKey,loadCorrelationId}}),bootstrap=bootstrapFrom(bootstrapResult);
      if(bootstrap&&bootstrap.error)throw new Error(bootstrap.error.message||'The authenticated Salesforce interface could not be created.');
      if(!bootstrap||!bootstrap.frontdoorUrl)throw new Error('A fresh Salesforce UI session was not returned.');
      configureDiagnostics(bootstrap.loggingEnabled);
      diagnostic('BOOTSTRAP_RECEIVED');
      allowedInputNames=bootstrap.inputNames||[];if(allowedInputNames.length)await waitForInputs(1000);
      await loadScript(bootstrap.orgOrigin,bootstrap.loaderUrl);diagnostic('LIGHTNING_LIBRARY_LOADED');await customElements.whenDefined('lightning-out-application');
      const application=document.createElement('lightning-out-application');application.setAttribute('app-id',bootstrap.appId);application.setAttribute('components',bootstrap.componentName);application.setAttribute('frontdoor-url',bootstrap.frontdoorUrl);application.addEventListener('lo.application.error',event=>{const message=event.detail&&event.detail.message||'Unknown error.';diagnostic('APPLICATION_ERROR','FAILED',message);setStatus('Lightning Out application error: '+message,true);});mount.append(application);diagnostic('APPLICATION_ATTACHED');
      await customElements.whenDefined(bootstrap.componentName);const component=document.createElement(bootstrap.componentName);mountedComponent=component;inboundMappings=(bootstrap.eventMappings||[]).filter(mapping=>mapping.direction==='HOST_TO_LWC');component.setAttribute('data-mcpapp-component','');applyComponentInputs(initialComponentInputs);component.addEventListener('lo.component.ready',()=>{for(const mapping of bootstrap.eventMappings||[])if(mapping.direction==='LWC_TO_HOST')component.addEventListener(mapping.eventName,event=>routeEvent(mapping,event));componentReady=true;while(queuedToolResults.length)dispatchToolResult(queuedToolResults.shift());diagnostic('COMPONENT_READY');status.hidden=true;},{once:true});component.addEventListener('lo.component.error',event=>{const message=event.detail&&event.detail.message||'Unknown error.';diagnostic('COMPONENT_ERROR','FAILED',message);setStatus('Lightning Out component error: '+message,true);});mount.append(component);diagnostic('COMPONENT_ATTACHED');
    }catch(error){const message=error&&error.message||'The configured Lightning Out component could not be loaded.';diagnostic('WIDGET_ERROR','FAILED',message);setStatus(message,true);}};
    requestAnimationFrame(()=>setWidgetHeight(widgetHeight));start();
  })();
  </script>
</body>
</html>
