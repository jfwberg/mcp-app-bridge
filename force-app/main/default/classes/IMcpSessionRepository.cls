/** Durable MCP session persistence contract. */
public interface IMcpSessionRepository {
    McpSession createSession(String sessionHash, String protocolVersion, String clientName, String clientVersion, Integer timeoutMinutes);
    McpSession getSession(String sessionHash);
    void markInitialized(Id recordId);
    void touch(Id recordId, Integer timeoutMinutes);
    void terminate(Id recordId);
}
