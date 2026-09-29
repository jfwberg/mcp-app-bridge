/** Stateful MCP Streamable HTTP endpoint. */
@RestResource(urlMapping='/mcp/*')
global with sharing class McpRestEndpoint {
    @HttpPost global static void doPost(){
        prepare(false); RestRequest req=RestContext.request; RestResponse res=RestContext.response;
        Object requestId;
        String requestMethod;
        String requestTool;
        Long startedAt=System.now().getTime();
        try{
            validateTransport(req); String raw=req.requestBody==null?null:req.requestBody.toString();
            if(String.isBlank(raw)||raw.length()>131072) throw new McpProtocolException(-32600,400,'Request body is missing or too large.');
            Map<String,Object> request;
            try{ request=(Map<String,Object>)JSON.deserializeUntyped(raw); }catch(Exception parseFailure){ writeError(null,-32700,'Parse error.',400); return; }
            requestId=request.get('id'); requestMethod=(String)request.get('method');
            Map<String,Object> requestParams=request.get('params') instanceof Map<String,Object>?(Map<String,Object>)request.get('params'):null;
            requestTool=requestParams==null?null:(String)requestParams.get('name');
            Boolean modern=McpModernProtocolService.isModern(request,req);
            String userAgent=getHeaderIgnoreCase(req,'User-Agent');
            Boolean useSse=!modern||(String.isNotBlank(userAgent)&&userAgent.toLowerCase().startsWith('openai-mcp/'));
            Object result=new McpProtocolDispatcher().dispatch(request,req,res);
            logRequest('SUCCEEDED',requestId,requestMethod,requestTool,200,System.now().getTime()-startedAt,null,null);
            if(!request.containsKey('id')){ res.statusCode=202; res.responseBody=null; return; }
            res.statusCode=200;String responseJson=JSON.serialize(McpJsonRpcResponse.success(requestId,result));
            if(!useSse)res.responseBody=Blob.valueOf(responseJson);
            else{res.addHeader('Content-Type','text/event-stream');res.responseBody=Blob.valueOf('event: message\ndata: '+responseJson+'\n\n');}
        }catch(McpProtocolException controlled){
            logRequest('FAILED',requestId,requestMethod,requestTool,controlled.httpStatus,System.now().getTime()-startedAt,controlled.errorType,controlled.getMessage());
            writeError(requestId,controlled.code,controlled.getMessage(),controlled.data,controlled.httpStatus);
        }
        catch(Exception unexpected){
            if (Test.isRunningTest()) { throw unexpected; }
            logRequest('FAILED',requestId,requestMethod,requestTool,500,System.now().getTime()-startedAt,'UNEXPECTED_ERROR','Internal error.');
            writeError(requestId,-32603,'Internal error.',null,500);
        }
    }
    @HttpGet global static void doGet(){
        String uri=RestContext.request.requestURI;
        if(uri.endsWith('/.well-known/oauth-protected-resource')){ prepare(true); RestContext.response.statusCode=200; RestContext.response.responseBody=Blob.valueOf(JSON.serialize(McpOAuthMetadataService.getMetadata())); return; }
        prepare(false); RestContext.response.statusCode=405; RestContext.response.addHeader('Allow','POST, DELETE');
        RestContext.response.responseBody=Blob.valueOf(JSON.serialize(new Map<String,Object>{'error'=>'method_not_allowed'}));
        logRequest('FAILED',null,'GET',null,405,0,'SSE_NOT_SUPPORTED','Standalone SSE stream is not supported.');
    }
    @HttpDelete global static void doDelete(){ prepare(false); try{ new McpLifecycleService().terminate(RestContext.request); RestContext.response.statusCode=204; }catch(McpProtocolException controlled){ writeError(null,controlled.code,controlled.getMessage(),controlled.data,controlled.httpStatus); } }
    private static void validateTransport(RestRequest request){
        String contentType=getHeaderIgnoreCase(request,'Content-Type');
        if(contentType==null||!contentType.toLowerCase().startsWith('application/json')) throw new McpProtocolException(-32600,415,'Content-Type must be application/json.');
        String accept=getHeaderIgnoreCase(request,'Accept'); if(String.isBlank(accept)||!accept.toLowerCase().contains('application/json')) throw new McpProtocolException(-32600,406,'Accept must include application/json.');
        String origin=getHeaderIgnoreCase(request,'Origin'); McpBridgeCoreConfig config=McpBridgeCoreConfig.get(); if(String.isNotBlank(origin)&&!config.allowedOrigins.contains(origin)) throw new McpProtocolException(-32600,403,'Origin is not allowed.');
        if(String.isNotBlank(origin)){ RestContext.response.addHeader('Access-Control-Allow-Origin',origin); RestContext.response.addHeader('Vary','Origin'); }
    }
    private static String getHeaderIgnoreCase(RestRequest request,String expectedName){ for(String name:request.headers.keySet()){ if(name.equalsIgnoreCase(expectedName)){ return request.headers.get(name); } } return null; }
    private static void prepare(Boolean cacheable){ RestResponse response=RestContext.response; response.addHeader('Content-Type','application/json; charset=utf-8'); response.addHeader('Cache-Control',cacheable?'public, max-age=300':'no-store'); response.addHeader('X-Content-Type-Options','nosniff'); response.addHeader('Access-Control-Expose-Headers','MCP-Session-Id, MCP-Protocol-Version'); }
    private static void writeError(Object id,Integer code,String message,Integer status){ writeError(id,code,message,null,status); }
    private static void writeError(Object id,Integer code,String message,Object data,Integer status){ RestContext.response.statusCode=status; RestContext.response.responseBody=Blob.valueOf(JSON.serialize(McpJsonRpcResponse.failure(id,code,message,data))); }
    private static void logRequest(String outcome,Object id,String method,String tool,Integer status,Long duration,String errorType,String message){
        McpDiagnostics.Entry entry=new McpDiagnostics.Entry(); entry.stage='MCP_REQUEST';entry.operation=method;entry.outcome=outcome;
        entry.correlationId=McpDiagnostics.correlationId(id);entry.mcpMethod=method;entry.toolName=tool;entry.httpStatus=status;
        entry.durationMs=duration;entry.errorType=errorType;entry.message=message;
        if(outcome=='FAILED')McpDiagnostics.error(entry);else McpDiagnostics.info(entry);
    }
}
