/** Namespace-neutral session domain DTO. */
public class McpSession {
    public Id recordId; public String sessionHash; public String userId; public String organizationId;
    public String protocolVersion; public String lifecycleState; public Datetime expiresAt;
}
