/** Implements the sessionless MCP 2026-07-28 protocol boundary. */
public with sharing class McpModernProtocolService {
    public static final String VERSION = '2026-07-28';
    private static final Set<String> SUPPORTED_METHODS = new Set<String>{
        'server/discover', 'tools/list', 'tools/call', 'resources/list', 'resources/read'
    };
    private static final Set<String> CACHEABLE_METHODS = new Set<String>{
        'tools/list', 'resources/list', 'resources/read'
    };

    public static Boolean isModern(Map<String,Object> request, RestRequest httpRequest) {
        if ((String)request.get('method') == 'server/discover') return true;
        Map<String,Object> params = request.get('params') instanceof Map<String,Object>
            ? (Map<String,Object>)request.get('params') : null;
        Map<String,Object> meta = params != null && params.get('_meta') instanceof Map<String,Object>
            ? (Map<String,Object>)params.get('_meta') : null;
        return meta != null && meta.containsKey('io.modelcontextprotocol/protocolVersion');
    }

    public Object dispatch(Map<String,Object> request, RestRequest httpRequest) {
        String method = (String)request.get('method');
        Map<String,Object> params = request.get('params') instanceof Map<String,Object>
            ? (Map<String,Object>)request.get('params') : new Map<String,Object>();
        validateEnvelope(request, params, httpRequest);
        if (!SUPPORTED_METHODS.contains(method)) {
            throw new McpProtocolException(-32601, 404, 'Method not found.');
        }

        Map<String,Object> result;
        if (method == 'server/discover') result = discover();
        else if (method == 'tools/list') result = McpToolRegistry.listTools();
        else if (method == 'tools/call') result = McpToolRegistry.callTool(params);
        else if (method == 'resources/list') result = McpResourceRegistry.listResources();
        else result = McpResourceRegistry.readResource(params);
        decorateResult(result, method);
        return result;
    }

    private static Map<String,Object> discover() {
        return new Map<String,Object>{
            'supportedVersions' => new List<String>{VERSION},
            'capabilities' => capabilities(),
            'instructions' => 'Use an available open_* tool to launch its configured authenticated Salesforce interface.',
            'ttlMs' => 0,
            'cacheScope' => 'private'
        };
    }

    private static Map<String,Object> capabilities() {
        return new Map<String,Object>{
            'tools' => new Map<String,Object>(),
            'resources' => new Map<String,Object>(),
            'extensions' => new Map<String,Object>{
                'io.modelcontextprotocol/ui' => new Map<String,Object>{
                    'mimeTypes' => new List<String>{'text/html;profile=mcp-app'}
                }
            }
        };
    }

    private static void decorateResult(Map<String,Object> result, String method) {
        result.put('resultType', 'complete');
        if (CACHEABLE_METHODS.contains(method)) {
            result.put('ttlMs', 0);
            result.put('cacheScope', 'private');
        }
        Map<String,Object> meta = result.get('_meta') instanceof Map<String,Object>
            ? (Map<String,Object>)result.get('_meta') : new Map<String,Object>();
        meta.put('io.modelcontextprotocol/serverInfo', serverInfo());
        result.put('_meta', meta);
    }

    private static Map<String,Object> serverInfo() {
        return new Map<String,Object>{
            'name' => 'mcpapp.bridge',
            'title' => 'MCP App Bridge',
            'version' => '1.0.0',
            'description' => 'A configuration-driven Salesforce Lightning Out MCP App bridge.'
        };
    }

    private static void validateEnvelope(Map<String,Object> request, Map<String,Object> params, RestRequest httpRequest) {
        String method = (String)request.get('method');
        Map<String,Object> meta = params.get('_meta') instanceof Map<String,Object>
            ? (Map<String,Object>)params.get('_meta') : null;
        String bodyVersion = meta == null ? null : (String)meta.get('io.modelcontextprotocol/protocolVersion');
        String headerVersion = getHeader(httpRequest, 'MCP-Protocol-Version');
        if (String.isBlank(headerVersion) || String.isBlank(bodyVersion) || headerVersion != bodyVersion) {
            throw new McpProtocolException(-32020, 400, 'Header mismatch: MCP-Protocol-Version must match request metadata.');
        }
        if (bodyVersion != VERSION) {
            throw new McpProtocolException(-32022, 400, 'Unsupported protocol version.', null, new Map<String,Object>{
                'supported' => new List<String>{VERSION}, 'requested' => bodyVersion
            });
        }
        if (!(meta.get('io.modelcontextprotocol/clientCapabilities') instanceof Map<String,Object>)) {
            throw new McpProtocolException(-32602, 400, 'Invalid params: clientCapabilities request metadata is required.');
        }
        String accept = getHeader(httpRequest, 'Accept');
        if (String.isBlank(accept) || !accept.toLowerCase().contains('application/json') || !accept.toLowerCase().contains('text/event-stream')) {
            throw new McpProtocolException(-32020, 400, 'Header mismatch: Accept must include application/json and text/event-stream.');
        }
        String headerMethod = getHeader(httpRequest, 'Mcp-Method');
        if (String.isBlank(headerMethod) || headerMethod != method) {
            throw new McpProtocolException(-32020, 400, 'Header mismatch: Mcp-Method must match the JSON-RPC method.');
        }
        if (method == 'tools/call' || method == 'resources/read') {
            String bodyName = method == 'resources/read' ? (String)params.get('uri') : (String)params.get('name');
            String headerName = decodeHeaderValue(getHeader(httpRequest, 'Mcp-Name'));
            if (String.isBlank(bodyName) || headerName != bodyName) {
                throw new McpProtocolException(-32020, 400, 'Header mismatch: Mcp-Name must match the request name or URI.');
            }
        }
    }

    private static String decodeHeaderValue(String value) {
        if (String.isBlank(value)) return value;
        if (value.startsWith('=?base64?') && value.endsWith('?=')) {
            try {
                return EncodingUtil.base64Decode(value.substring(10, value.length() - 2)).toString();
            } catch (Exception invalidEncoding) {
                throw new McpProtocolException(-32020, 400, 'Header mismatch: Mcp-Name contains invalid Base64 encoding.');
            }
        }
        return value;
    }

    private static String getHeader(RestRequest request, String expectedName) {
        for (String name : request.headers.keySet()) {
            if (name.equalsIgnoreCase(expectedName)) return request.headers.get(name);
        }
        return null;
    }
}
