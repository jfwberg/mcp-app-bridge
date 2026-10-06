/** Behavioral tests for the stateful MCP HTTP endpoint. */
@IsTest
private class McpRestEndpointTest {
    @IsTest static void shouldPublishMatchingUiResourceAliases(){
        String sessionId=initialize('2024-11-05');ready(sessionId,'2024-11-05');
        McpEventMappingConfig mapping=new McpEventMappingConfig();mapping.key='refresh';mapping.configKey='admin_friend';mapping.direction='HOST_TO_LWC';mapping.eventName='refresh_component';mapping.hostAction='DISPATCH_EVENT';mapping.toolName='refresh_configured_component';mapping.maxPayloadCharacters=4096;McpEventMappingConfig.testMappings.add(mapping);
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>2,'method'=>'tools/list'}));useSession(sessionId,'2024-11-05');McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'2024 discovery should succeed');
        Map<String,Object> result=(Map<String,Object>)((Map<String,Object>)JSON.deserializeUntyped(responseJson())).get('result');
        Integer linkedTools=0;
        for(Object item:(List<Object>)result.get('tools')) {
            Map<String,Object> tool=(Map<String,Object>)item;Map<String,Object> meta=(Map<String,Object>)tool.get('_meta');Map<String,Object> ui=(Map<String,Object>)meta.get('ui');
            if(ui.containsKey('resourceUri')) {
                linkedTools++;
                Assert.areEqual('ui://mcp-app-bridge/admin-friend/v3/index.html',ui.get('resourceUri'),'UI tools should link the configured resource');
                Assert.areEqual(ui.get('resourceUri'),meta.get('ui/resourceUri'),'Flat and nested resource URIs must agree on the wire');
                Assert.areEqual('["model","app"]',JSON.serialize(ui.get('visibility')),'UI-linked tools must explicitly allow model and app calls');
            } else Assert.isFalse(meta.containsKey('ui/resourceUri'),'App-only helper tools must not gain a UI resource');
        }
        Assert.areEqual(2,linkedTools,'Opening and inbound action tools must both publish the alias');
    }
    @IsTest static void shouldSupportNovember2024WithAndWithoutHeaders(){
        String version='2024-11-05';String sessionId=initialize(version);ready(sessionId,version);
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'old-tools','method'=>'tools/list'}));
        RestContext.request.addHeader('MCP-Session-Id',sessionId);McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'2024 sessions must work without the later version header');
        Map<String,Object> result=(Map<String,Object>)((Map<String,Object>)JSON.deserializeUntyped(responseJson())).get('result');
        for(Object item:(List<Object>)result.get('tools')) Assert.isFalse(((Map<String,Object>)item).containsKey('title'),'2024 tools must omit later titles');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'old-call','method'=>'tools/call','params'=>new Map<String,Object>{'name'=>'open_admin_friend'}}));
        McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'Headerless stateless 2024 calls must work');
        result=(Map<String,Object>)((Map<String,Object>)JSON.deserializeUntyped(responseJson())).get('result');
        Assert.isFalse(result.containsKey('structuredContent'),'2024 must use text content for structured data');
        List<Object> content=(List<Object>)result.get('content');
        Map<String,Object> data=(Map<String,Object>)JSON.deserializeUntyped((String)((Map<String,Object>)content[1]).get('text'));
        Assert.areEqual('admin_friend',data.get('configKey'),'Text fallback must preserve tool data');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'wrong-old-version','method'=>'tools/list'}));useSession(sessionId,'2025-06-18');McpRestEndpoint.doPost();
        Assert.areEqual(400,RestContext.response.statusCode,'Explicit session version mismatches must still fail');
    }
    @IsTest static void shouldInitializeNovember2024Stateless(){
        McpLifecycleService.testStatefulSessions=false;
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>1,'method'=>'initialize','params'=>new Map<String,Object>{'protocolVersion'=>'2024-11-05'}}));McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'2024 initialize should succeed');
        Assert.isNull(RestContext.response.headers.get('MCP-Session-Id'),'Default initialize must stay stateless');
        Map<String,Object> result=(Map<String,Object>)((Map<String,Object>)JSON.deserializeUntyped(responseJson())).get('result');
        Assert.areEqual('2024-11-05',result.get('protocolVersion'),'Requested revision must be negotiated');
        Map<String,Object> capabilities=(Map<String,Object>)result.get('capabilities');
        Assert.isTrue(capabilities.containsKey('extensions'),'MCP Apps uses extensions even with the 2024 core revision');
        Assert.isTrue(JSON.serialize(capabilities.get('extensions')).contains('io.modelcontextprotocol/ui'),'2024 must advertise MCP Apps support');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','method'=>'notifications/initialized'}));McpRestEndpoint.doPost();
        Assert.areEqual(202,RestContext.response.statusCode,'Headerless initialized notification must succeed');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>2,'method'=>'ping'}));RestContext.request.addHeader('MCP-Protocol-Version','unsupported');McpRestEndpoint.doPost();
        Assert.areEqual(400,RestContext.response.statusCode,'Explicit unsupported versions must remain rejected');
    }
    private static void setRequest(String method,String body){ RestRequest request=new RestRequest(); request.requestURI='/services/apexrest/mcp'; request.httpMethod=method; request.addHeader('Content-Type','application/json'); request.addHeader('Accept','application/json, text/event-stream'); if(body!=null)request.requestBody=Blob.valueOf(body); RestContext.request=request; RestContext.response=new RestResponse(); }
    private static String responseJson(){String body=RestContext.response.responseBody.toString();if(body.startsWith('event: message\ndata: '))return body.substring('event: message\ndata: '.length()).trim();return body;}
    private static String initialize(){ return initialize('2025-11-25'); }
    private static String initialize(String protocolVersion){ McpLifecycleService.testStatefulSessions=true;McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(Enabled__c=true,Protocol_Version__c='2025-11-25',Session_Timeout_Minutes__c=30);McpLightningOutConfig.testRecords=new List<MCP_App_Bridge_LO2_Config__mdt>{new MCP_App_Bridge_LO2_Config__mdt(DeveloperName='admin_friend',Enabled__c=true,App_Id__c='1Us000000000001AAA',Component_Name__c='xdemo-mcp-admin-friend',Resource_Uri__c='ui://mcp-app-bridge/admin-friend/v3/index.html',Static_Resource_Name__c='McpLightningOutHost',Display_Name__c='MCP Admin Friend',Description__c='Authenticated Salesforce MCP Admin Friend interface.')};McpEventMappingConfig.testMappings=new List<McpEventMappingConfig>();McpLightningOutService.testSessionId='test-session';McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';McpLightningOutService.testFrontdoorUrl='https://example.my.salesforce.com/secur/frontdoor.jsp?otp=test';McpLightningOutService.testBootstrapInvocationCount=0;setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>1,'method'=>'initialize','params'=>new Map<String,Object>{'protocolVersion'=>protocolVersion,'capabilities'=>new Map<String,Object>(),'clientInfo'=>new Map<String,Object>{'name'=>'test','version'=>'1'}}})); Test.startTest(); McpRestEndpoint.doPost(); Test.stopTest(); Assert.areEqual(200,RestContext.response.statusCode,'Initialize should succeed'); String responseBody=RestContext.response.responseBody.toString(); Assert.isTrue(responseBody.contains('io.modelcontextprotocol/ui'),'Initialize must advertise the MCP Apps UI extension'); Assert.isTrue(responseBody.contains('text/html;profile=mcp-app'),'Initialize must advertise the supported MCP App MIME type');Assert.areEqual('text/event-stream',RestContext.response.headers.get('Content-Type'),'Legacy request results should use Streamable HTTP SSE framing'); Map<String,Object> responseEnvelope=(Map<String,Object>)JSON.deserializeUntyped(responseJson());Map<String,Object> result=(Map<String,Object>)responseEnvelope.get('result');Assert.areEqual(protocolVersion,result.get('protocolVersion'),'Initialize must confirm the negotiated protocol version'); String sessionId=RestContext.response.headers.get('MCP-Session-Id'); Assert.isNotNull(sessionId,'Stateful compatibility test initialization must return a session ID'); Assert.isTrue(Pattern.matches('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',sessionId),'Session identifier should be a UUID v4'); return sessionId; }
    private static void useSession(String sessionId){ useSession(sessionId,'2025-11-25'); }
    private static void useSession(String sessionId,String protocolVersion){ RestContext.request.addHeader('MCP-Session-Id',sessionId); RestContext.request.addHeader('MCP-Protocol-Version',protocolVersion); }
    private static Map<String,Object> modernMeta(){ return new Map<String,Object>{'io.modelcontextprotocol/protocolVersion'=>'2026-07-28','io.modelcontextprotocol/clientInfo'=>new Map<String,Object>{'name'=>'test-modern','version'=>'1'},'io.modelcontextprotocol/clientCapabilities'=>new Map<String,Object>()}; }
    private static void useModernHeaders(String method,String name){ RestContext.request.addHeader('MCP-Protocol-Version','2026-07-28');RestContext.request.addHeader('Mcp-Method',method);if(name!=null)RestContext.request.addHeader('Mcp-Name',name); }
    private static void ready(String sessionId){ setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','method'=>'notifications/initialized'})); useSession(sessionId); McpRestEndpoint.doPost(); Assert.areEqual(202,RestContext.response.statusCode,'Initialized notification should be accepted'); }
    private static void ready(String sessionId,String protocolVersion){ setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','method'=>'notifications/initialized'})); useSession(sessionId,protocolVersion); McpRestEndpoint.doPost(); Assert.areEqual(202,RestContext.response.statusCode,'Initialized notification should be accepted'); }
    @IsTest static void shouldInitializeListToolsAndDeleteSession(){ String sessionId=initialize(); ready(sessionId); setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'tool-id','method'=>'tools/list'})); useSession(sessionId); McpRestEndpoint.doPost(); Assert.areEqual(200,RestContext.response.statusCode,'tools/list should succeed'); String json=RestContext.response.responseBody.toString(); Assert.isTrue(json.contains('open_admin_friend'),'Metadata-derived render tool should be listed'); Assert.isFalse(json.contains('admin_friend_event'),'Component-specific event tools should not be built into the bridge');Assert.isFalse(json.contains('resultType'),'Legacy results must retain their 2025-11-25 wire shape'); setRequest('DELETE',null);useSession(sessionId);McpRestEndpoint.doDelete();Assert.areEqual(204,RestContext.response.statusCode,'DELETE should terminate session'); }
    @IsTest static void shouldNegotiateJune2025AndEnforceItsSessionVersion(){
        String protocolVersion='2025-06-18';String sessionId=initialize(protocolVersion);ready(sessionId,protocolVersion);
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'slack-tools','method'=>'tools/list'}));useSession(sessionId,protocolVersion);McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'2025-06-18 tools/list should succeed');Assert.isTrue(RestContext.response.responseBody.toString().contains('open_admin_friend'),'June clients should receive configured tools');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'wrong-version','method'=>'tools/list'}));useSession(sessionId,'2025-11-25');McpRestEndpoint.doPost();
        Assert.areEqual(400,RestContext.response.statusCode,'A session must retain its negotiated version');Assert.isTrue(RestContext.response.responseBody.toString().contains('does not match the session'),'A version mismatch should be explicit');
    }
    @IsTest static void shouldUseStatelessLegacyHandshakeByDefault(){
        McpLifecycleService.testStatefulSessions=false;McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(Enabled__c=true,Protocol_Version__c='2025-11-25',Session_Timeout_Minutes__c=30);McpLightningOutConfig.testRecords=new List<MCP_App_Bridge_LO2_Config__mdt>{new MCP_App_Bridge_LO2_Config__mdt(DeveloperName='admin_friend',Enabled__c=true,App_Id__c='1Us000000000001AAA',Component_Name__c='xdemo-mcp-admin-friend',Resource_Uri__c='ui://mcp-app-bridge/admin-friend/v3/index.html',Static_Resource_Name__c='McpLightningOutHost',Display_Name__c='MCP Admin Friend',Description__c='Authenticated Salesforce MCP Admin Friend interface.')};McpEventMappingConfig.testMappings=new List<McpEventMappingConfig>();
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'stateless-init','method'=>'initialize','params'=>new Map<String,Object>{'protocolVersion'=>'2025-06-18','capabilities'=>new Map<String,Object>(),'clientInfo'=>new Map<String,Object>{'name'=>'slack','version'=>'1'}}}));McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'Stateless initialize should succeed');Assert.isNull(RestContext.response.headers.get('MCP-Session-Id'),'Stateless initialize must not create a session header');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','method'=>'notifications/initialized'}));RestContext.request.addHeader('MCP-Protocol-Version','2025-06-18');McpRestEndpoint.doPost();Assert.areEqual(202,RestContext.response.statusCode,'Stateless initialized notification should succeed');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'stateless-tools','method'=>'tools/list'}));RestContext.request.addHeader('MCP-Protocol-Version','2025-06-18');McpRestEndpoint.doPost();Assert.areEqual(200,RestContext.response.statusCode,'Stateless tools/list should succeed');Assert.isTrue(RestContext.response.responseBody.toString().contains('open_admin_friend'),'Stateless clients should receive tools');
    }
    @IsTest static void shouldUseStatefulSseHandshakeForOpenAiConnector(){
        McpLifecycleService.testStatefulSessions=false;McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(Enabled__c=true,Protocol_Version__c='2025-11-25',Session_Timeout_Minutes__c=30);McpLightningOutConfig.testRecords=new List<MCP_App_Bridge_LO2_Config__mdt>{new MCP_App_Bridge_LO2_Config__mdt(DeveloperName='admin_friend',Enabled__c=true,App_Id__c='1Us000000000001AAA',Component_Name__c='xdemo-mcp-admin-friend',Resource_Uri__c='ui://mcp-app-bridge/admin-friend/v3/index.html',Static_Resource_Name__c='McpLightningOutHost',Display_Name__c='MCP Admin Friend',Description__c='Authenticated Salesforce MCP Admin Friend interface.')};McpEventMappingConfig.testMappings=new List<McpEventMappingConfig>();
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'openai-init','method'=>'initialize','params'=>new Map<String,Object>{'protocolVersion'=>'2025-11-25','capabilities'=>new Map<String,Object>(),'clientInfo'=>new Map<String,Object>{'name'=>'openai-mcp','version'=>'1.0.0'}}}));RestContext.request.addHeader('User-Agent','openai-mcp/1.0.0');McpRestEndpoint.doPost();
        String sessionId=RestContext.response.headers.get('MCP-Session-Id');Assert.isNotNull(sessionId,'OpenAI connector should receive a session for its request batch');Assert.areEqual('text/event-stream',RestContext.response.headers.get('Content-Type'),'OpenAI initialize should use SSE framing');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','method'=>'notifications/initialized'}));useSession(sessionId,'2025-11-25');McpRestEndpoint.doPost();Assert.areEqual(202,RestContext.response.statusCode,'OpenAI initialized notification should succeed');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'openai-tools','method'=>'tools/list'}));useSession(sessionId,'2025-11-25');McpRestEndpoint.doPost();Assert.areEqual(200,RestContext.response.statusCode,'OpenAI tools/list should succeed');Assert.isTrue(RestContext.response.responseBody.toString().startsWith('event: message\ndata: '),'OpenAI tools/list should use SSE framing');
    }
    @IsTest static void shouldPreserveStringIdAndCallOpenTool(){ String sessionId=initialize();ready(sessionId);McpLightningOutConfig.testRecords[0].Input_Schema_JSON__c='{"type":"object","properties":{"recordId":{"type":"string"}},"required":["recordId"],"additionalProperties":false}';setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'abc','method'=>'tools/call','params'=>new Map<String,Object>{'name'=>'open_admin_friend','arguments'=>new Map<String,Object>{'recordId'=>'001000000000001AAA'}}}));useSession(sessionId);McpRestEndpoint.doPost();Map<String,Object> body=(Map<String,Object>)JSON.deserializeUntyped(responseJson());Assert.areEqual('abc',body.get('id'),'String JSON-RPC ID should be preserved');Assert.isTrue(body.containsKey('result'),'Successful JSON-RPC response must contain result');Assert.isFalse(body.containsKey('error'),'Successful JSON-RPC response must omit error');String response=RestContext.response.responseBody.toString();Assert.isTrue(response.contains('componentInputs'),'Tool result should expose configured component inputs');Assert.isTrue(response.contains('001000000000001AAA'),'Configured input should be passed to the widget');Assert.isFalse(response.contains('mcpapp/bootstrap'),'Opening tool must not persist bootstrap metadata in conversation history');Assert.isFalse(response.contains('frontdoor.jsp?otp=test'),'Opening tool must not mint or return a frontdoor URL');Assert.areEqual(0,McpLightningOutService.testBootstrapInvocationCount,'Opening a widget must defer session creation until the app mounts'); }
    @IsTest static void shouldRejectConfiguredArrayBelowMinimum(){
        String sessionId=initialize();ready(sessionId);
        McpLightningOutConfig.testRecords[0].Input_Schema_JSON__c='{"type":"object","properties":{"recordIds":{"type":"array","items":{"type":"string"},"minItems":1}},"required":["recordIds"],"additionalProperties":false}';
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>7,'method'=>'tools/call','params'=>new Map<String,Object>{'name'=>'open_admin_friend','arguments'=>new Map<String,Object>{'recordIds'=>new List<String>()}}}));
        useSession(sessionId);McpRestEndpoint.doPost();
        Assert.areEqual(400,RestContext.response.statusCode,'An array below configured minItems should be rejected');
        Assert.isTrue(RestContext.response.responseBody.toString().contains('recordIds must contain at least 1 item'),'The correction should be clear to the calling model');
        Assert.areEqual(0,McpLightningOutService.testBootstrapInvocationCount,'Invalid inputs must not mint a UI session');
    }
    @IsTest static void shouldRouteConfiguredComponentEventToHostMessage(){
        String sessionId=initialize();ready(sessionId);
        McpEventMappingConfig mapping=new McpEventMappingConfig();mapping.key='account_details';mapping.configKey='admin_friend';mapping.direction='LWC_TO_HOST';mapping.eventName='account_details';mapping.hostAction='SEND_MESSAGE';mapping.instructions='Show the account in a table.';mapping.maxPayloadCharacters=4096;McpEventMappingConfig.testMappings.add(mapping);
        Map<String,Object> args=new Map<String,Object>{'configKey'=>'admin_friend','mappingKey'=>'account_details','payload'=>new Map<String,Object>{'name'=>'Edge Communications','notes'=>'data only'}};
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>9,'method'=>'tools/call','params'=>new Map<String,Object>{'name'=>'bridge_event','arguments'=>args}}));useSession(sessionId);McpRestEndpoint.doPost();
        String response=RestContext.response.responseBody.toString();
        Assert.areEqual(200,RestContext.response.statusCode,'Configured event should be routed');
        Assert.isTrue(response.contains('Show the account in a table.'),'Configured instructions should be included');
        Assert.isTrue(response.contains('untrusted Salesforce data'),'Payload trust boundary should be explicit');
        Assert.isTrue(response.contains('Edge Communications'),'Event payload should be included');
        Assert.isTrue(response.contains('"mcpapp/hostMessage"'),'A host message should be returned to the app');
    }
    @IsTest static void shouldDeriveToolsFromEnabledConfigurations(){
        initialize();
        McpLightningOutConfig.testRecords.add(new MCP_App_Bridge_LO2_Config__mdt(DeveloperName='case_console',Enabled__c=true,App_Id__c='1Us000000000002AAA',Component_Name__c='example-case-console',Resource_Uri__c='ui://mcp-app-bridge/case-console/v1/index.html',Static_Resource_Name__c='McpLightningOutHost',Display_Name__c='Case Console',Description__c='Open the configured case console.'));
        String renderedTools=JSON.serialize(McpToolRegistry.listTools());
        Assert.isTrue(renderedTools.contains('open_admin_friend'),'First configuration should produce a tool');
        Assert.isTrue(renderedTools.contains('open_case_console'),'Second configuration should produce a tool without a code change');
        Assert.isTrue(renderedTools.contains('ui://mcp-app-bridge/case-console/v1/index.html'),'Each generated tool should point at its configured resource');
        McpLightningOutConfig.testRecords.remove(1);
        Assert.isFalse(JSON.serialize(McpToolRegistry.listTools()).contains('open_case_console'),'Removing configuration should remove its tool');
    }
    @IsTest static void shouldDeriveAndExecuteInboundComponentAction(){
        String sessionId=initialize();ready(sessionId);
        McpEventMappingConfig mapping=new McpEventMappingConfig();mapping.key='refresh';mapping.configKey='admin_friend';mapping.direction='HOST_TO_LWC';mapping.eventName='refresh_component';mapping.hostAction='DISPATCH_EVENT';mapping.toolName='refresh_configured_component';mapping.toolTitle='Refresh configured component';mapping.toolDescription='Refresh it.';mapping.inputSchemaJson='{"type":"object","properties":{"accountId":{"type":"string"}},"additionalProperties":false}';mapping.maxPayloadCharacters=4096;McpEventMappingConfig.testMappings.add(mapping);
        Assert.isTrue(JSON.serialize(McpToolRegistry.listTools()).contains('refresh_configured_component'),'Inbound metadata should generate a model-visible tool');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>8,'method'=>'tools/call','params'=>new Map<String,Object>{'name'=>'refresh_configured_component','arguments'=>new Map<String,Object>{'accountId'=>'001000000000001AAA'}}}));useSession(sessionId);McpRestEndpoint.doPost();
        String response=RestContext.response.responseBody.toString();
        Assert.areEqual(200,RestContext.response.statusCode,'Configured inbound action should execute');
        Assert.isTrue(response.contains('mcpappCommand'),'Action result should contain a generic component command');
        Assert.isTrue(response.contains('"mappingKey":"refresh"'),'Command should identify its mapping without component knowledge');
        Assert.isTrue(response.contains('001000000000001AAA'),'Command should carry configured action inputs to the component');
    }
    @IsTest static void shouldRejectMalformedAndUnsupportedRequests(){ setRequest('POST','{');McpRestEndpoint.doPost();Assert.areEqual(400,RestContext.response.statusCode,'Malformed JSON should return 400');Map<String,Object> errorBody=(Map<String,Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());Assert.isTrue(errorBody.containsKey('error'),'Failed JSON-RPC response must contain error');Assert.isFalse(errorBody.containsKey('result'),'Failed JSON-RPC response must omit result');Assert.isTrue(RestContext.response.responseBody.toString().contains('-32700'),'Parse error code should be returned'); setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>1,'method'=>'initialize','params'=>new Map<String,Object>{'protocolVersion'=>'unsupported'}}));McpRestEndpoint.doPost();Assert.areEqual(400,RestContext.response.statusCode,'Unsupported version should return 400'); }
    @IsTest static void shouldDiscoverModernProtocolWithoutSession(){
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'openai-mcp-discover','method'=>'server/discover','params'=>new Map<String,Object>{'_meta'=>modernMeta()}}));
        useModernHeaders('server/discover',null);
        McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'Modern discovery must succeed without a session');
        Map<String,Object> body=(Map<String,Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual('openai-mcp-discover',body.get('id'),'Discovery must preserve the JSON-RPC request ID');
        Map<String,Object> result=(Map<String,Object>)body.get('result');
        Assert.areEqual('complete',result.get('resultType'),'Modern results must identify their result type');
        Assert.areEqual('private',result.get('cacheScope'),'Discovery must not be shared across authorization contexts');
        Assert.isTrue(JSON.serialize(result.get('supportedVersions')).contains('2026-07-28'),'Discovery must advertise the implemented modern version');
        Assert.isTrue(JSON.serialize(result).contains('io.modelcontextprotocol/serverInfo'),'Modern results should identify the server');
    }
    @IsTest static void shouldFrameModernOpenAiDiscoveryAsSse(){
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>'openai-mcp-discover','method'=>'server/discover','params'=>new Map<String,Object>{'_meta'=>modernMeta()}}));
        RestContext.request.addHeader('User-Agent','openai-mcp/1.0.0');useModernHeaders('server/discover',null);McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'OpenAI modern discovery must succeed');Assert.areEqual('text/event-stream',RestContext.response.headers.get('Content-Type'),'OpenAI modern discovery should use SSE framing');
        Map<String,Object> body=(Map<String,Object>)JSON.deserializeUntyped(responseJson());Assert.areEqual('openai-mcp-discover',body.get('id'),'SSE discovery must preserve the request ID');Map<String,Object> result=(Map<String,Object>)body.get('result');Assert.areEqual('complete',result.get('resultType'),'SSE discovery must preserve the modern result');
    }
    @IsTest static void shouldListModernToolsWithoutSession(){
        initialize();
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>20,'method'=>'tools/list','params'=>new Map<String,Object>{'_meta'=>modernMeta()}}));
        useModernHeaders('tools/list',null);McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'Modern tools/list must be sessionless');
        Map<String,Object> body=(Map<String,Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());Map<String,Object> result=(Map<String,Object>)body.get('result');
        Assert.areEqual('complete',result.get('resultType'),'Modern tool lists require a complete result type');
        Assert.areEqual('private',result.get('cacheScope'),'Authorized tool lists must not be shared between callers');
        Assert.areEqual(0,((Decimal)result.get('ttlMs')).intValue(),'Dynamic tool lists should be immediately stale');
        Assert.isTrue(JSON.serialize(result).contains('open_admin_friend'),'Modern tool discovery must use the configured registry');
    }
    @IsTest static void shouldCallModernToolWithoutSession(){
        initialize();
        Map<String,Object> params=new Map<String,Object>{'name'=>'open_admin_friend','arguments'=>new Map<String,Object>(),'_meta'=>modernMeta()};
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>23,'method'=>'tools/call','params'=>params}));
        useModernHeaders('tools/call','open_admin_friend');McpRestEndpoint.doPost();
        Assert.areEqual(200,RestContext.response.statusCode,'Modern tools/call must be sessionless');
        Assert.isNull(RestContext.response.headers.get('MCP-Session-Id'),'Modern requests must not mint a protocol session');
        Map<String,Object> body=(Map<String,Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());Map<String,Object> result=(Map<String,Object>)body.get('result');
        Assert.areEqual('complete',result.get('resultType'),'Modern tool results require a complete result type');
        String rendered=JSON.serialize(result);Assert.isFalse(rendered.contains('mcpapp/bootstrap'),'Modern opening results must not persist single-use bootstrap metadata');Assert.isTrue(rendered.contains('io.modelcontextprotocol/serverInfo'),'Modern tool results should identify the server');
    }
    @IsTest static void shouldValidateModernRoutingHeaders(){
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>21,'method'=>'tools/list','params'=>new Map<String,Object>{'_meta'=>modernMeta()}}));
        RestContext.request.addHeader('MCP-Protocol-Version','2026-07-28');RestContext.request.addHeader('Mcp-Method','resources/list');McpRestEndpoint.doPost();
        Assert.areEqual(400,RestContext.response.statusCode,'Mismatched modern routing headers must be rejected');
        Map<String,Object> body=(Map<String,Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());Map<String,Object> error=(Map<String,Object>)body.get('error');
        Assert.areEqual(-32020,((Decimal)error.get('code')).intValue(),'Header mismatch must use the modern protocol error code');
    }
    @IsTest static void shouldReturnStructuredUnsupportedModernVersion(){
        Map<String,Object> meta=modernMeta();meta.put('io.modelcontextprotocol/protocolVersion','2099-01-01');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>22,'method'=>'server/discover','params'=>new Map<String,Object>{'_meta'=>meta}}));
        RestContext.request.addHeader('MCP-Protocol-Version','2099-01-01');RestContext.request.addHeader('Mcp-Method','server/discover');McpRestEndpoint.doPost();
        Assert.areEqual(400,RestContext.response.statusCode,'Unsupported modern versions must return bad request');
        Map<String,Object> body=(Map<String,Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());Map<String,Object> error=(Map<String,Object>)body.get('error');
        Assert.areEqual(-32022,((Decimal)error.get('code')).intValue(),'Unsupported versions must use the negotiation error code');
        Map<String,Object> data=(Map<String,Object>)error.get('data');Assert.isTrue(JSON.serialize(data.get('supported')).contains('2026-07-28'),'Negotiation errors must advertise supported versions');
        Assert.areEqual('2099-01-01',data.get('requested'),'Negotiation errors must identify the requested version');
    }
    @IsTest static void shouldRequireReadySessionForOperationalCalls(){ String sessionId=initialize();setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>1,'method'=>'tools/list'}));useSession(sessionId);McpRestEndpoint.doPost();Assert.areEqual(400,RestContext.response.statusCode,'Operational calls before initialized should fail'); }
    @IsTest static void shouldReturnDiscoveryAndRejectGetOnMcp(){ setRequest('GET',null);McpRestEndpoint.doGet();Assert.areEqual(405,RestContext.response.statusCode,'GET /mcp should be rejected');RestContext.request.requestURI='/services/apexrest/mcp/.well-known/oauth-protected-resource';McpRestEndpoint.doGet();Assert.areEqual(200,RestContext.response.statusCode,'Discovery route should succeed');Assert.isTrue(RestContext.response.responseBody.toString().contains('authorization_servers'),'Metadata should identify authorization server'); }
    @IsTest static void shouldListAndReadCacheableUiResource(){
        String sessionId=initialize();ready(sessionId);
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>2,'method'=>'resources/list'}));useSession(sessionId);McpRestEndpoint.doPost();
        String listJson=RestContext.response.responseBody.toString();
        Assert.isTrue(listJson.contains('"resourceDomains"'),'Resource listing should predeclare standard CSP metadata');
        Assert.isTrue(listJson.contains('ui://mcp-app-bridge/admin-friend/v3/index.html'),'Resource listing should publish the configured cache key');
        setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>3,'method'=>'resources/read','params'=>new Map<String,Object>{'uri'=>'ui://mcp-app-bridge/admin-friend/v3/index.html'}}));useSession(sessionId);McpRestEndpoint.doPost();
        String json=RestContext.response.responseBody.toString();
        Assert.areEqual(200,RestContext.response.statusCode,'Resource read should succeed');
        Assert.isTrue(json.contains('text/html;profile=mcp-app'),'MCP App MIME type should be returned');
        Assert.isFalse(json.contains('waitForBootstrap'),'Widget must not wait for cached bootstrap metadata from its opening result');
        Assert.isTrue(json.contains('waitForInputs'),'Widget should allow opening inputs to arrive before mounting Lightning Out');
        Assert.isFalse(json.contains('window.openai'),'Widget should remain MCP Apps client-neutral');
        Assert.isFalse(json.contains('openai:set_globals'),'Widget should not depend on client-specific global events');
        Assert.isTrue(json.contains('mcpapp/bootstrapError'),'Widget should render safe failures from its mount-time bootstrap call');
        Assert.isTrue(json.contains('bootstrap_lightning_out'),'Widget must always call the private bootstrap tool when it mounts');
        Assert.isTrue(json.contains('bridge_event'),'Widget should route configured component events generically');
        Assert.isTrue(json.contains('ui/notifications/tool-input'),'Widget should consume opening tool arguments through the MCP Apps notification');
        Assert.isTrue(json.contains('attributeName=name=&gt;name.replace') || json.contains('attributeName=name=>name.replace'),'Widget should translate public property names to Lightning Out attributes');
        Assert.isTrue(json.contains('queuedToolResults'),'Widget should retain inbound commands until the Lightning Out component is ready');
        Assert.isTrue(json.contains('appInfo:{name:\'mcpapp-bridge\',version:\'1.0.0\'}'),'Widget must use the MCP Apps initialization schema');
        Assert.isTrue(json.contains('appCapabilities:{}'),'Widget must declare MCP Apps capabilities');
        Assert.isFalse(json.contains('admin_friend_event'),'Generic host must not contain a component-specific event tool');
        Assert.isFalse(json.contains('adminfriendaction'),'Generic host must not contain component-specific DOM events');
        Assert.isTrue(json.contains('ui/notifications/size-changed'),'Widget should report requested height to its MCP host');
        Assert.isTrue(json.contains('resize-handle'),'Widget should include an accessible resize handle');
        Assert.isTrue(json.contains('#mount{flex:1;min-height:0;overflow:hidden}'),'Outer widget should not add a second scrollbar around Lightning Out');
        Assert.isFalse(json.contains('frontdoor.jsp?otp=test'),'Cacheable resource must not contain a one-time frontdoor URL');
        Assert.areEqual(0,McpLightningOutService.testBootstrapInvocationCount,'Reading cacheable HTML must not mint a frontdoor URL');
        Assert.isTrue(json.contains('.file.force.com'),'Widget CSP should allow the Salesforce file frame');
        Assert.isFalse(json.contains('test-session'),'Salesforce session ID must never be returned');
    }
    @IsTest static void shouldMintFreshBootstrapForEveryAppCall(){
        String sessionId=initialize();ready(sessionId);
        McpLightningOutConfig.testRecords[0].Input_Schema_JSON__c='{"type":"object","properties":{"recordId":{"type":"string"}},"additionalProperties":false}';
        for(Integer index=0;index<2;index++){
            setRequest('POST',JSON.serialize(new Map<String,Object>{'jsonrpc'=>'2.0','id'=>index+10,'method'=>'tools/call','params'=>new Map<String,Object>{'name'=>'bootstrap_lightning_out','arguments'=>new Map<String,Object>{'configKey'=>'admin_friend'}}}));
            useSession(sessionId);McpRestEndpoint.doPost();
            String json=RestContext.response.responseBody.toString();
            Assert.areEqual(200,RestContext.response.statusCode,'Bootstrap tool should succeed');
            Assert.isTrue(json.contains('"mcpapp/bootstrap"'),'Fresh bootstrap must be returned in tool-result metadata');
            Assert.isTrue(json.contains('frontdoor.jsp?otp=test'),'Bootstrap tool must return the newly minted frontdoor URL');
            Assert.isTrue(json.contains('inputNames'),'Bootstrap should provide the configured component-input allowlist');
            Assert.isTrue(json.contains('recordId'),'Bootstrap allowlist should be derived from the configured schema');
        }
        Assert.areEqual(2,McpLightningOutService.testBootstrapInvocationCount,'Every app bootstrap call must mint its own frontdoor URL');
    }
    @IsTest static void shouldCleanExpiredSessions(){ insert new MCP_Session__c(Session_Hash__c='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',User_Id__c=UserInfo.getUserId(),Organization_Id__c=UserInfo.getOrganizationId(),Protocol_Version__c='2025-11-25',Lifecycle_State__c='TERMINATED',Created_At__c=System.now(),Last_Seen_At__c=System.now(),Expires_At__c=System.now());Test.startTest();new McpSessionCleanupSchedulable().execute(null);Test.stopTest();Assert.areEqual(0,[SELECT COUNT() FROM MCP_Session__c],'Cleanup should delete terminated sessions'); }
    @IsTest static void shouldReadConfiguredMetadataValues(){ McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(Enabled__c=true,ECA_Consumer_Key__c='consumer-key',ECA_Certificate_Name__c='certificate-name',Required_Scopes__c='api refresh_token',Protocol_Version__c='2025-11-25',Session_Timeout_Minutes__c=45,Allowed_Origins__c='https://chatgpt.com,https://example.com');Test.startTest();McpBridgeCoreConfig value=McpBridgeCoreConfig.get();Test.stopTest();Assert.areEqual(45,value.timeoutMinutes,'Configured timeout should be used');Assert.areEqual(2,value.allowedOrigins.size(),'Configured origins should be parsed');Assert.areEqual('api refresh_token',value.requiredScopes,'Configured scopes should be used');Assert.areEqual('consumer-key',value.ecaConsumerKey,'ECA consumer key should be available to JWT bootstrap');Assert.areEqual('certificate-name',value.ecaCertificateName,'ECA certificate should be available to JWT bootstrap');Assert.isTrue(value.endpointUrl.endsWith('/services/apexrest/mcpapp/mcp'),'MCP endpoint should be derived with the package namespace'); }
}
