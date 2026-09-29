# Client compatibility

This page records observed interoperability results for MCP App Bridge. It distinguishes MCP transport success from UI-host framing restrictions: a client can successfully discover and call tools while still refusing to render the nested Salesforce iframe.

## Verified client matrix

| Client/host | Observed MCP flow | Response profile | Tool and authentication status | Embedded UI status |
| --- | --- | --- | --- | --- |
| ChatGPT (`openai-mcp/1.0.0`) | `2026-07-28` using `server/discover` | Sessionless completed SSE `message` responses | End-to-end verified: discovery, tool calls, bootstrap, frontdoor authentication, and follow-up actions | Working end to end |
| Slack (`Slack-MCP-Client/1.0`) | `2025-06-18` using `initialize` | Stateless-compatible completed SSE `message` responses | Initialization, tool discovery, tool invocation, and frontdoor generation verified | Working End to End. Note: By default frame are blocked by the Slack host CSP `frame-src 'none'`; You need to contact support to change this setting |
| Claude | Legacy MCP initialize/tool flow | Legacy-compatible transport | Discovery, tool invocation, and valid frontdoor authentication verified. Note: OAuth requires a token proxy due to strict OAuth 2.1 implementation | The observed host CSP does not permit the nested Salesforce iframe; this is not an MCP App Bridge failure, No solution as of yet |
| Microsoft 365/Copilot hosts | Not yet tested | To be determined from the client request | Not yet verified | Not yet verified |

These results describe the tested host versions and can change when a host updates its MCP implementation or CSP.

## Supported transport profiles

- **OpenAI modern:** `2026-07-28`, sessionless requests, with each JSON-RPC result returned as one completed SSE `message` event.
- **Legacy clients:** `2025-06-18` or `2025-11-25`, stateless-compatible requests, with completed SSE `message` responses. Existing requests carrying a valid bridge session ID remain compatible.
- **OpenAI legacy fallback:** legacy initialize requests from `openai-mcp/*` receive a session ID and completed SSE responses for compatibility with the observed client behavior.
- **Other modern clients:** `2026-07-28` remains sessionless and uses JSON responses unless a client-specific compatibility profile requires SSE.

User-agent matching selects a transport compatibility profile only. It is not an authentication or authorization mechanism.

## What “working” means

Validate each layer separately so a host rendering restriction is not mistaken for a server or OAuth failure:

1. **Negotiation:** `initialize` or `server/discover` returns the requested supported protocol version in the expected framing.
2. **Discovery:** the client proceeds to `tools/list` or consumes the tools returned by its discovery flow.
3. **Invocation:** `tools/call` returns the expected structured content and `mcpapp/bootstrap` metadata.
4. **Authentication:** the generated frontdoor URL establishes the Salesforce UI session.
5. **Widget resource:** the host loads the MCP App HTML resource.
6. **Nested UI:** the host CSP permits the widget iframe to load the Salesforce iframe.
7. **Interaction:** host-to-LWC and LWC-to-host events are delivered as configured.

The diagnostic log can prove layers 1–4 and record component activity. Browser developer tools are required to diagnose host CSP failures at layers 5–6.

## Testing a new host

For Microsoft 365/Copilot or another new client, capture the following without including bearer tokens, OAuth secrets, one-time passwords, or complete frontdoor URLs:

- request user-agent, `MCP-Protocol-Version`, `Accept`, and `Content-Type`;
- JSON-RPC method, ID type, requested protocol version, capabilities, and `_meta` keys;
- response status, `Content-Type`, `MCP-Session-Id`, and `MCP-Protocol-Version`;
- whether the body is JSON or SSE, including SSE event names but not credentials;
- the next request made after negotiation, or confirmation that the client stopped;
- MCP Bridge Log stages for discovery, invocation, frontdoor generation, and component events;
- browser console CSP errors and the effective `frame-src` directive.

If negotiation succeeds but no discovery request follows, compare the response framing with the profiles above. If tool invocation and frontdoor generation succeed but no UI appears, use the iframe failure table in [Troubleshooting](TROUBLESHOOTING.md#salesforce-frame-is-blocked-by-the-mcp-client).
