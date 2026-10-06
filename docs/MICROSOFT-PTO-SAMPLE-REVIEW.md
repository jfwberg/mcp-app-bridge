# Microsoft PTO sample comparison

Reviewed the user-provided `copilot-da-ptorequest-msgraph-mcpapp` project on 6 October 2026. The source was inspected without running its provisioning instructions or modifying the original project.

## Differences relevant to the missing resource read

| Area | PTO sample | MCP App Bridge |
| --- | --- | --- |
| Agent registration | Teams app manifest registers a declarative agent; its action references `mcpapp-plugin.json` | Observed connection uses a Copilot Studio Power Platform connector |
| Tool snapshot | `RemoteMCPServer.spec.x-mcp_tool_description.tools` includes each tool's `_meta.ui.resourceUri` | The server returns that metadata in `tools/list`; metadata retained inside Microsoft's connector is not established |
| HTTP responses | SDK Streamable HTTP with `sessionIdGenerator: undefined` and `enableJsonResponse: true` | Legacy requests return a completed SSE message; default lifecycle is stateless |
| UI linkage | `_meta.ui.resourceUri` only in source and packaged tool snapshot | Both nested and flat URI forms |
| UI resource | `resources/read` returns self-contained HTML with `text/html;profile=mcp-app` | Same method and MIME type; HTML then bootstraps Lightning Out |
| Result data | Tool handlers return text plus `structuredContent` | 2024 compatibility profile converts structured data into an extra JSON text item |
| Widget connection | Official ext-apps React `useApp`; consumes `result.structuredContent` | Custom postMessage MCP Apps connection; Lightning Out bootstrap and nested Salesforce UI |
| Authentication | Widget MCP runtime is `None`; Microsoft Graph is a separate agent action | Salesforce OAuth through the proxy |

The sample pins MCP SDK `1.24.0` and ext-apps `1.0.0`; its source does not force protocol `2026-07-28` or declare `io.modelcontextprotocol/apps`. SDK-generated wire responses must be captured before asserting their exact negotiated version or capability advertisement.

The empty `capabilities` object in the sample's plugin manifest is a plugin-manifest setting, not an MCP initialize message. Likewise the React `useApp` capabilities object belongs to the widget-to-host handshake, not Microsoft-to-server negotiation.

## Recommended comparison

1. Run the unmodified PTO widget server and invoke `collect-pto-request` through the same Copilot Studio/Teams connector path. Record initialize, discovery, tool call, and whether `resources/read` follows. This tests the endpoint independently of Salesforce and nested frames.
2. Test the same endpoint through the included declarative-agent package. If only this route renders, investigate the connector/host integration rather than the Salesforce resource handler.
3. If the sample works through the connector, compare actual wire output with the bridge, starting with JSON versus SSE response framing and retained metadata. Change one factor at a time.
4. Once a resource read occurs, test widget handshake/data delivery, then nested iframe support and Lightning Out authentication.

The existing `m365agents*.yml` provisioning flow creates Entra and Teams applications and OAuth registrations for Graph. It is broader than a minimal UI test. Building the server alone does not publish it or require those registrations; publishing or installing the declarative agent requires a chosen hosting URL and tenant setup.

No server runtime changes were made as part of this inspection. The sample identifies concrete differences, so merging its PTO/Graph behavior into the bridge would confound the comparison.
