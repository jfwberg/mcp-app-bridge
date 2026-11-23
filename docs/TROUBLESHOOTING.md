# Troubleshooting

## Teams Lightning Out fails with invalid target origin 'null'

**Local modified loader option (26 October 2026):** enable **LO2 JS From Static Resource** (`LO2_JS_FROM_STATIC_RESOURCE__c`) on **Setup → Custom Metadata Types → MCP App Bridge Core Configuration → Manage Records → Default**. This embeds the packaged `McpLo2Modified` JavaScript in the authenticated MCP HTML response; it does not fetch the static-resource URL from the browser. The setting is subscriber-controlled and defaults to false; disabled uses Salesforce's hosted latest loader. Start a fresh widget load after saving. Turn it off and start another fresh load to return to the hosted version.

Teams was observed hosting the widget inside an HTTPS renderer and an inner `srcdoc` iframe, both with `allow-same-origin`. In the inner document, `location.origin` is the string `"null"` because its URL is `about:srcdoc`, while `window.origin` is the valid inherited HTTPS renderer origin. This does not establish that Microsoft removed sandbox permissions or when its renderer changed.

The inspected LO2 2.2.5 loader assigns `loAppOrigin` from `window.location.origin` in two places. Its generated auth page then attempts `postMessage` with target origin `"null"`, which the browser rejects. Authentication/bootstrap can therefore succeed without the component reaching ready. Adding a top-level frontdoor query parameter or a `lo-app-origin` attribute did not resolve the reported reproduction.

The local modified version changes those two assignments to use the effective `window.origin`, validates that it is HTTP(S), and rejects an override that differs from the real effective origin. It does not remove message checks, use wildcard target origins, or make opaque origins usable. It still loads Salesforce authentication and component assets; it is a pinned loader, not a fully offline runtime.

**Validation status (23 November 2026):** the user confirmed Teams and Slack loading in clean Firefox sessions without prior Salesforce sign-in. Chrome Incognito required a host-site third-party-cookie allowance. Verify `COMPONENT_READY`, inputs, events, and session behavior in your environment. Existing OAuth and ancestor-domain requirements still apply.

Use the origin checkpoints in [Logging](LOGGING.md#browser-origin-investigation) to compare clients and group entries by the widget load Correlation ID. See [Setup](SETUP.md#local-modified-lo2-loader-for-teams) and [local modified loader maintenance](LO2-LOCAL-MODIFIED.md). The pinned local version does not automatically receive Salesforce loader updates.

## Teams tool works but no UI resource is requested

**Microsoft update (23 November 2026):** the published Copilot Studio agent was verified rendering MCP Admin Friend and returning selected Salesforce record data to chat, including in Copilot in Teams. Add the MCP server as a tool in Copilot Studio and publish the agent; a separate declarative-agent appPackage is not required for this verified route. Preview displayed the UI but returned `MCP integration is unavailable for this agent.` Test the published agent before treating that preview error as a bridge failure. Salesforce ancestor trust, loader configuration, and third-party-cookie requirements still apply. If the published agent does not request a UI resource, check the opening tool metadata and MCP connection. Do not infer runtime UI support from a discovery-only trace.

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

## Historical external LO2 static resource blocked by script-src

These external-fetch checks apply to older bridge versions or separately hosted test pages. The current embedded-loader route does not request the loader from a Salesforce static-resource URL.

The local static-resource request can redirect from My Domain to the package-specific Visualforce host (for example, `https://ORG--mcpapp.vf.force.com`). When the local loader is enabled, MCP resource metadata includes that exact host in `ui.csp.resourceDomains`, resolved with Salesforce DomainCreator. Both resources/list and resources/read share this policy. Start a fresh widget/resource load after upgrading so the host receives the updated CSP; an already-mounted iframe retains its old policy. A script-src rejection for that host indicates missing or cached resource CSP metadata, not an OAuth failure.

Static-resource requests can also pass through the Lightning origin's `/visualforce/session` endpoint before reaching the Visualforce resource. When the local loader is enabled, resourceDomains includes the Lightning origin as well. Inclusion in connectDomains or frameDomains alone does not permit a script redirect there. This addresses CSP only; if the session endpoint subsequently returns HTML, authentication or resource delivery still needs investigation.

## Lightning Out library could not be loaded

This exact message comes from the script element's error event, not from a console warning. In the former external static-resource route, Salesforce returned an HTML 404/login response instead of JavaScript. Firefox reported a MIME mismatch with `X-Content-Type-Options: nosniff`. Both My Domain and Visualforce resource URLs worked while signed into Salesforce and failed in anonymous sessions.

Public cache control alone did not resolve this. Salesforce documents that View File resource URLs can depend on authentication when the server-side cache misses, even with Public caching. See [Salesforce's explanation](https://help.salesforce.com/s/articleView?id=000383810&language=en_US&type=1).

The current solution reads the packaged loader server-side and includes it in the authenticated MCP HTML response only when **LO2 JS From Static Resource** is enabled. It adds approximately 27 KB, skips the separate browser fetch, and requires no public Site or new trusted domain for loader delivery. Disabled uses Salesforce's hosted loader as before. Upgrade the bridge and start a fresh widget; old mounted widgets retain their old HTML. If Network still shows `/resource/mcpapp__McpLo2Modified`, verify the installed version and whether an old widget/resource response is being reused.

## Chrome redirects a Salesforce frame to www.salesforce.com

In the tested Chrome Incognito session, a frame navigation toward `https://www.salesforce.com/` was blocked by the widget's `frame-src` policy. Allowing third-party cookies for the host site immediately restored loading. Firefox clean sessions already worked. The CSP message was a secondary symptom of the failed frame/session flow; do not add the public Salesforce website to the allowlist to suppress it.

Chrome blocks third-party cookies in Incognito by default. Use its host-site cookie control to allow them where permitted, reload, and launch a fresh widget. See [Chrome's cookie instructions](https://support.google.com/chrome/answer/95647?hl=en). If it still fails, inspect DevTools Issues, blocked-cookie reasons, and document-request redirects. Capture status, Location, and final destination; redact credentials and frontdoor tokens.

MCP OAuth refresh tokens authenticate server calls; they do not log the browser into the nested Salesforce frame. Existing Salesforce logins can mask this distinction. For regression checks, use clean sessions with the intended cookie policy and a fresh widget/frontdoor URL every time. Compare enabled and disabled loader modes separately rather than assuming a cache clear fixes authentication.
