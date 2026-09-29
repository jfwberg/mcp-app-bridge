/** Reads the singleton MCP App Bridge core configuration. */
public with sharing class McpBridgeCoreConfig {
    @TestVisible private static MCP_App_Bridge_Core_Config__mdt testRecord;

    public Boolean enabled = true;
    public String endpointUrl;
    public String authorizationIssuer;
    public String ecaConsumerKey;
    public String ecaCertificateName;
    public String requiredScopes = 'api';
    public String protocolVersion = '2025-11-25';
    public Integer timeoutMinutes = 30;
    public Boolean loggingEnabled = false;
    public Set<String> allowedOrigins = new Set<String>();

    public static McpBridgeCoreConfig get() {
        McpBridgeCoreConfig value = new McpBridgeCoreConfig();
        MCP_App_Bridge_Core_Config__mdt record = Test.isRunningTest() && testRecord != null
            ? testRecord
            : MCP_App_Bridge_Core_Config__mdt.getInstance('Default');
        String origin = URL.getOrgDomainUrl().toExternalForm();
        value.endpointUrl = origin + '/services/apexrest/mcpapp/mcp';
        value.authorizationIssuer = origin;
        if (record == null) {
            return value;
        }
        value.enabled = record.Enabled__c;
        value.ecaConsumerKey = record.ECA_Consumer_Key__c;
        value.ecaCertificateName = record.ECA_Certificate_Name__c;
        value.requiredScopes = defaultIfBlank(record.Required_Scopes__c, value.requiredScopes);
        value.protocolVersion = defaultIfBlank(record.Protocol_Version__c, value.protocolVersion);
        value.timeoutMinutes = record.Session_Timeout_Minutes__c == null ? 30 : Integer.valueOf(record.Session_Timeout_Minutes__c);
        value.loggingEnabled = record.Logging_Enabled__c == true;
        if (String.isNotBlank(record.Allowed_Origins__c)) {
            value.allowedOrigins.addAll(record.Allowed_Origins__c.split('[,\\n]'));
        }
        return value;
    }

    private static String defaultIfBlank(String candidate, String fallback) {
        return String.isBlank(candidate) ? fallback : candidate;
    }
}
