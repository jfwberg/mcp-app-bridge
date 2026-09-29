@IsTest
private class McpEventMappingConfigTest {
    @IsTest
    static void shouldResolvePackagedMappingsAndClientProjection() {
        MCP_App_Bridge_Event_Mapping__mdt packagedRecord = [
            SELECT DeveloperName, Lightning_Out_Config__r.DeveloperName, Direction__c,
                LWC_Event_Name__c, Host_Action__c, LLM_Instructions__c, Max_Payload_Characters__c,
                MCP_Tool_Name__c, Tool_Title__c, Tool_Description__c, Input_Schema_JSON__c
            FROM MCP_App_Bridge_Event_Mapping__mdt
            WHERE DeveloperName = 'demo_records_created'
            LIMIT 1
        ];
        McpEventMappingConfig packagedMapping = McpEventMappingConfig.fromRecord(packagedRecord);
        McpEventMappingConfig.testMappings = new List<McpEventMappingConfig>{ packagedMapping };

        Test.startTest();
        List<McpEventMappingConfig> mappings = McpEventMappingConfig.listForConfig('demo_record_creator');
        List<McpEventMappingConfig.ClientMapping> clientMappings = McpEventMappingConfig.clientMappings('demo_record_creator');
        Test.stopTest();

        Assert.areEqual(1, mappings.size(), 'The packaged creator event should resolve from metadata when enabled by a subscriber.');
        Assert.areEqual('demo_records_created', mappings[0].key, 'The mapping developer name should be its stable route key.');
        Assert.areEqual('records_created', mappings[0].eventName, 'The configured DOM event should be resolved.');
        Assert.areEqual('SEND_MESSAGE', mappings[0].hostAction, 'The host action should be resolved.');
        Assert.areEqual(1, clientMappings.size(), 'The creator event should be projected to the generic browser host.');
        Assert.areEqual('LWC_TO_HOST', clientMappings[0].direction, 'The client projection should identify outbound messages generically.');
    }
}
