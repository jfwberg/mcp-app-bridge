@IsTest
private class McpDemoRecordControllerTest {
    @IsTest static void shouldDescribeCreateAndViewAccounts() {
        McpDemoRecordController.Configuration configuration = McpDemoRecordController.describeDemo('Account', new List<String>{'Name','Industry'});
        Assert.areEqual(2, configuration.fields.size(), 'Requested fields should be described.');
        Assert.isTrue(configuration.fields[1].options.size() > 0, 'Industry should expose its picklist values.');
        String values = JSON.serialize(new List<Object>{new Map<String,Object>{'Name'=>'MCP Demo Account','Industry'=>'Technology'}});
        McpDemoRecordController.SaveResult saved = McpDemoRecordController.createRecords('Account', values);
        Assert.areEqual(1, saved.records.size(), 'One Account should be created.');
        McpDemoRecordController.ViewerResult viewed = McpDemoRecordController.viewRecords('Account', new List<Id>{(Id)saved.records[0].get('Id')}, new List<String>{'Name','Industry'});
        Assert.areEqual(1, viewed.records.size(), 'Created Account should be returned to the viewer.');
    }

    @IsTest static void shouldExplainInvalidMetadata() {
        try { McpDemoRecordController.describeDemo('DoesNotExist', null); Assert.fail('Unknown object should fail.'); }
        catch (AuraHandledException expected) { Assert.isTrue(true, 'Unknown object was rejected.'); }
        try { McpDemoRecordController.describeDemo('Account', new List<String>{'DoesNotExist'}); Assert.fail('Unknown field should fail.'); }
        catch (AuraHandledException expected) { Assert.isTrue(true, 'Unknown field was rejected.'); }
        try { McpDemoRecordController.describeDemo('Opportunity', null); Assert.fail('Non-allowlisted object should fail.'); }
        catch (AuraHandledException expected) { Assert.isTrue(true, 'Non-allowlisted object was rejected.'); }
    }
}
