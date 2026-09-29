trigger McpBridgeLogEventTrigger on MCP_Bridge_Log_Event__e (after insert) {
    McpDiagnostics.persistEvents(Trigger.new);
}
