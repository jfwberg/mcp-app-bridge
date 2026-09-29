/** Controlled MCP protocol failure safe to return to clients. */
public class McpProtocolException extends Exception {
    public Integer code;
    public Integer httpStatus;
    public String errorType;
    public Object data;
    public McpProtocolException(Integer code, Integer httpStatus, String message) {
        this(code, httpStatus, message, null, null);
    }
    public McpProtocolException(Integer code, Integer httpStatus, String message, String errorType) {
        this(code, httpStatus, message, errorType, null);
    }
    public McpProtocolException(Integer code, Integer httpStatus, String message, String errorType, Object data) {
        this.code = code;
        this.httpStatus = httpStatus;
        this.errorType = errorType;
        this.data = data;
        this.setMessage(message);
    }
}
