/** Builds mutually exclusive JSON-RPC 2.0 success and error responses. */
public class McpJsonRpcResponse {
    public static Map<String,Object> success(Object id, Object result) {
        return new Map<String,Object>{
            'jsonrpc' => '2.0',
            'id' => id,
            'result' => result
        };
    }
    public static Map<String,Object> failure(Object id, Integer code, String message) {
        return failure(id, code, message, null);
    }
    public static Map<String,Object> failure(Object id, Integer code, String message, Object data) {
        Map<String,Object> error = new Map<String,Object>{'code' => code, 'message' => message};
        if (data != null) error.put('data', data);
        return new Map<String,Object>{
            'jsonrpc' => '2.0',
            'id' => id,
            'error' => error
        };
    }
}
