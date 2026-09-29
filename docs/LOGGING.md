# Diagnostic logging

Diagnostic logging is an opt-in troubleshooting facility. It is disabled in the packaged `Default` core configuration and should normally remain disabled outside investigation or client certification.

## Enable and view logs

1. Open **Setup → Custom Metadata Types → MCP App Bridge Core Configuration → Manage Records**.
2. Edit `Default`, select **Logging Enabled**, and save.
3. Reproduce the connection or widget problem.
4. Open **MCP Bridge Logs** from the App Launcher. The `MCP App Bridge` permission set makes the tab and records available.
5. Disable logging when the investigation is complete.

Logging is best-effort and never changes an MCP response. Successful milestones are inserted directly. Failures are published through the Publish Immediately `MCP_Bridge_Log_Event__e` platform event and copied by its subscriber into `MCP_Bridge_Log__c`, allowing an error to survive rollback of the originating transaction.

## Field reference

| Field | Meaning |
| --- | --- |
| Log Number | Auto-number record identifier. |
| Occurred At | Time the originating milestone occurred; use this rather than asynchronous record creation time. |
| Level | `INFO` for a successful/direct milestone; `ERROR` for a failed milestone persisted from the platform event. |
| Stage | Stable lifecycle checkpoint listed below. |
| Operation | Broader activity, such as an MCP method, `LIGHTNING_OUT_BOOTSTRAP`, or `WIDGET_LIFECYCLE`. |
| Outcome | `SUCCEEDED` or `FAILED`. Error-event records are normalized to `FAILED`. |
| Correlation ID | String form of the JSON-RPC request ID when one exists, such as `openai-mcp-discover`; it is not an MCP session ID. |
| Configuration Key | Lightning Out configuration developer name associated with the event. |
| MCP Method | JSON-RPC method, for example `server/discover`, `tools/list`, or `tools/call`. |
| Tool Name | MCP tool involved in the request or widget diagnostic. |
| HTTP Status | MCP or upstream Salesforce HTTP status when applicable. |
| Duration (ms) | Elapsed time for the measured request or callout. |
| Error Type | Safe, stable error category intended for troubleshooting. |
| Message | Sanitized explanatory message. |
| Details JSON | Bridge-generated safe metadata such as credential source and response byte count; never an upstream response body. |
| URL Fingerprint | SHA-256 fingerprint of a frontdoor URL, used only to correlate events without storing the URL. |
| User ID / Organization ID | Salesforce execution context that emitted the event. |

Blank fields mean that the value is not meaningful or was unavailable for that stage; they do not by themselves indicate an error.

## Stage reference

| Stage | What it proves |
| --- | --- |
| `MCP_REQUEST` | The Apex REST endpoint completed or rejected one JSON-RPC request. Inspect MCP Method, HTTP Status, Correlation ID, and Error Type. |
| `JWT_TOKEN_CALLOUT` | The JWT token endpoint could not be reached. This stage is emitted only on failure. |
| `JWT_TOKEN_RESPONSE` | The JWT token endpoint rejected the request. This stage is emitted only for non-200 responses; a later successful single-access stage implies the JWT exchange succeeded. |
| `SINGLE_ACCESS_CALLOUT` | The `/services/oauth2/singleaccess` endpoint could not be reached. This stage is emitted only on failure. |
| `SINGLE_ACCESS_RESPONSE` | Salesforce answered `/services/oauth2/singleaccess`. A successful entry proves the access token was accepted for one-time UI access. |
| `FRONTDOOR_VALIDATED` | The returned frontdoor URI passed origin and shape validation. Only its fingerprint is retained. |
| `BOOTSTRAP_FAILED` | The widget's mount-time bootstrap call could not produce a usable Lightning Out bootstrap. The widget receives a safe `mcpapp/bootstrapError`. |
| `UI_INITIALIZED` | The shared HTML resource started and initialized its MCP App connection. |
| `BOOTSTRAP_RECEIVED` | The widget received fresh bootstrap metadata from its mount-time bootstrap call. |
| `LIGHTNING_LIBRARY_LOADED` | The Lightning Out 2.0 browser library loaded. |
| `APPLICATION_ATTACHED` | The frontdoor URL and Lightning Out app ID were handed to Lightning Out. This does not alone prove that the nested frame completed authentication. |
| `COMPONENT_ATTACHED` | Lightning Out attached the configured custom element. |
| `COMPONENT_READY` | Strongest success milestone: the configured LWC reported ready inside the widget. |
| `APPLICATION_ERROR` | Lightning Out application attachment failed. |
| `COMPONENT_ERROR` | Component attachment or readiness failed. |
| `WIDGET_ERROR` | The shared HTML host encountered another widget lifecycle error. |

## Bootstrap error types

| Error type | Meaning |
| --- | --- |
| `JWT_CONFIGURATION_ERROR` | Only one of the consumer key and certificate name is configured. Configure both or neither. |
| `JWT_SIGNING_ERROR` | Salesforce could not sign with the configured certificate. |
| `JWT_TOKEN_UNREACHABLE` | The JWT token callout failed before receiving an HTTP response. |
| `JWT_TOKEN_REJECTED` | The token endpoint returned a non-200 response. Check ECA JWT settings and user pre-authorization. |
| `JWT_TOKEN_INVALID_RESPONSE` | The token endpoint response lacked a usable access token or instance URL. |
| `UI_SESSION_UNREACHABLE` | The single-access endpoint could not be reached. |
| `UI_SESSION_REJECTED` | The single-access endpoint rejected the credential. |
| `UI_SESSION_AUTH_EXPIRED` | The available Salesforce authentication had expired; reconnect the MCP client. |
| `UI_SESSION_INVALID_RESPONSE` | Salesforce returned an unreadable or incomplete single-access response. |
| `UI_SESSION_INVALID_FRONTDOOR` | The returned frontdoor URI failed the expected org-origin or one-time-token validation. |

An absent Error Type on a successful record is normal. `UNEXPECTED_ERROR` on `MCP_REQUEST` means the endpoint caught an unclassified server exception and deliberately returned only a safe generic message.

## Reading a trace

- `server/discover` succeeds but no later `MCP_REQUEST` exists: the modern MCP client stopped before `tools/list`.
- `initialize` succeeds but no `notifications/initialized` or `tools/list` follows: the legacy client stopped after negotiation.
- `FRONTDOOR_VALIDATED` exists but no `UI_INITIALIZED`: the MCP host did not mount the `ui://` HTML resource.
- `APPLICATION_ATTACHED` is followed by a browser `frame-src` CSP error and no component milestones: the outer host blocked the nested Salesforce frame.
- `COMPONENT_READY` exists: OAuth, frontdoor exchange, Lightning Out loading, application attachment, and component mounting all completed.

## Security behavior

The logger never intentionally stores access tokens, JWT assertions, Salesforce session IDs, upstream response bodies, or complete frontdoor URLs. Messages redact bearer-like values, `otp`, `access_token`, and `assertion` query values, then redact HTTP(S) URLs. Structured details are constructed internally from allowlisted operational values. Error-event message and details fields are limited to 255 characters; object records allow longer sanitized text.

Treat diagnostic records as operational data: retain them only as long as needed, restrict access through Salesforce permissions and sharing, and delete them according to your organization's retention policy.
