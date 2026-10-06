# Troubleshooting

## Teams tool works but no UI resource is requested

Use the Microsoft [appPackage integration](../appPackage/README.md). The Copilot Studio agent/connector route tested here discovers and invokes tools but does not render MCP Apps UI. The packaged Teams integration rendered a Salesforce LWC on 6 October 2026. Enable host developer mode with `-developer on` and inspect Actions and authentication errors. Do not infer runtime UI support from the discovery client's empty capabilities alone.

## OAuth completes but Microsoft cannot finish the connection

Check proxy OAuth navigation responses for `Cross-Origin-Opener-Policy: same-origin`. In the confirmed setup, those routes needed `unsafe-none` to preserve communication with the opening window. Start a fresh flow after changing headers. A null `window.opener` is a clue, but may also mean the tab was opened without an opener initially. Keep authorization, token, and refresh endpoints consistent: proxy-wrapped authorization codes must be redeemed through the matching proxy token endpoint. The OAuth registration Base URL must match the packaged MCP endpoint. Successful upstream token exchange alone does not prove Microsoft stored the token or completed the browser connection.

## Salesforce blocks Teams with frame-ancestors

This is Salesforce's embedding policy, distinct from the host's `frame-src`. Add every actual ancestor origin to Salesforce Trusted Domains for Inline Frames. In the working Teams deployment, the origins required `https://*.widget-renderer.usercontent.microsoft` and cloud Microsoft ancestors including `https://m365copilotapp.svc.cloud.microsoft` and `https://teams.cloud.microsoft`. The renderer uses `.microsoft`, not `.microsoft.com`; retain older entries where other hosts need them. Inspect `Array.from(location.ancestorOrigins)` in the relevant frame context and compare it with the effective policy. Resource `frameDomains` cannot relax Salesforce's policy.

Start by enabling [diagnostic logging](LOGGING.md), reproduce the problem once, and then disable it. The absence of a follow-up milestone is often as useful as an explicit error.

## MCP negotiation stops before tools/list

For MCP `2026-07-28`, a client normally sends `server/discover` and then `tools/list`. For MCP `2024-11-05`, `2025-06-18`, or `2025-11-25`, it sends `initialize`, `notifications/initialized`, and then `tools/list`.

If the bridge logs a successful discovery or initialization but receives no subsequent request, the server cannot progress the connection: the client stopped locally. Capture the successful response, response headers, client error, and the absence of a later `MCP_REQUEST` for the client vendor. A `Correlation ID` such as `openai-mcp-discover` is the caller's JSON-RPC request ID and is expected.

Modern requests must carry matching `MCP-Protocol-Version` and per-request `_meta` values, an `Mcp-Method` header, and `Mcp-Name` for `tools/call` and `resources/read`. Header failures return HTTP 400 with JSON-RPC `-32020`; unsupported modern versions return `-32022`; unknown methods return HTTP 404 with `-32601`.

New legacy handshakes do not return the optional `MCP-Session-Id`; later requests must carry a supported `MCP-Protocol-Version`. The bridge still accepts an existing valid session ID for backward compatibility, in which case its protocol header must match the version stored on that session.

Legacy JSON-RPC request results use `Content-Type: text/event-stream` and contain one completed `event: message` frame. Notifications such as `notifications/initialized` still return an empty HTTP 202. This is Streamable HTTP response framing, not the deprecated standalone HTTP+SSE transport.

The ChatGPT connector identifies itself with `User-Agent: openai-mcp/1.0.0` and receives a stateful SSE handshake for compatibility. Its initialize response includes `MCP-Session-Id`, which it must return on `notifications/initialized` and `tools/list`. Other legacy clients use the stateless SSE handshake unless they already supply a valid bridge session. The user-agent distinction changes transport state only; OAuth remains the security boundary.

ChatGPT normally probes modern support first with `server/discover` at `2026-07-28`. Responses to modern requests from `openai-mcp/` also use a completed SSE `message` event. If discovery succeeds but no `tools/list` follows, capture the response `Content-Type` and body framing: it should be `text/event-stream` followed by `event: message` and a single `data:` JSON-RPC response.

The diagnostic log also records a `GET` against the MCP endpoint as `SSE_NOT_SUPPORTED` with HTTP 405. This is a standards-compliant indication that the optional standalone server-sent-event stream is unavailable, and lets you distinguish that probe from a client that stops immediately after `initialize`.

## A fresh Salesforce UI session was not returned

### Symptoms

The tool is discovered and its widget begins loading, but the widget displays:

```text
A fresh Salesforce UI session was not returned.
```

The MCP client may show only this response:

```json
{
  "error": "HTTP 503 Service Unavailable"
}
```

### Inspect the widget bootstrap result

Inspect the complete result from the app-only `bootstrap_lightning_out` call made when the widget mounts, including its widget-only `_meta`. If it contains the following value, the bridge could not resolve a valid Lightning Out application ID:

```json
{
  "mcpapp/bootstrapError": {
    "retryable": true,
    "message": "Lightning Out application is not configured.",
    "type": "UI_SESSION_ERROR"
  }
}
```

### Resolution

Lightning Out 2.0 applications are org-specific and cannot be included in the managed package. In the affected Salesforce org:

