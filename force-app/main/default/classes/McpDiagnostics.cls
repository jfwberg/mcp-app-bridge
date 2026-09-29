/** Opt-in, secret-safe diagnostics for MCP transport and Lightning Out bootstrap. */
public without sharing class McpDiagnostics {
    @TestVisible private static Boolean testEnabled;

    public class Entry {
        public String stage;
        public String operation;
        public String outcome;
        public String correlationId;
        public String configKey;
        public String mcpMethod;
        public String toolName;
        public Integer httpStatus;
        public Long durationMs;
        public String errorType;
        public String message;
        public Map<String,Object> details;
        public String urlFingerprint;
    }

    public static Boolean isEnabled() {
        return testEnabled != null ? testEnabled : McpBridgeCoreConfig.get().loggingEnabled;
    }

    /** Persists successful milestones in the current transaction. Logging must never break MCP work. */
    public static void info(Entry entry) {
        if (!isEnabled() || entry == null) {
            return;
        }
        try {
            insert toRecord(entry, 'INFO');
        } catch (Exception ignored) {
            // Diagnostics are deliberately best-effort.
        }
    }

    /** Publishes failures immediately so delivery is independent of a later transaction rollback. */
    public static void error(Entry entry) {
        if (!isEnabled() || entry == null) {
            return;
        }
        try {
            EventBus.publish(toEvent(entry));
        } catch (Exception ignored) {
            // The primary request must retain its original failure semantics.
        }
    }

    public static String fingerprint(String sensitiveValue) {
        return String.isBlank(sensitiveValue) ? null
            : EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(sensitiveValue))).toLowerCase();
    }

    public static String correlationId(Object requestId) {
        return requestId == null ? null : truncateValue(String.valueOf(requestId), 255);
    }

    public static void persistEvents(List<MCP_Bridge_Log_Event__e> events) {
        List<MCP_Bridge_Log__c> records = new List<MCP_Bridge_Log__c>();
        for (MCP_Bridge_Log_Event__e eventRecord : events) {
            records.add(new MCP_Bridge_Log__c(
                Occurred_At__c=eventRecord.Occurred_At__c == null ? System.now() : eventRecord.Occurred_At__c,
                Level__c='ERROR', Stage__c=eventRecord.Stage__c, Operation__c=eventRecord.Operation__c,
                Outcome__c='FAILED', Correlation_Id__c=eventRecord.Correlation_Id__c,
                Config_Key__c=eventRecord.Config_Key__c, MCP_Method__c=eventRecord.MCP_Method__c,
                Tool_Name__c=eventRecord.Tool_Name__c, HTTP_Status__c=eventRecord.HTTP_Status__c,
                Duration_Ms__c=eventRecord.Duration_Ms__c, Error_Type__c=eventRecord.Error_Type__c,
                Message__c=eventRecord.Message__c, Details_JSON__c=eventRecord.Details_JSON__c,
                URL_Fingerprint__c=eventRecord.URL_Fingerprint__c, User_Id__c=eventRecord.User_Id__c,
                Organization_Id__c=eventRecord.Organization_Id__c
            ));
        }
        // code-analyzer-suppress-next-line ApexCRUDViolation -- The platform-event subscriber must persist internal error telemetry even when the originating user transaction rolls back; access to the resulting records remains permission-set controlled.
        if (!records.isEmpty()) Database.insert(records, false);
    }

    private static MCP_Bridge_Log__c toRecord(Entry entry, String level) {
        return new MCP_Bridge_Log__c(
            Occurred_At__c=System.now(), Level__c=level, Stage__c=truncateValue(entry.stage,80),
            Operation__c=truncateValue(entry.operation,80), Outcome__c=truncateValue(entry.outcome,40),
            Correlation_Id__c=truncateValue(entry.correlationId,255), Config_Key__c=truncateValue(entry.configKey,80),
            MCP_Method__c=truncateValue(entry.mcpMethod,80), Tool_Name__c=truncateValue(entry.toolName,100),
            HTTP_Status__c=entry.httpStatus, Duration_Ms__c=entry.durationMs,
            Error_Type__c=truncateValue(entry.errorType,100), Message__c=truncateValue(sanitize(entry.message),32768),
            Details_JSON__c=detailsJson(entry.details,32768), URL_Fingerprint__c=truncateValue(entry.urlFingerprint,64),
            User_Id__c=UserInfo.getUserId(), Organization_Id__c=UserInfo.getOrganizationId()
        );
    }

    private static MCP_Bridge_Log_Event__e toEvent(Entry entry) {
        return new MCP_Bridge_Log_Event__e(
            Occurred_At__c=System.now(), Stage__c=truncateValue(entry.stage,80), Operation__c=truncateValue(entry.operation,80),
            Correlation_Id__c=truncateValue(entry.correlationId,255), Config_Key__c=truncateValue(entry.configKey,80),
            MCP_Method__c=truncateValue(entry.mcpMethod,80), Tool_Name__c=truncateValue(entry.toolName,100),
            HTTP_Status__c=entry.httpStatus, Duration_Ms__c=entry.durationMs,
            Error_Type__c=truncateValue(entry.errorType,100), Message__c=truncateValue(sanitize(entry.message),255),
            Details_JSON__c=detailsJson(entry.details,255), URL_Fingerprint__c=truncateValue(entry.urlFingerprint,64),
            User_Id__c=UserInfo.getUserId(), Organization_Id__c=UserInfo.getOrganizationId()
        );
    }

    private static String detailsJson(Map<String,Object> details, Integer maximum) {
        return details == null || details.isEmpty() ? null : truncateValue(JSON.serialize(details), maximum);
    }

    private static String truncateValue(String value, Integer maximum) {
        return value == null || value.length() <= maximum ? value : value.substring(0, maximum);
    }

    @TestVisible private static String sanitize(String value) {
        if (value == null) return null;
        return value.replaceAll('(?i)Bearer\\s+[^\\s,;]+','Bearer [REDACTED]')
            .replaceAll('(?i)(otp|access_token|assertion)=([^\\s&]+)','$1=[REDACTED]')
            .replaceAll('(?i)https?://\\S+','[URL_REDACTED]');
    }
}
