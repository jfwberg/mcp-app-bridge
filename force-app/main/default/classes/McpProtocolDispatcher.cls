/** Central JSON-RPC method dispatcher. */
public with sharing class McpProtocolDispatcher {
    private final McpLifecycleService lifecycle=new McpLifecycleService();
    public Object dispatch(Map<String,Object> request, RestRequest httpRequest, RestResponse httpResponse) {
        Object id=request.get('id'); String method=(String)request.get('method');
        if((String)request.get('jsonrpc')!='2.0'||String.isBlank(method)) throw new McpProtocolException(-32600,400,'Invalid Request.');
        Map<String,Object> params=request.get('params') instanceof Map<String,Object>?(Map<String,Object>)request.get('params'):new Map<String,Object>();
        if(McpModernProtocolService.isModern(request,httpRequest)) return new McpModernProtocolService().dispatch(request,httpRequest);
        if(method=='initialize') return adaptLegacyResult((String)params.get('protocolVersion'),method,lifecycle.initialize(params,httpResponse));
        Set<String> sessionMethods=new Set<String>{'notifications/initialized','ping','tools/list','tools/call','resources/list','resources/read'};
        if(!sessionMethods.contains(method)) throw new McpProtocolException(-32601,404,'Method not found.');
        Boolean stateful=lifecycle.hasSession(httpRequest);McpSession session;
        if(stateful){Boolean ready=method!='notifications/initialized'&&method!='ping';session=lifecycle.requireSession(httpRequest,ready);}
        String version=stateful?session.protocolVersion:lifecycle.requireStatelessProtocolVersion(httpRequest);
        Object result;
        if(method=='notifications/initialized'){ if(stateful)lifecycle.markInitialized(session); return null; }
        if(method=='ping') result=new Map<String,Object>();
        else if(method=='tools/list') result=McpToolRegistry.listTools();
        else if(method=='tools/call') result=McpToolRegistry.callTool(params);
        else if(method=='resources/list') result=McpResourceRegistry.listResources();
        else result=McpResourceRegistry.readResource(params);
        if(stateful)lifecycle.touchSession(session);
        return adaptLegacyResult(version,method,result);
    }
    /** Preserve November 2024 core schemas and bridge extension metadata. */
    @TestVisible private static Object adaptLegacyResult(String version,String method,Object result) {
        if(version!='2024-11-05' || !(result instanceof Map<String,Object>)) return result;
        Map<String,Object> value=(Map<String,Object>)result;
        if(method=='initialize') {
            Map<String,Object> serverInfo=(Map<String,Object>)value.get('serverInfo');
            serverInfo.remove('title');serverInfo.remove('description');
        } else if(method=='tools/list') {
            for(Object item:(List<Object>)value.get('tools')) {
                Map<String,Object> tool=(Map<String,Object>)item;
                tool.remove('title');tool.remove('annotations');tool.remove('outputSchema');
            }
        } else if(method=='resources/list') {
            for(Object item:(List<Object>)value.get('resources')) ((Map<String,Object>)item).remove('title');
        } else if(method=='tools/call' && value.containsKey('structuredContent')) {
            Object structured=value.remove('structuredContent');
            ((List<Object>)value.get('content')).add(new Map<String,Object>{'type'=>'text','text'=>JSON.serialize(structured)});
        }
        return value;
    }
}
