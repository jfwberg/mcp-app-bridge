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
        for(String origin : new List<String>{'null','unavailable','https://widget.example:443'}) {
            McpToolRegistry.callTool(new Map<String,Object>{'name'=>'log_bridge_diagnostic','arguments'=>new Map<String,Object>{'configKey'=>'demo','stage'=>'WIDGET_EFFECTIVE_ORIGIN','outcome'=>'SUCCEEDED','message'=>origin}});
        }
        Assert.areEqual(3,[SELECT COUNT() FROM MCP_Bridge_Log__c WHERE Stage__c='WIDGET_EFFECTIVE_ORIGIN']);
        // API 67 defaults queries to user mode. Inspect internal test telemetry independently
        // of the package-build user's field permissions; production access is unchanged.
        List<MCP_Bridge_Log__c> originLogs=[SELECT Details_JSON__c FROM MCP_Bridge_Log__c WHERE Stage__c='WIDGET_EFFECTIVE_ORIGIN' WITH SYSTEM_MODE];
        Assert.areEqual(3,originLogs.size());
        Set<String> observedOrigins=new Set<String>();
        for(MCP_Bridge_Log__c saved : originLogs) {
            Map<String,Object> details=(Map<String,Object>)JSON.deserializeUntyped(saved.Details_JSON__c);
            observedOrigins.add((String)details.get('origin'));
            Assert.areEqual(details.get('origin')=='null',details.get('literalNull'));
            Assert.areEqual(details.get('origin')=='unavailable',details.get('unavailable'));
        }
        Assert.areEqual(new Set<String>{'null','unavailable','https://widget.example:443'},observedOrigins);
        try {
            McpToolRegistry.callTool(new Map<String,Object>{'name'=>'log_bridge_diagnostic','arguments'=>new Map<String,Object>{'configKey'=>'demo','stage'=>'WIDGET_URL_ORIGIN','outcome'=>'SUCCEEDED','message'=>'https://widget.example/path?otp=secret'}});
            Assert.fail('Origin diagnostics must reject full URLs.');
        } catch (McpProtocolException expected) {
            Assert.areEqual(400,expected.httpStatus);
        }
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

    @IsTest static void shouldCorrelateLoadLogsAndRetainLegacyRequestIds() {
        McpDiagnostics.testEnabled=true;
        String loadId='load-0123456789abcdef0123456789abcdef';
        McpDiagnostics.setLoadCorrelationId(loadId);
        McpDiagnostics.Entry entry=new McpDiagnostics.Entry();
        entry.stage='TEST_LOAD';entry.outcome='SUCCEEDED';entry.correlationId='request-1';
        McpDiagnostics.info(entry);
        entry.stage='TEST_LOAD_ERROR';entry.outcome='FAILED';
        McpDiagnostics.error(entry);
        Test.getEventBus().deliver();
        List<MCP_Bridge_Log__c> logs=[SELECT Correlation_Id__c FROM MCP_Bridge_Log__c WITH SYSTEM_MODE];
        Assert.areEqual(2,logs.size());
        for(MCP_Bridge_Log__c saved : logs)Assert.areEqual(loadId,saved.Correlation_Id__c);
        McpDiagnostics.setLoadCorrelationId(null);
        entry.stage='TEST_LEGACY';entry.outcome='SUCCEEDED';
        McpDiagnostics.info(entry);
        Assert.areEqual('request-1',[SELECT Correlation_Id__c FROM MCP_Bridge_Log__c WHERE Stage__c='TEST_LEGACY' WITH SYSTEM_MODE LIMIT 1].Correlation_Id__c);
        try {
            McpDiagnostics.setLoadCorrelationId('invalid id');
            Assert.fail('Malformed load IDs must be rejected.');
        } catch(McpProtocolException expected) {
            Assert.areEqual(400,expected.httpStatus);
        }
    }
}
