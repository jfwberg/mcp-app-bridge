# Client compatibility

This page records observed interoperability results for MCP App Bridge. It distinguishes MCP transport success from UI-host framing restrictions: a client can successfully discover and call tools while still refusing to render the nested Salesforce iframe.

## Verified client matrix

**Microsoft integration note (6 October 2026):** MCP Apps UI is not supported through the Copilot Studio agent/connector route tested here. It requires a Microsoft **appPackage** registering a declarative agent and its RemoteMCPServer plugin. This is distinct from exposing an MCP server through an existing agent: tool calls worked there, but no `resources/read` followed. The [MCP App Bridge package](../appPackage/README.md) successfully rendered a Salesforce LWC in Teams. This records the current observed limitation, not a guarantee about future Microsoft releases.

| Client/host | Observed MCP flow | Response profile | Tool and authentication status | Embedded UI status |
| --- | --- | --- | --- | --- |
| ChatGPT (`openai-mcp/1.0.0`) | `2026-07-28` using `server/discover` | Sessionless completed SSE `message` responses | End-to-end verified: discovery, tool calls, bootstrap, frontdoor authentication, and follow-up actions | Working end to end |
| Slack (`Slack-MCP-Client/1.0`) | `2025-06-18` using `initialize` | Stateless-compatible completed SSE `message` responses | Initialization, tool discovery, tool invocation, and frontdoor generation verified | Working End to End. Note: By default frame are blocked by the Slack host CSP `frame-src 'none'`; You need to contact support to change this setting |
| Claude | Legacy MCP initialize/tool flow | Legacy-compatible transport | Discovery, tool invocation, and valid frontdoor authentication verified. Note: OAuth requires a token proxy due to strict OAuth 2.1 implementation | The observed host CSP does not permit the nested Salesforce iframe; this is not an MCP App Bridge failure, No solution as of yet |
| Microsoft Copilot Studio (`MicrosoftCopilotStudio-AgenticLoop/1.0`) | Observed `2024-11-05` using `initialize`; headerless `tools/call` | Legacy completed POST/SSE response profile | Admin Friend invocation returned HTTP 200, `isError: false`, and component input data | User reports no visible UI; resource fetch and widget bootstrap not yet confirmed |

These results describe the tested host versions and can change when a host updates its MCP implementation or CSP.

Teams packaged integration was confirmed working by the user on 6 October 2026. The package includes Record Creator, Record Viewer, and MCP Admin Friend; the report confirms LWC rendering, not separate acceptance tests for every tool and action. No change to the MCP core protocol version or UI extension namespace was needed to resolve rendering.

Two configuration fixes were required during the successful integration:

- Proxy OAuth navigation responses must preserve the opener relationship. The tested proxy used `Cross-Origin-Opener-Policy: unsafe-none` on those routes instead of `same-origin`; start a fresh login after changing this.
- Salesforce's trusted iframe domains must allow every ancestor. The observed chain was `https://2e0403e952b6183ee865b86ce344fb98.widget-renderer.usercontent.microsoft`, `https://m365copilotapp.svc.cloud.microsoft`, and `https://teams.cloud.microsoft`. Add `https://*.widget-renderer.usercontent.microsoft` and the corresponding cloud Microsoft origins. The existing `https://*.widget-renderer.usercontent.microsoft.com` entry did not match the renderer's `.microsoft` domain. Resource `frameDomains` cannot override Salesforce's `frame-ancestors` policy.

