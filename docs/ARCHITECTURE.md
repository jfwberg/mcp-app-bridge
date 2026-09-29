# Architecture

## Goal

MCP App Bridge turns installed Lightning Web Components into authenticated MCP Apps without adding component-specific code to the bridge. A component package supplies Lightning Out configuration, a JSON input schema, and optional event mappings. The bridge discovers those records and generates MCP tools and UI resources dynamically.

## Runtime flow

1. The MCP client authenticates to Salesforce and calls the namespaced Apex REST endpoint.
2. The endpoint selects the protocol era from the request. MCP `2025-06-18` and `2025-11-25` use the legacy `initialize` lifecycle without assigning a new protocol session; MCP `2026-07-28` uses `server/discover` and per-request metadata. Existing legacy requests that carry an `MCP-Session-Id` remain supported for backward compatibility.
3. `tools/list` derives component tools and host-to-LWC action tools from custom metadata. Modern list and resource responses include the required result type and conservative private, immediately-stale cache hints.
4. The component tool result points at the configured `ui://` MCP App resource but contains no frontdoor credential. Each time the outer widget mounts—including when a conversation is reopened—it calls the app-only `bootstrap_lightning_out` tool. When configured, Apex then signs a current-user JWT with a Salesforce-managed certificate, exchanges it through the External Client App for a short-lived access token, and immediately exchanges that token through `/services/oauth2/singleaccess`.
5. The shared HTML host initializes the MCP Apps protocol and reads bootstrap data from `ui/notifications/tool-result`.
6. If a host supplies neither result-metadata path, the widget calls the private bootstrap tool as a compatibility fallback.
7. Lightning Out 2.0 loads the configured component inside the MCP widget.
8. `ui/notifications/tool-input` values are allowlisted from the configured JSON schema and mapped from camel-case properties to kebab-case Lightning Out attributes. Inputs can arrive after the LWC connects, so conforming components react to later public-property setter calls rather than relying only on `connectedCallback`.
9. Configured LWC events call the private `bridge_event` tool. `SEND_MESSAGE` mappings produce a host message for the conversation.
10. Configured host actions return `mcpappCommand` results that the widget maps to DOM events.
11. When logging is enabled, sanitized success milestones are written directly and failures are published immediately as platform events before asynchronous persistence to `MCP_Bridge_Log__c`.

## Boundaries

- The bridge has no knowledge of a specific component, object, event, or input property.
- Frontdoor URLs and Salesforce sessions are never persisted or logged.
- Diagnostic records contain safe categories, timing, status, and a one-way frontdoor fingerprint; they deliberately omit credentials and complete URLs.
- Cached HTML contains no authentication material.
- Previously rendered widgets are isolated historical instances. A model-invoked UI tool normally opens a new widget; the protocol does not provide a portable global widget-instance address.
- The three configuration custom metadata types are public and subscriber-controlled so administrators and extension packages can contribute configuration.
- `MCP_Session__c` remains private runtime state.
- Modern requests never create, read, or return an `MCP_Session__c` or `MCP-Session-Id`. Legacy requests are stateless-compatible by default and return completed SSE `message` responses; existing valid session-bearing requests remain compatible, and the OpenAI legacy profile retains a stateful handshake.

## Supported MCP protocol versions

- **2025-06-18**: stateless-compatible Streamable HTTP using `initialize`, `notifications/initialized`, and `MCP-Protocol-Version`. JSON-RPC request results are returned as a completed SSE `message` event, matching the default official SDK transport behavior. This revision supports structured tool output and is intended for clients such as Slack that negotiate the June 2025 revision.
- **2025-11-25**: the newer handshake revision using the same stateless-compatible lifecycle.
- **2026-07-28**: sessionless Streamable HTTP using `server/discover`, per-request `_meta`, and the standard `MCP-Protocol-Version`, `Mcp-Method`, and conditional `Mcp-Name` headers.

All versions use the same configuration-driven tool and resource registries. New legacy handshakes deliberately omit the optional `MCP-Session-Id`, avoiding a dependency on clients or intermediaries preserving a custom response header. If an older connection supplies a valid session header, the original stateful validation path remains available.

For interoperability with the ChatGPT connector, a legacy request whose `User-Agent` begins with `openai-mcp/` receives the official SDK-style stateful SSE combination: initialize returns `MCP-Session-Id`, and request results use completed SSE `message` events. The header selects transport state only and is never trusted for authentication or authorization.

The same ChatGPT user agent receives completed SSE `message` events for modern `2026-07-28` request results, including `server/discover`. Modern requests remain sessionless and retain their required result metadata; only their legal Streamable HTTP response framing changes from a single JSON object to SSE.

## Configuration types

- **MCP App Bridge Core Configuration**: ECA credentials, preferred legacy protocol revision, scopes, origins, and session timeout. Endpoint and OAuth discovery URLs are derived from the org's My Domain. Both supported legacy revisions and modern `2026-07-28` are negotiated automatically.
- **MCP App Bridge Lightning Out 2.0**: one generated MCP UI tool and one Lightning Out component per enabled record.
- **MCP App Bridge Event Mapping**: an LWC-to-host message or host-to-LWC action related to a Lightning Out configuration.
