# Salesforce MCP App Bridge

Salesforce MCP App Bridge is a managed-package MCP server that turns configured Lightning Web Components into authenticated MCP Apps and generated tools without adding component-specific code to the bridge.

Version 0.1 supports both protocol eras on one Apex REST endpoint:

- MCP `2025-06-18` and `2025-11-25`: stateless-compatible `initialize` flows, with backward-compatible handling of existing session-bearing requests.
- MCP `2026-07-28`: sessionless `server/discover` flow with per-request metadata and standard routing headers.

## What it provides

- Configuration-driven MCP tools and `ui://` resources backed by Lightning Out 2.0.
- JSON Schema inputs mapped to allowlisted LWC public properties.
- Configured LWC-to-host messages and host-to-LWC action tools.
- Fresh, single-use Salesforce frontdoor URLs generated through JWT bearer and `/services/oauth2/singleaccess`.
- Opt-in, secret-safe diagnostics with rollback-resistant error capture.
- Public custom metadata types that extension packages can populate.
- Two disabled reference LWCs demonstrating record creation and viewing.

The bridge remains client-neutral and follows MCP Apps conventions. A host must support MCP App HTML resources and permit the nested Salesforce frame required by Lightning Out 2.0.

## Public routes

```text
MCP endpoint
https://{MY_DOMAIN}/services/apexrest/mcpapp/mcp

Protected-resource metadata
https://{MY_DOMAIN}/services/apexrest/mcpapp/mcp/.well-known/oauth-protected-resource

Salesforce authorization
https://{MY_DOMAIN}/services/oauth2/authorize

Salesforce token
https://{MY_DOMAIN}/services/oauth2/token
```

Apex REST cannot own a domain-root `/.well-known/*` route. The Salesforce My Domain does not currentyl expose the `./well-known/oauth-authorization-server` endpoint. Clients that soley rely on this resource will require an authentication proxy solution until Salesforce adds the `./well-known` endpoint.
Note That salesforce does expose the `/.well-known/openid-configuration` endpoint that MCP clients should fall back on, but this does not always happen in practice.

## Package Info

**Managed Package v67.0 - 0.2** `/packaging/installPackage.apexp?p0=04tP3000002E2YfIAK`

## Start here

1. Install the package and assign the **MCP App Bridge** permission set to the integration user.
2. Follow [Installation and org setup](docs/SETUP.md) to configure OAuth, JWT, allowed origins, and Lightning Out 2.0.
3. Connect the client to the namespaced MCP endpoint above.
4. Enable [diagnostic logging](docs/LOGGING.md) temporarily when validating a new client.
5. Optionally enable the [record creator/viewer demo](docs/DEMO.md).

Packaged configuration is safe by default: the core record, demo tools, event mappings, and logging switch are disabled, and no org-specific OAuth identifier, certificate name, Lightning Out app ID, token, or URL is included.

## Configuration model

- **MCP App Bridge Core Configuration** controls OAuth/JWT settings, the legacy protocol version, scopes, allowed origins, session timeout, and diagnostic logging.
- **MCP App Bridge Lightning Out 2.0** defines generated UI tools, components, resource URIs, static resources, and input schemas.
- **MCP App Bridge Event Mapping** defines LWC-to-host messages and host-to-LWC action tools.

## Documentation

- [Installation and org setup](docs/SETUP.md)
- [Diagnostic logging reference](docs/LOGGING.md)
- [Architecture and security boundaries](docs/ARCHITECTURE.md)
- [Client compatibility matrix](docs/COMPATIBILITY.md)
- [Add and package your own LWC](docs/EXTENDING.md)
- [Record creator demo](docs/DEMO.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Managed-package release checklist](docs/PACKAGING.md)

## Development

Deploy and test:

```powershell
sf project deploy start --source-dir force-app --test-level RunLocalTests --wait 60
```

Run static analysis and package guardrails:

```powershell
sf code-analyzer run --workspace force-app --view detail
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Validate-PackageMetadata.ps1
```

The permission set grants bridge runtime, log, and demo Apex access. It deliberately does not grant access to arbitrary Salesforce business data; component packages and administrators must grant their own CRUD/FLS permissions.

## Namespace behavior

Source metadata is namespace-neutral. Salesforce exposes installed components with namespace `mcpapp`, for example `mcpapp.McpRestEndpoint`, `mcpapp__MCP_Bridge_Log__c`, and `mcpapp-lwc-record-creator`. Do not add namespace prefixes to API names inside this package's source.

## Known host limitation

A rendered widget is an isolated UI instance. Model-invoked UI tools normally create a new widget; MCP Apps does not define a portable mechanism for addressing an arbitrary older widget. Hosts whose Content Security Policy blocks iframe-inside-iframe rendering cannot display Lightning Out even when authentication and frontdoor generation succeed. See the [client compatibility matrix](docs/COMPATIBILITY.md) for verified host behavior and [Troubleshooting](docs/TROUBLESHOOTING.md#salesforce-frame-is-blocked-by-the-mcp-client) for the distinct iframe failure modes.
