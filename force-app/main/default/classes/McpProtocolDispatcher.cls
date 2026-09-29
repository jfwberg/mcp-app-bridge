/** Central JSON-RPC method dispatcher. */
public with sharing class McpProtocolDispatcher {
    private final McpLifecycleService lifecycle=new McpLifecycleService();
    public Object dispatch(Map<String,Object> request, RestRequest httpRequest, RestResponse httpResponse) {
        Object id=request.get('id'); String method=(String)request.get('method');
        if((String)request.get('jsonrpc')!='2.0'||String.isBlank(method)) throw new McpProtocolException(-32600,400,'Invalid Request.');
        Map<String,Object> params=request.get('params') instanceof Map<String,Object>?(Map<String,Object>)request.get('params'):new Map<String,Object>();
        if(McpModernProtocolService.isModern(request,httpRequest)) return new McpModernProtocolService().dispatch(request,httpRequest);
        if(method=='initialize') return lifecycle.initialize(params,httpResponse);
        Set<String> sessionMethods=new Set<String>{'notifications/initialized','ping','tools/list','tools/call','resources/list','resources/read'};
        if(!sessionMethods.contains(method)) throw new McpProtocolException(-32601,404,'Method not found.');
        Boolean stateful=lifecycle.hasSession(httpRequest);McpSession session;
        if(stateful){Boolean ready=method!='notifications/initialized'&&method!='ping';session=lifecycle.requireSession(httpRequest,ready);}
        else lifecycle.requireStatelessProtocolVersion(httpRequest);
        Object result;
        if(method=='notifications/initialized'){ if(stateful)lifecycle.markInitialized(session); return null; }
        if(method=='ping') result=new Map<String,Object>();
        else if(method=='tools/list') result=McpToolRegistry.listTools();
        else if(method=='tools/call') result=McpToolRegistry.callTool(params);
        else if(method=='resources/list') result=McpResourceRegistry.listResources();
        else result=McpResourceRegistry.readResource(params);
        if(stateful)lifecycle.touchSession(session);
        return result;
    }
}
