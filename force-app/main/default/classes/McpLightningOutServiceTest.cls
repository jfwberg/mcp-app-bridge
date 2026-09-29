/** Tests secure creation of Lightning Out bootstrap values. */
@IsTest
private class McpLightningOutServiceTest {
    private static McpLightningOutConfig config(String componentName) {
        McpEventMappingConfig.testMappings=new List<McpEventMappingConfig>();
        McpLightningOutConfig value=new McpLightningOutConfig();
        value.key='test_component';
        value.appId='1Us000000000001AAA';
        value.componentName=componentName;
        return value;
    }
    private class SingleAccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.areEqual('POST',request.getMethod(),'UI Bridge exchange must use POST');
            Assert.areEqual('https://example.my.salesforce.com/services/oauth2/singleaccess',request.getEndpoint(),'Exchange must use the current My Domain');
            Assert.areEqual('Bearer test-session',request.getHeader('Authorization'),'Current session must be sent only in the authorization header');
            Assert.areEqual('',request.getBody(),'Standard UI Bridge must not receive a redirect URI');
            HttpResponse response=new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type','application/json');
            response.setBody('{"frontdoor_uri":"https://example.my.salesforce.com/secur/frontdoor.jsp?otp=one-time"}');
            return response;
        }
    }

    @IsTest
    static void shouldExchangeSessionForFrontdoorUrl() {
        McpLightningOutService.testSessionId='test-session';
        McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';
        McpLightningOutService.testFrontdoorUrl=null;
        Test.setMock(HttpCalloutMock.class,new SingleAccessMock());
        Test.startTest();
        McpLightningOutService.BootstrapConfig result=McpLightningOutService.createBootstrapConfig(config('xdemo-mcp-admin-friend'));
        Test.stopTest();
        Assert.areEqual('https://example.my.salesforce.com/secur/frontdoor.jsp?otp=one-time',result.frontdoorUrl,'Frontdoor URL should be returned');
        Assert.areEqual('https://example.lightning.force.com',result.lightningOrigin,'Lightning iframe origin should be derived');
    }

    @IsTest
    static void shouldRejectMissingLightningOutAppId() {
        Test.startTest();
        try {
            McpLightningOutService.createBootstrapConfig(new McpLightningOutConfig());
            Assert.fail('Expected missing Lightning Out app configuration to fail');
        } catch (McpProtocolException expected) {
            Assert.areEqual(503,expected.httpStatus,'Missing app configuration should be unavailable');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldRejectUnsafeComponentName() {
        Test.startTest();
        try {
            McpLightningOutService.createBootstrapConfig(config('xdemo-mcpAdminFriend<script>'));
            Assert.fail('Expected unsafe component configuration to fail');
        } catch (McpProtocolException expected) {
            Assert.areEqual(503,expected.httpStatus,'Unsafe component configuration should be unavailable');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldUseInboundBearerToken() {
        McpLightningOutService.testSessionId=null;
        McpLightningOutService.testAuthorizationHeader='Bearer inbound-token';
        McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';
        Test.setMock(HttpCalloutMock.class,new BearerAccessMock());
        Test.startTest();
        McpLightningOutService.BootstrapConfig result=McpLightningOutService.createBootstrapConfig(config('xdemo-mcp-admin-friend'));
        Test.stopTest();
        Assert.isNotNull(result.frontdoorUrl,'Inbound bearer should create a frontdoor URL');
    }

    private class BearerAccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.areEqual('Bearer inbound-token',request.getHeader('Authorization'),'Inbound bearer must be forwarded to UI Bridge');
            HttpResponse response=new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"frontdoor_uri":"https://example.my.salesforce.com/secur/frontdoor.jsp?otp=inbound"}');
            return response;
        }
    }

    private class ExpiredAccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response=new HttpResponse();
            response.setStatusCode(401);
            response.setBody('{"error":"invalid_session"}');
            return response;
        }
    }

    @IsTest
    static void shouldClassifyExpiredUiSessionWithoutExposingResponse() {
        McpLightningOutService.testSessionId='expired-session';
        McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';
        McpLightningOutService.testFrontdoorUrl=null;
        Test.setMock(HttpCalloutMock.class,new ExpiredAccessMock());
        Test.startTest();
        try {
            McpLightningOutService.createBootstrapConfig(config('xdemo-mcp-admin-friend'));
            Assert.fail('Expected expired UI session to fail');
        } catch (McpProtocolException expected) {
            Assert.areEqual('UI_SESSION_AUTH_EXPIRED',expected.errorType,'Failure should identify an expired authentication session');
            Assert.areEqual(401,expected.httpStatus,'Authentication failure should retain an actionable status');
            Assert.isTrue(expected.getMessage().contains('Reconnect'),'Failure should tell the user how to recover');
            Assert.isFalse(expected.getMessage().contains('expired-session'),'Failure must not expose the bearer token');
            Assert.isFalse(expected.getMessage().contains('invalid_session'),'Failure must not expose the upstream response body');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldUseApexSessionWhenBearerIsUnavailable() {
        McpLightningOutService.testSessionId=null;
        McpLightningOutService.testAuthorizationHeader=null;
        McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';
        // The packaged Default record intentionally contains JWT setup values.
        // This test exercises the backward-compatible no-JWT fallback, so keep
        // its configuration independent from package metadata and certificates.
        McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(Enabled__c=true);
        RestContext.request=new RestRequest();
        Test.setMock(HttpCalloutMock.class,new ApexSessionAccessMock());
        Test.startTest();
        McpLightningOutService.BootstrapConfig result=McpLightningOutService.createBootstrapConfig(config('xdemo-mcp-admin-friend'));
        Test.stopTest();
        Assert.isNotNull(result.frontdoorUrl,'Apex session fallback should create a frontdoor URL');
    }

    private class ApexSessionAccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.isTrue(request.getHeader('Authorization').startsWith('Bearer '),'Apex session must be sent as a bearer token');
            Assert.isTrue(request.getHeader('Authorization').length() > 7,'Apex session bearer must not be blank');
            HttpResponse response=new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"frontdoor_uri":"https://example.my.salesforce.com/secur/frontdoor.jsp?otp=apex-session"}');
            return response;
        }
    }

    private class JwtBootstrapMock implements HttpCalloutMock {
        private Integer requestNumber=0;
        public HttpResponse respond(HttpRequest request) {
            requestNumber++;
            HttpResponse response=new HttpResponse();
            response.setStatusCode(200);
            if(requestNumber==1){
                Assert.areEqual('https://example.my.salesforce.com/services/oauth2/token',request.getEndpoint(),'JWT exchange should use the configured issuer');
                Assert.isTrue(request.getBody().contains('urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer'),'JWT bearer grant type should be encoded');
                Assert.isTrue(request.getBody().contains('signed-test-assertion'),'Signed assertion should be exchanged server-side');
                response.setBody('{"access_token":"jwt-access-token","instance_url":"https://example.my.salesforce.com"}');
            }else{
                Assert.areEqual('https://example.my.salesforce.com/services/oauth2/singleaccess',request.getEndpoint(),'JWT access token should be exchanged for a frontdoor URL');
                Assert.areEqual('Bearer jwt-access-token',request.getHeader('Authorization'),'JWT access token must remain in the authorization header');
                response.setBody('{"frontdoor_uri":"https://example.my.salesforce.com/secur/frontdoor.jsp?otp=jwt-session"}');
            }
            return response;
        }
    }

    @IsTest
    static void shouldUseConfiguredJwtBearerFlowForCurrentUser() {
        McpLightningOutService.testSessionId=null;
        McpLightningOutService.testAuthorizationHeader=null;
        McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';
        McpLightningOutService.testFrontdoorUrl=null;
        McpLightningOutService.testJwtAssertion='signed-test-assertion';
        McpLightningOutService.testIsSandbox=true;
        McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(
            Enabled__c=true,
            ECA_Consumer_Key__c='consumer-key',
            ECA_Certificate_Name__c='Mcp_App_Bridge_JWT'
        );
        Test.setMock(HttpCalloutMock.class,new JwtBootstrapMock());
        Test.startTest();
        McpLightningOutService.BootstrapConfig result=McpLightningOutService.createBootstrapConfig(config('xdemo-mcp-admin-friend'));
        Test.stopTest();
        Assert.areEqual(UserInfo.getUserName(),McpLightningOutService.testJwtSubject,'JWT subject should be the username for the current user ID');
        Assert.isTrue(result.frontdoorUrl.contains('otp=jwt-session'),'JWT flow should produce the one-time frontdoor URL');
    }

    @IsTest
    static void shouldRejectPartialJwtConfiguration() {
        McpLightningOutService.testSessionId=null;
        McpLightningOutService.testAuthorizationHeader=null;
        McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';
        McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(Enabled__c=true,ECA_Consumer_Key__c='consumer-key');
        Test.startTest();
        try {
            McpLightningOutService.createBootstrapConfig(config('xdemo-mcp-admin-friend'));
            Assert.fail('Expected partial JWT configuration to fail');
        } catch(McpProtocolException expected) {
            Assert.areEqual('JWT_CONFIGURATION_ERROR',expected.errorType,'Partial JWT configuration should be actionable');
        }
        Test.stopTest();
    }

    private class JwtRejectedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response=new HttpResponse();
            response.setStatusCode(400);
            response.setBody('{"error":"invalid_grant","error_description":"sensitive upstream detail"}');
            return response;
        }
    }

    @IsTest
    static void shouldClassifyRejectedJwtWithoutExposingResponse() {
        McpLightningOutService.testSessionId=null;
        McpLightningOutService.testAuthorizationHeader=null;
        McpLightningOutService.testOrgOrigin='https://example.my.salesforce.com';
        McpLightningOutService.testJwtAssertion='signed-test-assertion';
        McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(
            Enabled__c=true,
            ECA_Consumer_Key__c='consumer-key',
            ECA_Certificate_Name__c='Mcp_App_Bridge_JWT'
        );
        Test.setMock(HttpCalloutMock.class,new JwtRejectedMock());
        Test.startTest();
        try {
            McpLightningOutService.createBootstrapConfig(config('xdemo-mcp-admin-friend'));
            Assert.fail('Expected rejected JWT exchange to fail');
        } catch(McpProtocolException expected) {
            Assert.areEqual('JWT_TOKEN_REJECTED',expected.errorType,'Rejected assertion should have a safe category');
            Assert.isTrue(expected.getMessage().contains('pre-authorization'),'Failure should suggest the relevant configuration');
            Assert.isFalse(expected.getMessage().contains('sensitive upstream detail'),'Upstream response must not be exposed');
        }
        Test.stopTest();
    }
}
