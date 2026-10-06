/** Implements MCP stateful lifecycle and validation. */
public with sharing class McpLifecycleService {
    @TestVisible private static final Set<String> SUPPORTED_PROTOCOL_VERSIONS = new Set<String>{
        '2024-11-05',
        '2025-06-18',
        '2025-11-25'
    };
    @TestVisible private static Boolean testStatefulSessions = false;
    private final IMcpSessionRepository repository;
    public McpLifecycleService() { this(new McpObjectSessionRepository()); }
    public McpLifecycleService(IMcpSessionRepository repository) { this.repository=repository; }
    public Map<String,Object> initialize(Map<String,Object> params, RestResponse response) {
        McpBridgeCoreConfig config=McpBridgeCoreConfig.get(); String version=(String)params.get('protocolVersion');
        if (!SUPPORTED_PROTOCOL_VERSIONS.contains(version)) throw new McpProtocolException(-32602, 400, 'Unsupported protocol version.');
        if (shouldCreateSession()) {
            Map<String,Object> client=(Map<String,Object>)params.get('clientInfo');
            String raw=createUuidV4();
            repository.createSession(hash(raw), version, client==null?null:(String)client.get('name'), client==null?null:(String)client.get('version'), config.timeoutMinutes);
            response.addHeader('MCP-Session-Id', raw);
        }
        return new Map<String,Object>{'protocolVersion'=>version,
            'capabilities'=>new Map<String,Object>{
                'tools'=>new Map<String,Object>{'listChanged'=>false},
                'resources'=>new Map<String,Object>{'subscribe'=>false,'listChanged'=>false},
                'extensions'=>new Map<String,Object>{
                    'io.modelcontextprotocol/ui'=>new Map<String,Object>{
                        'mimeTypes'=>new List<String>{'text/html;profile=mcp-app'}
                    }
                }
            },
            'serverInfo'=>new Map<String,Object>{'name'=>'mcpapp.bridge','title'=>'MCP App Bridge','version'=>'1.0.0','description'=>'A configuration-driven Salesforce Lightning Out MCP App bridge.'},
            'instructions'=>'Use an available open_* tool to launch its configured authenticated Salesforce interface.'};
    }
    public McpSession requireSession(RestRequest request, Boolean requireReady) {
        String raw=getHeaderIgnoreCase(request, 'MCP-Session-Id'); if (String.isBlank(raw)) throw new McpProtocolException(-32600,400,'MCP-Session-Id is required.');
        McpSession session=repository.getSession(hash(raw));
        if (session==null || session.expiresAt<=System.now() || session.lifecycleState=='TERMINATED') throw new McpProtocolException(-32600,404,'Session not found.');
        if (session.userId!=UserInfo.getUserId() || session.organizationId!=UserInfo.getOrganizationId()) throw new McpProtocolException(-32600,403,'Session access denied.');
        String version=getHeaderIgnoreCase(request, 'MCP-Protocol-Version');
        if (String.isBlank(version) && session.protocolVersion=='2024-11-05') version=session.protocolVersion;
        if (version!=session.protocolVersion) throw new McpProtocolException(-32600,400,'MCP-Protocol-Version does not match the session.');
        if (requireReady && session.lifecycleState!='READY') throw new McpProtocolException(-32600,400,'Session initialization is incomplete.');
        return session;
    }
    public String requireStatelessProtocolVersion(RestRequest request) {
        String version=getHeaderIgnoreCase(request, 'MCP-Protocol-Version');
        // November 2024 predates the protocol-version HTTP header.
        if (String.isBlank(version)) version='2024-11-05';
        if (!SUPPORTED_PROTOCOL_VERSIONS.contains(version)) {
            throw new McpProtocolException(-32600,400,'A supported MCP-Protocol-Version is required.');
        }
        return version;
    }
    public Boolean hasSession(RestRequest request) {
        return String.isNotBlank(getHeaderIgnoreCase(request, 'MCP-Session-Id'));
    }
    private static Boolean shouldCreateSession() {
        if (Test.isRunningTest() && testStatefulSessions) return true;
        String userAgent=RestContext.request==null?null:getHeaderIgnoreCase(RestContext.request,'User-Agent');
        return String.isNotBlank(userAgent) && userAgent.toLowerCase().startsWith('openai-mcp/');
    }
    /** Extends the inactivity expiry after request work, including any callout, is complete. */
    public void touchSession(McpSession session) { repository.touch(session.recordId,McpBridgeCoreConfig.get().timeoutMinutes); }
    public void markInitialized(McpSession session) { repository.markInitialized(session.recordId); }
    public void terminate(RestRequest request) { McpSession session=requireSession(request,false); repository.terminate(session.recordId); }
    /**
     * Creates a cryptographically random UUID with RFC 4122 version and variant bits.
     * @return Lowercase UUID v4 string
     */
    @TestVisible private static String createUuidV4() {
        String randomHex = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).toLowerCase();
        String sourceVariant = randomHex.substring(16, 17);
        String variant;
        if ('0123'.contains(sourceVariant)) {
            variant = '8';
        } else if ('4567'.contains(sourceVariant)) {
            variant = '9';
        } else if ('89ab'.contains(sourceVariant)) {
            variant = 'a';
        } else {
            variant = 'b';
        }
        String uuidHex = randomHex.substring(0, 12) + '4' + randomHex.substring(13, 16)
            + variant + randomHex.substring(17);
        return uuidHex.substring(0, 8) + '-' + uuidHex.substring(8, 12) + '-'
            + uuidHex.substring(12, 16) + '-' + uuidHex.substring(16, 20) + '-'
            + uuidHex.substring(20);
    }
    private static String getHeaderIgnoreCase(RestRequest request, String expectedName) {
        for (String name : request.headers.keySet()) {
            if (name.equalsIgnoreCase(expectedName)) {
                return request.headers.get(name);
            }
        }
        return null;
    }
    @TestVisible private static String hash(String raw) { return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(raw))); }
}
