// MCP App Bridge JWT/frontdoor diagnostic.
//
// Run this as the affected user with Execute Anonymous. Update only the two
// configuration values below. The script deliberately does not log the signed
// JWT, access token, or one-time frontdoor URL.

String consumerKey = 'REPLACE_WITH_ECA_CONSUMER_KEY';
String certificateDeveloperName = 'REPLACE_WITH_CERTIFICATE_DEVELOPER_NAME';

Organization currentOrg = [
    SELECT IsSandbox
    FROM Organization
    LIMIT 1
];
String audience = currentOrg.IsSandbox
    ? 'https://test.salesforce.com'
    : 'https://login.salesforce.com';
String tokenEndpointBase = URL.getOrgDomainUrl().toExternalForm().removeEnd('/');
String subject = [
    SELECT Username
    FROM User
    WHERE Id = :UserInfo.getUserId()
].Username;

System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: isSandbox=' + currentOrg.IsSandbox);
System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: audience=' + audience);
System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: tokenEndpointBase=' + tokenEndpointBase);
System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: subject=' + subject);
System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: certificate=' + certificateDeveloperName);

Auth.JWT jwt = new Auth.JWT();
jwt.setIss(consumerKey);
jwt.setSub(subject);
jwt.setAud(audience);

String assertion;
try {
    assertion = new Auth.JWS(jwt, certificateDeveloperName).getCompactSerialization();
    System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: assertion signed successfully');
} catch (Exception signingError) {
    System.debug(LoggingLevel.ERROR,
        'MCP JWT diagnostic: SIGNING FAILED: ' + signingError.getTypeName() + ': ' + signingError.getMessage());
    throw signingError;
}

HttpRequest tokenRequest = new HttpRequest();
// The JWT audience is the Salesforce login domain, but the request itself is
// sent to this org's My Domain endpoint.
tokenRequest.setEndpoint(tokenEndpointBase + '/services/oauth2/token');
tokenRequest.setMethod('POST');
tokenRequest.setHeader('Accept', 'application/json');
tokenRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');
tokenRequest.setBody(
    'grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8')
    + '&assertion=' + EncodingUtil.urlEncode(assertion, 'UTF-8')
);
tokenRequest.setTimeout(10000);

HttpResponse tokenResponse = new Http().send(tokenRequest);
System.debug(LoggingLevel.ERROR,
    'MCP JWT diagnostic: token exchange HTTP ' + tokenResponse.getStatusCode() + ' ' + tokenResponse.getStatus());

if (tokenResponse.getStatusCode() != 200) {
    // Salesforce OAuth failures normally contain only "error" and
    // "error_description". Log the body here for this deliberate admin-run
    // diagnostic; it never contains the assertion sent in the request.
    System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: token error=' + tokenResponse.getBody());
} else {
    Map<String, Object> tokenPayload =
        (Map<String, Object>) JSON.deserializeUntyped(tokenResponse.getBody());
    String accessToken = (String) tokenPayload.get('access_token');
    String instanceUrl = (String) tokenPayload.get('instance_url');

    System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: token exchange succeeded');
    System.debug(LoggingLevel.ERROR, 'MCP JWT diagnostic: instanceUrl=' + instanceUrl);
    System.debug(LoggingLevel.ERROR,
        'MCP JWT diagnostic: access token returned=' + String.valueOf(String.isNotBlank(accessToken)));

    HttpRequest singleAccessRequest = new HttpRequest();
    singleAccessRequest.setEndpoint(instanceUrl.removeEnd('/') + '/services/oauth2/singleaccess');
    singleAccessRequest.setMethod('POST');
    singleAccessRequest.setHeader('Accept', 'application/json');
    singleAccessRequest.setHeader('Authorization', 'Bearer ' + accessToken);
    singleAccessRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    singleAccessRequest.setBody('');
    singleAccessRequest.setTimeout(10000);

    HttpResponse singleAccessResponse = new Http().send(singleAccessRequest);
    System.debug(LoggingLevel.ERROR,
        'MCP JWT diagnostic: singleaccess HTTP ' + singleAccessResponse.getStatusCode()
        + ' ' + singleAccessResponse.getStatus());

    if (singleAccessResponse.getStatusCode() == 200) {
        Map<String, Object> frontdoorPayload =
            (Map<String, Object>) JSON.deserializeUntyped(singleAccessResponse.getBody());
        String frontdoorUrl = (String) frontdoorPayload.get('frontdoor_uri');
        System.debug(LoggingLevel.ERROR,
            'MCP JWT diagnostic: frontdoor URL returned=' + String.valueOf(String.isNotBlank(frontdoorUrl)));
    } else {
        System.debug(LoggingLevel.ERROR,
            'MCP JWT diagnostic: singleaccess error=' + singleAccessResponse.getBody());
    }
}
