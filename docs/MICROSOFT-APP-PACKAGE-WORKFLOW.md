# Create or update a Microsoft appPackage

Use this workflow for the packaged Microsoft Teams/Microsoft 365 integration. The Copilot Studio agent/connector route tested here does not render MCP Apps UI.

## Rebuild the existing EZ Form package

From the repository root:

```powershell
node scripts/build_microsoft_app_package.cjs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/zip_microsoft_app_package.ps1
```

The builder preserves the OAuth vault reference already in `appPackage/ai-plugin.json`. To replace it, set `$env:MCP_OAUTH_VAULT_ID` before building. This is Microsoft's registration ID, not the Salesforce consumer key or secret.

Before uploading an update, increment the app `version` in the builder. Keep the app ID unchanged for an update to the same app. The output is `appPackage/MCP-App-Bridge.zip`; uploading this replaces the installed package only through the appropriate Microsoft update/install flow.

## What to edit

The current builder is `scripts/build_microsoft_app_package.cjs`:

| Change | Where |
| --- | --- |
| Org domain / MCP endpoint | `salesforce` and `endpoint` constants |
| App version, ID, branding, valid domains | Generated `manifest.json` definition |
| Agent instructions and starter prompts | Generated `declarativeAgent.json` definition |
| UI tools | `tools` array and definitions |
| OAuth vault reference | `MCP_OAUTH_VAULT_ID` environment variable |

Record Creator and Record Viewer input schemas come from source custom metadata. Viewer resource URI also comes from metadata; Creator URI is pinned and checked against metadata. Admin Friend comes from the previously supplied EZ Form tool trace because its subscriber metadata is not in this repo. Callback schemas are pinned in the builder. This is a partial metadata-based builder, not automatic discovery of every deployed tool.

When adding or changing a tool, use its current deployed `tools/list` definition as the reference. Copy the exact name, input schema, description, and resource URI. Keep `_meta.ui.resourceUri` and `_meta["ui/resourceUri"]` identical. UI launch tools use `visibility: ["model", "app"]`; bootstrap, event, and diagnostic callbacks use `["app"]`.

The generated plugin must register the tool in all three places: `functions`, `runtimes[].run_for_functions`, and `runtimes[].spec.mcp_tool_description.tools`. The builder derives these from one array. Do not edit generated JSON alone: the next build overwrites it.

## Reusable Codex prompt

Copy this prompt and fill in the requested change:

> Create or update the Microsoft appPackage in this repository for MCP App Bridge. Requested change: **[describe org, endpoint, tools, or branding]**. Read docs/MICROSOFT-APP-PACKAGE-WORKFLOW.md and appPackage/README.md first. Update the builder rather than just generated manifests. Use current Salesforce custom metadata or a supplied deployed tools/list response for exact tool schemas and UI resource URIs; ask for missing subscriber definitions rather than inventing them. Preserve the existing app ID and Microsoft OAuth vault registration ID for an update, increment the app version, and keep OAuth secrets and tokens out of the package. Include the app-only callback tools. Rebuild the manifests, validate against Microsoft's published schemas, check ZIP root files and icon dimensions, and create the updated ZIP. Update the documentation for changed endpoints or setup requirements. Do not deploy Salesforce changes or upload to Microsoft unless requested. Report the ZIP path, version, included UI tools, and any remaining configuration required.

## Checks before installation

- Validate Teams, plugin, and declarative-agent JSON against their published schemas. The ZIP script checks JSON parsing and rejects an unresolved OAuth placeholder, but does **not** perform full schema validation.
- Verify the ZIP root contains `manifest.json`, `declarativeAgent.json`, `ai-plugin.json`, `color.png` (192 × 192), and `outline.png` (32 × 32).
- Ensure the Microsoft OAuth registration Base URL matches the packaged MCP endpoint. If using proxy OAuth, use matching proxy authorization/token/refresh endpoints; if using direct Salesforce OAuth, use the Salesforce endpoints together.
- Keep `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect` registered with the OAuth provider. Preserve popup communication on proxy OAuth routes.
- Configure Salesforce iframe trusted domains for the actual ancestor chain, including `https://*.widget-renderer.usercontent.microsoft` for the renderer observed in Teams.

After installation, launch a UI tool and verify `resources/read`, widget bootstrap, and LWC rendering. Package schema validation alone does not test authentication or host rendering. See [compatibility](COMPATIBILITY.md) for the confirmed setup and [package setup](../appPackage/README.md) for OAuth registration.
