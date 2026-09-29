/**
 * Exchanges the current authenticated Salesforce session for a short-lived,
 * single-use Lightning Out 2.0 frontdoor URL.
 */
public with sharing class McpLightningOutService {
    private static final String SINGLE_ACCESS_PATH = '/services/oauth2/singleaccess';
    @TestVisible private static String testSessionId;
    @TestVisible private static String testAuthorizationHeader;
    @TestVisible private static String testOrgOrigin;
    @TestVisible private static String testFrontdoorUrl;
    @TestVisible private static String testJwtAssertion;
    @TestVisible private static String testJwtSubject;
    @TestVisible private static Boolean testIsSandbox;
    @TestVisible private static Integer testBootstrapInvocationCount=0;

    /** Runtime values injected into the MCP App resource. */
    public class BootstrapConfig {
        public String appId;
        public String componentName;
        public String frontdoorUrl;
        public String orgOrigin;
        public String lightningOrigin;
        public Boolean loggingEnabled;
        public List<String> inputNames;
        public List<McpEventMappingConfig.ClientMapping> eventMappings;
    }

    /**
     * Generates the one-time authentication configuration used to mount Lightning Out.
     * @return Validated Lightning Out bootstrap values
     * @throws McpProtocolException when configuration or the UI Bridge exchange fails
     */
    public static BootstrapConfig createBootstrapConfig(McpLightningOutConfig lightningConfig) {
        if(Test.isRunningTest()) testBootstrapInvocationCount++;
        if (lightningConfig == null || String.isBlank(lightningConfig.appId)
            || !Pattern.matches('^[A-Za-z0-9]{18}$', lightningConfig.appId)) {
            throw new McpProtocolException(-32603, 503, 'Lightning Out application is not configured.');
        }
        String componentName = lightningConfig.componentName;
        if (!Pattern.matches('^[a-z][a-z0-9_]*-[a-z][a-zA-Z0-9-]*$', componentName)) {
            throw new McpProtocolException(-32603, 503, 'Lightning Out component is not configured correctly.');
        }

        String orgOrigin = Test.isRunningTest() && testOrgOrigin != null
            ? testOrgOrigin
            : URL.getOrgDomainUrl().toExternalForm();
        SessionCredential credential = resolveSessionCredential(orgOrigin);
        if (Test.isRunningTest() && testFrontdoorUrl != null) {
            BootstrapConfig testedResult=buildResult(lightningConfig, testFrontdoorUrl, orgOrigin);
            logBootstrap('FRONTDOOR_VALIDATED','SUCCEEDED',lightningConfig,null,null,null,null,'A valid test frontdoor URL was supplied.',testFrontdoorUrl,new Map<String,Object>{'credentialSource'=>credential.source,'testMode'=>true});
            return testedResult;
        }
        HttpRequest request = new HttpRequest();
        request.setEndpoint(credential.instanceUrl + SINGLE_ACCESS_PATH);
        request.setMethod('POST');
        request.setHeader('Accept', 'application/json');
        // code-analyzer-suppress-next-line ApexSuggestUsingNamedCred -- A Named Credential cannot forward the current MCP caller's authenticated Salesforce session to this same-org UI Bridge exchange.
        request.setHeader('Authorization', 'Bearer ' + credential.accessToken);
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody('');
        request.setTimeout(10000);

        HttpResponse response; Long startedAt=System.now().getTime();
        try {
            response = new Http().send(request);
        } catch (CalloutException calloutFailure) {
            logBootstrap('SINGLE_ACCESS_CALLOUT','FAILED',lightningConfig,null,System.now().getTime()-startedAt,null,'UI_SESSION_UNREACHABLE','Salesforce single-access callout failed.',null,new Map<String,Object>{'credentialSource'=>credential.source});
            throw bootstrapFailure('UI_SESSION_UNREACHABLE', 502,
                'Salesforce could not be reached to create the authenticated interface. Please retry.');
        }
        logBootstrap('SINGLE_ACCESS_RESPONSE',response.getStatusCode()==200?'SUCCEEDED':'FAILED',lightningConfig,response.getStatusCode(),System.now().getTime()-startedAt,null,response.getStatusCode()==200?null:'UI_SESSION_REJECTED','Salesforce single-access endpoint responded.',null,new Map<String,Object>{'credentialSource'=>credential.source,'responseBytes'=>response.getBody()==null?0:response.getBody().length()});
        if (response.getStatusCode() != 200) {
            Integer statusCode = response.getStatusCode();
            if (statusCode == 401 || statusCode == 403) {
                throw bootstrapFailure('UI_SESSION_AUTH_EXPIRED', 401,
                    'Your Salesforce authentication can no longer create an interface session. Reconnect the MCP app and try again.');
            }
            throw bootstrapFailure('UI_SESSION_REJECTED', 502,
                'Salesforce could not create the authenticated interface (HTTP ' + statusCode + '). Please retry or reconnect the MCP app.');
        }

        Map<String, Object> responseBody;
        try {
            responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        } catch (JSONException invalidResponse) {
            throw bootstrapFailure('UI_SESSION_INVALID_RESPONSE', 502,
                'Salesforce returned an invalid interface-session response. Please retry.');
        }
        String frontdoorUrl = (String) responseBody.get('frontdoor_uri');
        BootstrapConfig result=buildResult(lightningConfig, frontdoorUrl, orgOrigin);
        logBootstrap('FRONTDOOR_VALIDATED','SUCCEEDED',lightningConfig,response.getStatusCode(),System.now().getTime()-startedAt,null,null,'A valid one-time frontdoor URL was generated.',frontdoorUrl,new Map<String,Object>{'credentialSource'=>credential.source});
        return result;
    }

    private class SessionCredential {
        public String accessToken;
        public String instanceUrl;
        public String source;
        public SessionCredential(String accessToken, String instanceUrl, String source) {
            this.accessToken = accessToken;
            this.instanceUrl = instanceUrl.removeEnd('/');
            this.source = source;
        }
    }

    private static SessionCredential resolveSessionCredential(String orgOrigin) {
        if (Test.isRunningTest() && testSessionId != null) {
            return new SessionCredential(testSessionId, orgOrigin, 'TEST_SESSION');
        }
        if (Test.isRunningTest() && testAuthorizationHeader != null) {
            return new SessionCredential(bearerValue(testAuthorizationHeader), orgOrigin, 'TEST_BEARER');
        }
        McpBridgeCoreConfig coreConfig = McpBridgeCoreConfig.get();
        Boolean hasConsumerKey = String.isNotBlank(coreConfig.ecaConsumerKey);
        Boolean hasCertificate = String.isNotBlank(coreConfig.ecaCertificateName);
        if (hasConsumerKey || hasCertificate) {
            if (!hasConsumerKey || !hasCertificate) {
                throw bootstrapFailure('JWT_CONFIGURATION_ERROR', 503,
                    'JWT interface authentication is incomplete. Configure both the ECA Consumer Key and ECA Certificate Name.');
            }
            return exchangeJwtForToken(coreConfig, orgOrigin);
        }
        RestRequest inboundRequest = RestContext.request;
        if (inboundRequest != null && inboundRequest.headers != null) {
            String authorization = inboundRequest.headers.get('Authorization');
            if (String.isBlank(authorization)) {
                authorization = inboundRequest.headers.get('authorization');
            }
            String token = bearerValue(authorization);
            if (String.isNotBlank(token)) {
                return new SessionCredential(token, orgOrigin, 'INBOUND_BEARER');
            }
            for (String headerName : inboundRequest.headers.keySet()) {
                if (headerName != null && headerName.equalsIgnoreCase('Authorization')) {
                    token = bearerValue(inboundRequest.headers.get(headerName));
                    if (String.isNotBlank(token)) {
                        return new SessionCredential(token, orgOrigin, 'INBOUND_BEARER');
                    }
                }
            }

            // Salesforce removes the inbound OAuth Authorization header before
            // Apex REST executes. Try the authenticated execution context as a
            // fallback; availability depends on the OAuth/session context.
            String sessionId = UserInfo.getSessionId();
            if (String.isNotBlank(sessionId)) {
                return new SessionCredential(sessionId, orgOrigin, 'APEX_SESSION');
            }

            throw new McpProtocolException(-32603, 401,
                'Neither the inbound Authorization bearer nor an Apex session ID is available.');
        }
        throw new McpProtocolException(-32603,401,'Authorization bearer is unavailable because no Apex REST request context exists.');
    }

    private static SessionCredential exchangeJwtForToken(McpBridgeCoreConfig config, String orgOrigin) {
        Boolean isSandbox = Test.isRunningTest() && testIsSandbox != null
            ? testIsSandbox
            : [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        String audience = isSandbox ? 'https://test.salesforce.com' : 'https://login.salesforce.com';
        String subject = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId() WITH USER_MODE].Username;
        if (Test.isRunningTest()) testJwtSubject = subject;
        String assertion = buildSignedJwt(config.ecaConsumerKey, subject, audience, config.ecaCertificateName);
        HttpRequest request = new HttpRequest();
        request.setEndpoint(orgOrigin.removeEnd('/') + '/services/oauth2/token');
        request.setMethod('POST');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody('grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8')
            + '&assertion=' + EncodingUtil.urlEncode(assertion, 'UTF-8'));
        request.setTimeout(10000);
        HttpResponse response; Long startedAt=System.now().getTime();
        try {
            response = new Http().send(request);
        } catch (CalloutException calloutFailure) {
            logBootstrap('JWT_TOKEN_CALLOUT','FAILED',null,null,System.now().getTime()-startedAt,null,'JWT_TOKEN_UNREACHABLE','Salesforce JWT token callout failed.',null,null);
            throw bootstrapFailure('JWT_TOKEN_UNREACHABLE', 502,
                'Salesforce could not be reached for JWT interface authentication. Please retry.');
        }
        if (response.getStatusCode() != 200) {
            logBootstrap('JWT_TOKEN_RESPONSE','FAILED',null,response.getStatusCode(),System.now().getTime()-startedAt,null,'JWT_TOKEN_REJECTED','Salesforce JWT token endpoint rejected authentication.',null,new Map<String,Object>{'responseBytes'=>response.getBody()==null?0:response.getBody().length()});
            throw bootstrapFailure('JWT_TOKEN_REJECTED', 401,
                'Salesforce rejected JWT interface authentication. Verify the ECA, certificate, and current-user pre-authorization.');
        }
        Map<String,Object> payload;
        try {
            payload = (Map<String,Object>)JSON.deserializeUntyped(response.getBody());
        } catch (JSONException invalidResponse) {
            throw bootstrapFailure('JWT_TOKEN_INVALID_RESPONSE', 502,
                'Salesforce returned an invalid JWT authentication response. Please retry.');
        }
        String accessToken = (String)payload.get('access_token');
        String instanceUrl = (String)payload.get('instance_url');
        if (String.isBlank(accessToken) || String.isBlank(instanceUrl)) {
            throw bootstrapFailure('JWT_TOKEN_INVALID_RESPONSE', 502,
                'Salesforce returned an invalid JWT authentication response. Please retry.');
        }
        return new SessionCredential(accessToken, instanceUrl, 'JWT_BEARER');
    }

    private static String buildSignedJwt(String issuer, String subject, String audience, String certificateName) {
        if (Test.isRunningTest() && testJwtAssertion != null) return testJwtAssertion;
        try {
            Auth.JWT jwt = new Auth.JWT();
            jwt.setIss(issuer);
            jwt.setSub(subject);
            jwt.setAud(audience);
            return new Auth.JWS(jwt, certificateName).getCompactSerialization();
        } catch (Exception signingFailure) {
            throw bootstrapFailure('JWT_SIGNING_ERROR', 503,
                'Salesforce could not sign the JWT interface assertion. Verify the configured certificate name.');
        }
    }

    private static String bearerValue(String authorization) {
        return String.isNotBlank(authorization) && authorization.toLowerCase().startsWith('bearer ')
            ? authorization.substring(7).trim()
            : null;
    }

    private static BootstrapConfig buildResult(McpLightningOutConfig lightningConfig, String frontdoorUrl, String orgOrigin) {
        validateFrontdoorUrl(frontdoorUrl, orgOrigin);
        BootstrapConfig result = new BootstrapConfig();
        result.appId = lightningConfig.appId;
        result.componentName = lightningConfig.componentName;
        result.frontdoorUrl = frontdoorUrl;
        result.orgOrigin = orgOrigin;
        result.lightningOrigin = orgOrigin.replace('.my.salesforce.com', '.lightning.force.com');
        result.loggingEnabled = McpDiagnostics.isEnabled();
        result.inputNames = lightningConfig.inputNames();
        result.eventMappings = McpEventMappingConfig.clientMappings(lightningConfig.key);
        return result;
    }

    private static void validateFrontdoorUrl(String frontdoorUrl, String orgOrigin) {
        if (String.isBlank(frontdoorUrl)
            || !frontdoorUrl.startsWith(orgOrigin + '/secur/frontdoor.jsp?')
            || !frontdoorUrl.contains('otp=')) {
            throw bootstrapFailure('UI_SESSION_INVALID_FRONTDOOR', 502,
                'Salesforce did not return a usable authenticated interface URL. Please reconnect the MCP app and try again.');
        }
    }

    private static McpProtocolException bootstrapFailure(String errorType, Integer httpStatus, String message) {
        return new McpProtocolException(-32603, httpStatus, message, errorType);
    }
    private static void logBootstrap(String stage,String outcome,McpLightningOutConfig config,Integer httpStatus,Long duration,String operation,String errorType,String message,String frontdoorUrl,Map<String,Object> details){
        McpDiagnostics.Entry entry=new McpDiagnostics.Entry();entry.stage=stage;entry.operation=String.isBlank(operation)?'LIGHTNING_OUT_BOOTSTRAP':operation;entry.outcome=outcome;
        entry.configKey=config==null?null:config.key;entry.httpStatus=httpStatus;entry.durationMs=duration;entry.errorType=errorType;entry.message=message;
        entry.details=details;entry.urlFingerprint=McpDiagnostics.fingerprint(frontdoorUrl);
        if(outcome=='FAILED')McpDiagnostics.error(entry);else McpDiagnostics.info(entry);
    }
}
