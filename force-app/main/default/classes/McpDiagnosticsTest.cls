@IsTest
private class McpDiagnosticsTest {
    @IsTest static void shouldPersistEnabledInformationalDiagnosticsWithoutSecrets() {
        McpDiagnostics.testEnabled=true;
        McpDiagnostics.Entry entry=new McpDiagnostics.Entry();
        entry.stage='FRONTDOOR_VALIDATED';entry.operation='LIGHTNING_OUT_BOOTSTRAP';entry.outcome='SUCCEEDED';
        entry.configKey='demo';entry.httpStatus=200;entry.durationMs=25;entry.message='Generated https://example.my.salesforce.com/secur/frontdoor.jsp?otp=secret';
        entry.urlFingerprint=McpDiagnostics.fingerprint('https://example.my.salesforce.com/secur/frontdoor.jsp?otp=secret');
        McpDiagnostics.info(entry);
        MCP_Bridge_Log__c saved=[SELECT Level__c,Stage__c FROM MCP_Bridge_Log__c LIMIT 1];
        Assert.areEqual('INFO',saved.Level__c);
        Assert.areEqual('FRONTDOOR_VALIDATED',saved.Stage__c);
        Assert.areEqual(64,McpDiagnostics.fingerprint('https://example.my.salesforce.com/secur/frontdoor.jsp?otp=secret').length());
        String sanitized=McpDiagnostics.sanitize(entry.message);
        Assert.isFalse(sanitized.contains('secret'),'A frontdoor secret must not survive sanitization');
        Assert.isTrue(sanitized.contains('[URL_REDACTED]'),'URLs in diagnostic messages must be redacted');
    }

    @IsTest static void shouldPersistErrorsThroughImmediatePlatformEvent() {
        McpDiagnostics.testEnabled=true;
        McpDiagnostics.Entry entry=new McpDiagnostics.Entry();
        entry.stage='APPLICATION_ERROR';entry.operation='WIDGET_LIFECYCLE';entry.outcome='FAILED';
        entry.configKey='demo';entry.errorType='LIGHTNING_OUT_ERROR';entry.message='Nested frame rejected.';
        Test.startTest();
        McpDiagnostics.error(entry);
        Test.getEventBus().deliver();
        Test.stopTest();
        MCP_Bridge_Log__c saved=[SELECT Level__c,Stage__c FROM MCP_Bridge_Log__c LIMIT 1];
        Assert.areEqual('ERROR',saved.Level__c);
        Assert.areEqual('APPLICATION_ERROR',saved.Stage__c);
    }

    @IsTest static void shouldDoNothingWhenLoggingIsDisabled() {
        McpDiagnostics.testEnabled=false;
        McpDiagnostics.Entry entry=new McpDiagnostics.Entry();entry.stage='IGNORED';entry.outcome='SUCCEEDED';
        McpDiagnostics.info(entry);McpDiagnostics.error(entry);
        Test.getEventBus().deliver();
        Assert.areEqual(0,[SELECT COUNT() FROM MCP_Bridge_Log__c]);
    }

    @IsTest static void shouldAcceptOnlyKnownWidgetMilestones() {
        McpDiagnostics.testEnabled=true;
        McpLightningOutConfig.testRecords=new List<MCP_App_Bridge_LO2_Config__mdt>{
            new MCP_App_Bridge_LO2_Config__mdt(DeveloperName='demo',Enabled__c=true,App_Id__c='1Us000000000001AAA',Component_Name__c='example-demo',Resource_Uri__c='ui://example/demo',Static_Resource_Name__c='McpLightningOutHost',Display_Name__c='Demo')
        };
        Map<String,Object> accepted=McpToolRegistry.callTool(new Map<String,Object>{'name'=>'log_bridge_diagnostic','arguments'=>new Map<String,Object>{'configKey'=>'demo','stage'=>'COMPONENT_READY','outcome'=>'SUCCEEDED'}});
        Assert.isFalse((Boolean)accepted.get('isError'));
        Assert.areEqual(1,[SELECT COUNT() FROM MCP_Bridge_Log__c WHERE Stage__c='COMPONENT_READY']);
        try {
            McpToolRegistry.callTool(new Map<String,Object>{'name'=>'log_bridge_diagnostic','arguments'=>new Map<String,Object>{'configKey'=>'demo','stage'=>'ARBITRARY_STAGE','outcome'=>'SUCCEEDED'}});
            Assert.fail('Unknown widget stages must be rejected.');
        } catch (McpProtocolException expected) {
            Assert.areEqual(400,expected.httpStatus);
        }
    }

    @IsTest static void shouldReadLoggingSwitchFromCoreConfiguration() {
        McpDiagnostics.testEnabled=null;
        McpBridgeCoreConfig.testRecord=new MCP_App_Bridge_Core_Config__mdt(Enabled__c=true,Logging_Enabled__c=true);
        Assert.isTrue(McpBridgeCoreConfig.get().loggingEnabled);
        Assert.isTrue(McpDiagnostics.isEnabled());
    }
}
