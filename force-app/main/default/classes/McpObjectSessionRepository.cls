/** Persists one-way session hashes in MCP_Session__c. */
public without sharing class McpObjectSessionRepository implements IMcpSessionRepository {
    public McpSession createSession(String hash, String version, String clientName, String clientVersion, Integer timeoutMinutes) {
        Datetime nowValue = System.now();
        MCP_Session__c record = new MCP_Session__c(Session_Hash__c=hash, User_Id__c=UserInfo.getUserId(),
            Organization_Id__c=UserInfo.getOrganizationId(), Protocol_Version__c=version,
            Client_Name__c=clientName, Client_Version__c=clientVersion, Lifecycle_State__c='INITIALIZING',
            Created_At__c=nowValue, Last_Seen_At__c=nowValue, Expires_At__c=nowValue.addMinutes(timeoutMinutes));
        Database.insert(record, AccessLevel.SYSTEM_MODE);
        return toDomain(record);
    }
    public McpSession getSession(String hash) {
        List<MCP_Session__c> records = [SELECT Id, Session_Hash__c, User_Id__c, Organization_Id__c,
            Protocol_Version__c, Lifecycle_State__c, Expires_At__c FROM MCP_Session__c
            WHERE Session_Hash__c=:hash WITH SYSTEM_MODE LIMIT 1];
        return records.isEmpty() ? null : toDomain(records[0]);
    }
    public void markInitialized(Id recordId) { updateRecord(recordId, 'READY', null); }
    public void touch(Id recordId, Integer timeoutMinutes) { updateRecord(recordId, null, System.now().addMinutes(timeoutMinutes)); }
    public void terminate(Id recordId) { updateRecord(recordId, 'TERMINATED', System.now()); }
    private void updateRecord(Id recordId, String state, Datetime expiry) {
        MCP_Session__c record = new MCP_Session__c(Id=recordId, Last_Seen_At__c=System.now());
        if (state != null) record.Lifecycle_State__c = state;
        if (expiry != null) record.Expires_At__c = expiry;
        Database.update(record, AccessLevel.SYSTEM_MODE);
    }
    private static McpSession toDomain(MCP_Session__c record) {
        McpSession value = new McpSession(); value.recordId=record.Id; value.sessionHash=record.Session_Hash__c;
        value.userId=record.User_Id__c; value.organizationId=record.Organization_Id__c;
        value.protocolVersion=record.Protocol_Version__c; value.lifecycleState=record.Lifecycle_State__c;
        value.expiresAt=record.Expires_At__c; return value;
    }
}
