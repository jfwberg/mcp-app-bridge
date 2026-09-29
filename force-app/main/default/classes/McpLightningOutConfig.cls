/** Resolves enabled Lightning Out 2.0 bridge entries from custom metadata. */
public with sharing class McpLightningOutConfig {
    @TestVisible private static List<MCP_App_Bridge_LO2_Config__mdt> testRecords;

    public String key;
    public String appId;
    public String componentName;
    public String resourceUri;
    public String staticResourceName;
    public String displayName;
    public String description;
    public String toolName;
    public String inputSchemaJson;

    public static List<McpLightningOutConfig> listEnabled() {
        List<MCP_App_Bridge_LO2_Config__mdt> records = Test.isRunningTest() && testRecords != null
            ? testRecords
            : [SELECT DeveloperName, App_Id__c, Component_Name__c, Resource_Uri__c,
                Static_Resource_Name__c, Display_Name__c, Description__c, Input_Schema_JSON__c
               FROM MCP_App_Bridge_LO2_Config__mdt
               WHERE Enabled__c = TRUE
               WITH USER_MODE
               ORDER BY DeveloperName];
        List<McpLightningOutConfig> results = new List<McpLightningOutConfig>();
        for (MCP_App_Bridge_LO2_Config__mdt record : records) {
            results.add(fromRecord(record));
        }
        return results;
    }

    public static McpLightningOutConfig getByResourceUri(String resourceUri) {
        for (McpLightningOutConfig config : listEnabled()) {
            if (config.resourceUri == resourceUri) {
                return config;
            }
        }
        throw new McpProtocolException(-32602, 404, 'Resource not found.');
    }

    public static McpLightningOutConfig getByKey(String key) {
        for (McpLightningOutConfig config : listEnabled()) {
            if (config.key == key) {
                return config;
            }
        }
        throw new McpProtocolException(-32602, 404, 'Lightning Out configuration not found.');
    }

    public List<String> inputNames() {
        List<String> names = new List<String>();
        if (String.isBlank(inputSchemaJson)) return names;
        try {
            Map<String,Object> schema = (Map<String,Object>)JSON.deserializeUntyped(inputSchemaJson);
            Map<String,Object> properties = schema.get('properties') instanceof Map<String,Object>
                ? (Map<String,Object>)schema.get('properties')
                : new Map<String,Object>();
            names.addAll(properties.keySet());
            names.sort();
            return names;
        } catch (Exception invalidSchema) {
            throw new McpProtocolException(-32603, 503, 'Configured tool input schema is invalid.');
        }
    }

    private static McpLightningOutConfig fromRecord(MCP_App_Bridge_LO2_Config__mdt record) {
        McpLightningOutConfig value = new McpLightningOutConfig();
        value.key = record.DeveloperName;
        value.appId = record.App_Id__c;
        value.componentName = record.Component_Name__c;
        value.resourceUri = record.Resource_Uri__c;
        value.staticResourceName = record.Static_Resource_Name__c;
        value.displayName = String.isBlank(record.Display_Name__c) ? record.DeveloperName : record.Display_Name__c;
        value.description = record.Description__c;
        value.toolName = 'open_' + record.DeveloperName.toLowerCase();
        value.inputSchemaJson = record.Input_Schema_JSON__c;
        return value;
    }
}
