// Isolated /services/oauth2/singleaccess diagnostic.
// Run with Execute Anonymous as the user who will load the Lightning Out UI.
// This deliberately logs only status information, never the session ID or
// returned one-time frontdoor URL.

String instanceUrl = URL.getOrgDomainUrl().toExternalForm().removeEnd('/');
String sessionId = UserInfo.getSessionId();

System.debug(LoggingLevel.ERROR, 'singleaccess diagnostic: instanceUrl=' + instanceUrl);
System.debug(LoggingLevel.ERROR,
    'singleaccess diagnostic: Apex session available=' + String.valueOf(String.isNotBlank(sessionId)));

if (String.isBlank(sessionId)) {
    System.debug(LoggingLevel.ERROR,
        'singleaccess diagnostic: STOPPED because UserInfo.getSessionId() returned no session.');
} else {
    HttpRequest request = new HttpRequest();
    request.setEndpoint(instanceUrl + '/services/oauth2/singleaccess');
    request.setMethod('POST');
    request.setHeader('Accept', 'application/json');
    request.setHeader('Authorization', 'Bearer ' + sessionId);
    request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    request.setBody('');
    request.setTimeout(10000);

    HttpResponse response = new Http().send(request);
    System.debug(LoggingLevel.ERROR,
        'singleaccess diagnostic: HTTP ' + response.getStatusCode() + ' ' + response.getStatus());

    if (response.getStatusCode() == 200) {
        Map<String, Object> payload =
            (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        String frontdoorUrl = (String) payload.get('frontdoor_uri');
        System.debug(LoggingLevel.ERROR,
            'singleaccess diagnostic: frontdoor_uri returned=' +
            String.valueOf(String.isNotBlank(frontdoorUrl)));
    } else {
        // Safe for this deliberate administrator-run diagnostic. The request's
        // bearer is not included in Salesforce's error response.
        System.debug(LoggingLevel.ERROR,
            'singleaccess diagnostic: response=' + response.getBody());
    }
}