1. Create or reuse a Lightning Out 2.0 application.
2. Add the LWC used by the failing bridge configuration to that application.
3. Copy the application's 18-character ID.
4. Open the corresponding **MCP App Bridge Lightning Out 2.0** custom metadata record.
5. Set **Lightning Out App ID** to the copied ID and ensure the record is enabled.
6. Verify that **Component Name** contains the generated Lightning Out custom-element name.
7. Reconnect the MCP client if the configuration also changed a tool or versioned resource URI, then retry with a fresh widget.

This error specifically indicates a missing or invalid Lightning Out App ID in the selected bridge configuration. Errors exchanging an otherwise valid Salesforce session for a frontdoor URL use a different bootstrap error message.

## Salesforce frame is blocked by the MCP client

There are three materially different failures around the Lightning Out frame. Use the browser message together with the bridge diagnostic log to identify the owner before changing Salesforce configuration.

| Failure | Typical evidence | Owner |
| --- | --- | --- |
| Salesforce origin is absent from the host allowlist | The host CSP reports `frame-src 'self' blob: data:` or another list that does not contain the Salesforce My Domain/Lightning origins. This has been observed in Claude. | MCP client/host |
| Salesforce UI session or frontdoor URL is invalid | The widget reports that a fresh Salesforce UI session was not returned, or diagnostics record a JWT, single-access, frontdoor-validation, or Lightning Out configuration failure. | MCP App Bridge or Salesforce configuration |
| Host blocks every frame | The host CSP reports `frame-src 'none'`. This has been observed in Slack. | MCP client/host |

### Host allows some frames, but not Salesforce

The browser console reports an error similar to:

```text
Framing 'https://your-domain.my.salesforce.com/' violates the following Content Security Policy directive: "frame-src 'self' blob: data:". The request has been blocked.
```

The MCP App widget is already rendered inside an iframe. Lightning Out 2.0 then loads the Salesforce interface in another iframe. Some MCP clients, including the observed Claude client environment, do not permit this iframe-inside-an-iframe arrangement or do not include the Salesforce origin in their outer `frame-src` policy.

This message is enforced by the MCP client's Content Security Policy. It does not, by itself, indicate that Salesforce rejected the frontdoor URL. If diagnostic logging shows a successful single-access exchange and validated frontdoor generation, authentication and frontdoor creation succeeded; the client blocked the subsequent frame navigation. Later component milestones may be absent because the browser never allowed the Salesforce frame to load.

The outer MCP client must allow the Salesforce My Domain origin in its `frame-src` policy and support nested frames. Salesforce Trusted Domains for Inline Frames cannot relax a CSP imposed by the outer client. If the client cannot support nested frames, the practical alternatives are for that client to add support or for the Salesforce interface to be opened outside the embedded MCP App frame.

### Salesforce rejects or cannot create the UI session

This is not identified by a host CSP message. The widget or bridge returns a bootstrap error, and diagnostic logging shows the failure before a validated frontdoor milestone. Check the error category and stage: JWT exchange, single-access exchange, frontdoor validation, Lightning Out application ID, and component configuration are Salesforce-side or bridge-side concerns. Follow [A fresh Salesforce UI session was not returned](#a-fresh-salesforce-ui-session-was-not-returned) and [JWT interface authentication fails](#jwt-interface-authentication-fails).

Do not classify a frontdoor URL as invalid merely because the browser refused to frame it. When the log shows successful single-access exchange and frontdoor validation, the URL was generated and validated successfully; a later CSP error belongs to the embedding host.

### Host blocks all frames

The browser console reports:

```text
Framing 'https://your-domain.my.salesforce.com/' violates the following Content Security Policy directive: "frame-src 'none'". The request has been blocked.
```

`frame-src 'none'` prohibits every iframe, regardless of its domain. No Salesforce trusted-domain, session, frontdoor, or Lightning Out setting can override it. The MCP host must change its widget CSP to permit nested frames and the required Salesforce origins, or the Salesforce interface must be opened outside the embedded MCP App. This has been observed in Slack even though MCP initialization, tool discovery, tool invocation, and frontdoor generation all completed successfully.

## JWT interface authentication fails

When the core record contains an ECA Consumer Key and ECA Certificate Name, the bridge uses JWT bearer flow before creating the frontdoor URL. Bootstrap errors identify the failing stage:

- `JWT_CONFIGURATION_ERROR`: one of the two core metadata values is missing.
- `JWT_SIGNING_ERROR`: the certificate developer name is incorrect or Apex cannot use the certificate.
- `JWT_TOKEN_UNREACHABLE`: Salesforce's token endpoint could not be reached.
- `JWT_TOKEN_REJECTED`: verify the consumer key, uploaded certificate, JWT Bearer Flow setting, ECA policy, and current user's pre-authorization.
- `JWT_TOKEN_INVALID_RESPONSE`: the token endpoint did not return both `access_token` and `instance_url`.

The bridge deliberately does not include the signed assertion, access token, or Salesforce token-response body in these errors.

For JWT bearer flow, the bridge derives the assertion audience from `Organization.IsSandbox`: `https://test.salesforce.com` for sandbox and scratch orgs, otherwise `https://login.salesforce.com`. The token request itself uses the current org's My Domain. An `invalid_client` response normally means the configured consumer key does not identify the JWT-enabled ECA in that org.
