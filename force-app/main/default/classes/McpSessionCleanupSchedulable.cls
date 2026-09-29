/** Removes expired and terminated MCP sessions. */
public with sharing class McpSessionCleanupSchedulable implements Schedulable {
    public static final String CRON_HOURLY='0 0 * * * ?';
    public void execute(SchedulableContext context){
        List<MCP_Session__c> expired=[SELECT Id FROM MCP_Session__c WHERE Expires_At__c<:System.now() OR Lifecycle_State__c='TERMINATED' WITH USER_MODE LIMIT 10000];
        if(!expired.isEmpty()) { Database.delete(expired,false,AccessLevel.USER_MODE); }
    }
    public static String scheduleHourly(){ return System.schedule('mcpapp MCP session cleanup',CRON_HOURLY,new McpSessionCleanupSchedulable()); }
}
