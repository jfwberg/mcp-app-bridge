/** Resolves component event routes without embedding component knowledge in the bridge. */
public with sharing class McpEventMappingConfig {
    @TestVisible private static List<McpEventMappingConfig> testMappings;
    public String key;
    public String configKey;
    public String direction;
    public String eventName;
    public String hostAction;
    public String instructions;
    public Integer maxPayloadCharacters;
    public String toolName;
    public String toolTitle;
    public String toolDescription;
    public String inputSchemaJson;

    public class ClientMapping {
        public String key;
        public String eventName;
        public String direction;
    }

    public static List<McpEventMappingConfig> listForConfig(String configKey) {
        if (Test.isRunningTest() && testMappings != null) return filter(testMappings, configKey);
        List<McpEventMappingConfig> results = new List<McpEventMappingConfig>();
        for (MCP_App_Bridge_Event_Mapping__mdt record : [
            SELECT DeveloperName, Lightning_Out_Config__r.DeveloperName, Direction__c,
                LWC_Event_Name__c, Host_Action__c, LLM_Instructions__c, Max_Payload_Characters__c,
                MCP_Tool_Name__c, Tool_Title__c, Tool_Description__c, Input_Schema_JSON__c
            FROM MCP_App_Bridge_Event_Mapping__mdt
            WHERE Enabled__c = TRUE AND Lightning_Out_Config__r.DeveloperName = :configKey
            WITH USER_MODE
            ORDER BY DeveloperName
        ]) results.add(fromRecord(record));
        return results;
    }

    public static List<ClientMapping> clientMappings(String configKey) {
        List<ClientMapping> results = new List<ClientMapping>();
        for (McpEventMappingConfig mapping : listForConfig(configKey)) {
            ClientMapping client = new ClientMapping();
            client.key = mapping.key;
            client.eventName = mapping.eventName;
            client.direction = mapping.direction;
            results.add(client);
        }
        return results;
    }

    public static McpEventMappingConfig require(String configKey, String mappingKey) {
        for (McpEventMappingConfig mapping : listForConfig(configKey)) if (mapping.key == mappingKey) return mapping;
        throw new McpProtocolException(-32602, 404, 'Event mapping not found.');
    }

    private static List<McpEventMappingConfig> filter(List<McpEventMappingConfig> source, String configKey) {
        List<McpEventMappingConfig> results = new List<McpEventMappingConfig>();
        for (McpEventMappingConfig mapping : source) if (mapping.configKey == configKey) results.add(mapping);
        return results;
    }

    @TestVisible
    private static McpEventMappingConfig fromRecord(MCP_App_Bridge_Event_Mapping__mdt record) {
        McpEventMappingConfig value = new McpEventMappingConfig();
        value.key = record.DeveloperName;
        value.configKey = record.Lightning_Out_Config__r.DeveloperName;
        value.direction = record.Direction__c;
        value.eventName = record.LWC_Event_Name__c;
        value.hostAction = record.Host_Action__c;
        value.instructions = record.LLM_Instructions__c;
        value.maxPayloadCharacters = record.Max_Payload_Characters__c == null ? 32768 : record.Max_Payload_Characters__c.intValue();
        value.toolName = record.MCP_Tool_Name__c;
        value.toolTitle = record.Tool_Title__c;
        value.toolDescription = record.Tool_Description__c;
        value.inputSchemaJson = record.Input_Schema_JSON__c;
        return value;
    }
}
