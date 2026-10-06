# MCP App Bridge for Microsoft 365

For repeatable creation and updates, use the [appPackage workflow and reusable Codex prompt](../docs/MICROSOFT-APP-PACKAGE-WORKFLOW.md).

This is a pinned declarative-agent package based on [Microsoft's employee-training sample](https://github.com/microsoft/mcp-interactiveUI-samples/tree/main/mcp-apps/employee-training/node/appPackage). The generated package currently uses the direct EZ Form Salesforce MCP endpoint; no Salesforce code deployment is required. The user confirmed Salesforce LWC rendering in Teams on 6 October 2026 after configuring proxy OAuth headers and Salesforce iframe trusted domains.

**Current Microsoft limitation:** exposing an MCP server through a Copilot Studio agent/connector does not render MCP Apps UI in the tested route. Use this **appPackage** integration, which registers a declarative agent and RemoteMCPServer plugin. The packaged declarative agent is a different integration path from the agent/connector route.

For proxy OAuth, use matching proxy authorization, token, and refresh endpoints in the Teams OAuth registration. The tested OAuth navigation routes needed `Cross-Origin-Opener-Policy: unsafe-none` to preserve popup communication. Salesforce trusted iframe domains needed `https://*.widget-renderer.usercontent.microsoft` (without `.com`) plus the cloud Microsoft ancestors. See [the confirmed Teams setup](../docs/COMPATIBILITY.md) for the observed ancestor chain. Ensure the registration Base URL matches the MCP endpoint in the package you actually install.

The package exposes three UI tools: `open_demo_record_creator`, `open_demo_record_viewer`, and `open_mcp_admin_friend`. The plugin pins `open_demo_record_creator` to `ui://mcp-app-bridge/demo-record-creator/v8/index.html`, with nested and flat UI metadata. Its three app-only callback tools are also registered so the widget can bootstrap, route events, and report diagnostics. Record Creator, Record Viewer, and MCP Admin Friend are model-visible in MCP metadata. Record Viewer uses the URI from source metadata; Admin Friend uses `ui://xdemo/mcp-admin-friend/v1/index.html` and the input schema from the EZ Form tools/list trace supplied by the user. Confirm that subscriber URI still matches the installed EZ Form configuration. The current v2.4 schema uses `mcp_tool_description` rather than the sample's older `x-mcp_tool_description` spelling.

## Configure OAuth

Follow [Microsoft's OAuth instructions](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/plugin-authentication-oauth). In the [Teams Developer Portal](https://dev.teams.microsoft.com), choose **Tools → OAuth client registration** and register:

| Setting | Value |
| --- | --- |
| Name | EZ Form Salesforce MCP |
| Base URL | Copy `runtimes[0].spec.url` from `ai-plugin.json` (`https://ezform-dev-ed.my.salesforce.com/services/apexrest/mcpapp/mcp`) |
| Authorization endpoint | `https://ezform-dev-ed.my.salesforce.com/services/oauth2/authorize` |
| Token and refresh endpoints | `https://ezform-dev-ed.my.salesforce.com/services/oauth2/token` |
| Client ID / secret | Existing Salesforce OAuth application's consumer key / secret; enter these in the portal only |
| Scopes | `api refresh_token` (must be enabled on the Salesforce OAuth application) |
| PKCE | Enabled; Salesforce client settings must support PKCE |
| Restrict usage by org | Your organization for initial testing |
| Restrict usage by app | **Any Teams app**, as required by Microsoft's current MCP OAuth guidance |

The Salesforce OAuth application must allow callback URL `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect`. The existing Copilot Studio connector registration is not automatically a Teams OAuth vault registration. The portal returns an **OAuth client registration ID**: this is the manifest's `reference_id`, not the Salesforce consumer key. No credentials belong in this folder or ZIP.

The package developer website, privacy and terms URLs currently point to the EZ Form org for private testing. Replace them with your real policy pages before broader distribution.

## Build and upload

From the repository root in PowerShell:

```powershell
$env:MCP_OAUTH_VAULT_ID = '<OAuth client registration ID from Teams Developer Portal>'
node scripts/build_microsoft_app_package.cjs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/zip_microsoft_app_package.ps1
```

Upload `appPackage/MCP-App-Bridge.zip` using your tenant's custom app upload flow. The ZIP contains the three JSON manifests and two icons at its root. Installation depends on your tenant's custom-app and declarative-agent policies and availability of MCP Apps rendering.

The generated manifests passed validation against Microsoft's published Teams v1.24, plugin v2.4, and declarative-agent v1.6 JSON schemas. This is structural validation; authentication and rendering require installation in your tenant.

`MCP-App-Bridge.template.zip` is a review artifact with an unresolved OAuth reference, **not an install-ready authenticated package**. The ZIP script refuses to create the final package with this placeholder unless `-AllowUnconfigured` is explicitly used.

## First rendering test

1. Open the installed MCP App Bridge agent in the supported Microsoft 365 host and request “Open a form to create one Account.” Complete Salesforce sign-in when prompted.
2. Check MCP endpoint logs (or proxy logs when using the proxy) for `tools/call` with `open_demo_record_creator`, then `resources/read` for the pinned v8 URI. That second request confirms the host has started loading the UI.
3. After the HTML loads, check `bootstrap_lightning_out` and subsequent lifecycle diagnostics. A failure here is separate from failure to fetch the resource. Salesforce iframe/CSP policy and host support still need real-host testing.
4. Save a test record only when ready; the form writes to the EZ Form org.

If tool execution succeeds but no resource read appears, capture the host developer diagnostics and compare against the working Microsoft sample. The packaged Teams integration has rendered the nested Lightning Out frame successfully; use the ancestor-domain checks above when another deployment is blocked.

Regenerate when tool inputs change; the build reads Record Creator's input schema from source metadata and checks the pinned URI. Helper schemas are explicitly pinned in the build script. Increment manifest version before uploading an update; change the stable app ID only for a separate app. Do not rebuild an updated manifest without first updating the version in the builder.
