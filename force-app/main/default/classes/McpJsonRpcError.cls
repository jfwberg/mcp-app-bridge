/** JSON-RPC error DTO. */
public class McpJsonRpcError {
    public Integer code;
    public String message;
    public McpJsonRpcError(Integer code, String message) { this.code = code; this.message = message; }
}