The subsequent initialization trace identifies the discovery client as `McpToolsListClient/1.0.0`, with `protocolVersion: 2024-11-05` and empty `capabilities: {}`. The bridge response correctly advertises `extensions.io.modelcontextprotocol/ui` and the HTML MIME type; the initialized notification returns empty HTTP 202, and tool discovery retains `_meta.ui.resourceUri`. The user confirmed no subsequent `resources/read` requests. This exchange does not negotiate MCP Apps on the client side. Because this is a tools-list client, it does not by itself establish the capabilities of a separate runtime or every Microsoft host. Capture any runtime initialization separately, or ask Microsoft whether the specific Copilot Studio connector and chat surface support the [MCP Apps capability negotiation](https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx#clientserver-capability-negotiation).

Microsoft's observed client requests negotiate `2024-11-05`, which the bridge now supports alongside its other revisions. That revision may omit `MCP-Protocol-Version`; headerless stateless requests use the 2024 profile. Structured tool data is returned as JSON text content, and MCP Apps uses the `extensions` capability even with the 2024 core revision. The original 2024 persistent GET SSE transport requires an adapter; see [Architecture](ARCHITECTURE.md#supported-mcp-protocol-versions). Server regression and smoke tests do not establish Microsoft host or embedded UI compatibility.

On 5 October 2026, the full project was deployed to the `mcpappbridge` scratch org: all 41 local Apex tests passed. Live endpoint smoke checks passed for `2024-11-05` initialization, initialized notification, and tool discovery, alongside the existing 2025 and modern protocol profiles. Teams LWC rendering was subsequently confirmed on 6 October 2026 through the appPackage integration described above.

A subsequent user-supplied Copilot Studio proxy trace confirmed a successful `open_mcp_admin_friend` call with `objectApiName: Contact` and the 2024 JSON text fallback. That response alone does not prove UI rendering: inspect the preceding `tools/list` entry for `_meta.ui.resourceUri`, then look for `resources/read` of that URI and `bootstrap_lightning_out`. If no resource read occurs, investigate host MCP Apps support and metadata preservation through the connector/proxy. If a resource is fetched, inspect widget initialization and browser CSP errors. The proxy's `X-Frame-Options: SAMEORIGIN` on the tool-call SSE response does not establish that the widget iframe was blocked. Microsoft [Copilot Studio resource documentation](https://learn.microsoft.com/en-us/microsoft-copilot-studio/mcp-add-components-to-agent) and [Cowork MCP Apps documentation](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/mcp-apps-support) describe different client flows; do not assume identical UI support across Microsoft hosts.

## Supported transport profiles

### Microsoft sample references

Reviewed Microsoft's [interactive UI samples](https://github.com/microsoft/mcp-interactiveUI-samples/tree/8c2cb6eed8d916dd4d8af355c55133be98da95fd) on 5 October 2026. These examples provide a declarative-agent integration reference, not proof that the observed Copilot Studio connector supports the same renderer.

- The [Employee Training server](https://github.com/microsoft/mcp-interactiveUI-samples/blob/8c2cb6eed8d916dd4d8af355c55133be98da95fd/mcp-apps/employee-training/node/server.ts) uses `_meta.ui.resourceUri`, serves HTML through `resources/read` with `text/html;profile=mcp-app`, and declares `frameDomains` for `https://learn-video.azurefd.net`. Its React UI embeds videos through actual iframes.
- The repository's [capability table](https://github.com/microsoft/mcp-interactiveUI-samples/blob/8c2cb6eed8d916dd4d8af355c55133be98da95fd/M365-Agents-Toolkit-Instructions.md) marks `frameDomains` supported. This conflicts with the Microsoft Learn Copilot table reviewed during diagnosis; verify the effective CSP in the target Teams renderer rather than treating either table as an end-to-end result for Salesforce.
- The [Employee Training plugin manifest](https://github.com/microsoft/mcp-interactiveUI-samples/blob/8c2cb6eed8d916dd4d8af355c55133be98da95fd/mcp-apps/employee-training/node/appPackage/ai-plugin.json) registers a `RemoteMCPServer` runtime and includes a static `x-mcp_tool_description` with both `_meta.ui.resourceUri` and the compatibility alias `_meta["ui/resourceUri"]`. The bridge now emits both forms with the same URI for opening and inbound action tools, with explicit `_meta.ui.visibility: ["model", "app"]`. Bootstrap, event, and diagnostic helper tools retain app-only visibility. This is a compatibility measure matching the sample, not evidence that the standard nested metadata is invalid or that the observed host will render a widget.
- Its app manifest registers `copilotAgents.declarativeAgents`, and the README instructs makers to sideload the package into Teams. This differs from adding an MCP tool through a Copilot Studio Power Platform connector.
- The [Salesforce sample](https://github.com/microsoft/mcp-interactiveUI-samples/blob/8c2cb6eed8d916dd4d8af355c55133be98da95fd/mcp-apps/salesforce-crm/python/sf_crm_mcp/salesforce_server.py) renders its own React CRM UI backed by Salesforce API tools; it is not a Lightning Out iframe reference. Its handlers use structured output, whereas the bridge's 2024 profile supplies a JSON text fallback. That difference matters for widget data delivery after rendering starts, but does not establish why the host currently sends no resource read.

- **OpenAI modern:** `2026-07-28`, sessionless requests, with each JSON-RPC result returned as one completed SSE `message` event.
- **Legacy clients:** `2024-11-05`, `2025-06-18`, or `2025-11-25`, stateless-compatible requests, with completed SSE `message` responses. Existing requests carrying a valid bridge session ID remain compatible.
- **OpenAI legacy fallback:** legacy initialize requests from `openai-mcp/*` receive a session ID and completed SSE responses for compatibility with the observed client behavior.
- **Other modern clients:** `2026-07-28` remains sessionless and uses JSON responses unless a client-specific compatibility profile requires SSE.

User-agent matching selects a transport compatibility profile only. It is not an authentication or authorization mechanism.

## What “working” means

Validate each layer separately so a host rendering restriction is not mistaken for a server or OAuth failure:

1. **Negotiation:** `initialize` or `server/discover` returns the requested supported protocol version in the expected framing.
2. **Discovery:** the client proceeds to `tools/list` or consumes the tools returned by its discovery flow.
3. **Invocation:** `tools/call` returns durable structured content without a single-use frontdoor URL.
4. **Authentication:** every widget mount calls the app-only bootstrap tool, whose newly generated frontdoor URL establishes the Salesforce UI session.
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
