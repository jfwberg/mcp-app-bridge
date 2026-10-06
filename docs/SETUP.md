# Installation and org setup

For Microsoft Teams, use the [Microsoft appPackage setup](../appPackage/README.md). At this stage, the tested Copilot Studio agent/connector route exposes tools but does not render MCP Apps UI; a packaged declarative-agent integration is required. Teams LWC rendering was confirmed on 6 October 2026. Configure both OAuth popup headers and Salesforce trusted iframe domains as described in [client compatibility](COMPATIBILITY.md).

## 1. Assign access

Assign the packaged **MCP App Bridge** permission set to every integration user. Grant those users the object and field permissions required by the LWCs they launch; the bridge permission set does not grant access to arbitrary business data.

## 2. Configure the core record

Edit the `Default` record under **MCP App Bridge Core Configuration**.

| Field | Value |
| --- | --- |
| Enabled | `true` |
| ECA Consumer Key | Consumer key from the External Client App |
| ECA Certificate Name | Developer name from Certificate and Key Management |
| Required Scopes | `api web refresh_token` |
| Protocol Version | `2025-11-25` (the preferred legacy handshake revision; `2024-11-05`, `2025-06-18`, and `2026-07-28` are also supported automatically) |
| Logging Enabled | Disabled by default. Enable temporarily to create sanitized `MCP_Bridge_Log__c` diagnostic records. |
| MCP Session Timeout Minutes | `30` |
| Allowed Origins | Comma-separated MCP host origins |

## Diagnostic logging

Logging is disabled in the packaged default. Enable it temporarily from the `Default` core configuration, reproduce the issue, and inspect **MCP Bridge Logs** from the App Launcher. See the [diagnostic logging reference](LOGGING.md) for every field and lifecycle stage, trace interpretation, asynchronous error behavior, and retention guidance.

Packaged configuration contains no org-specific OAuth identifier, certificate name, Lightning Out app ID, token, or URL.

## 3. Configure OAuth

Create an External Client App suitable for the MCP client's authorization-code plus PKCE connection. Include `api`, `web`, and `refresh_token` scopes and configure the callback URL required by the MCP client.

To make Lightning Out bootstrap independent of the MCP client's access-token format and refresh behavior:

1. Create a Salesforce-managed certificate under **Certificate and Key Management**.
2. Enable JWT Bearer Flow on the External Client App and upload that certificate's public certificate.
3. Configure the ECA policy for **Admin approved users are pre-authorized** and associate the permission set used by MCP App Bridge users.
4. Ensure every MCP App Bridge user is assigned that permission set. The bridge uses the current Apex user as the JWT subject; Salesforce JWT bearer flow represents that subject by username.
5. Copy the ECA consumer key and Salesforce certificate developer name into the core metadata fields above.

When both JWT fields are configured, the bridge signs an assertion in Apex. Its audience is `https://test.salesforce.com` for a sandbox or scratch org and `https://login.salesforce.com` for a production org. Apex sends the token request to the current org's My Domain and immediately exchanges the returned access token at the returned instance URL's `/services/oauth2/singleaccess` endpoint. Tokens and assertions are never returned to the widget or persisted.

If JWT settings are absent, the bridge retains its legacy inbound bearer/Apex-session fallback. If JWT authentication fails, verify the consumer key, certificate developer name, certificate uploaded to the ECA, JWT-flow enablement, and current-user pre-authorization. The bridge exposes only a safe error category and recovery message, never the assertion, token, or upstream response body.

## 4. Configure Lightning Out 2.0

Lightning Out applications are org-specific and cannot be packaged.

1. Create or reuse a Lightning Out 2.0 app.
2. Add every LWC referenced by a bridge configuration.
3. Add the MCP client's widget origins as Host Page Domain Names.
4. Add those origins under **Session Settings → Trusted Domains for Inline Frames**, with iframe type **Lightning Out**.
5. Add any Salesforce My Domain, Lightning, and file domains required by the MCP client's CSP configuration.
6. Ensure **Require first-party use of Salesforce cookies** is disabled under My Domain if the chosen host requires third-party cookies.
7. Copy the app's 18-character ID into each relevant Lightning Out configuration record.

## 5. Schedule cleanup

Run this once as an administrator:

```apex
McpSessionCleanupSchedulable.scheduleHourly();
```

## 6. Connect the MCP client

Use the namespaced endpoint:

```text
https://{MY_DOMAIN}/services/apexrest/mcpapp/mcp
```

Reconnect the client whenever tool configuration or a versioned `ui://` resource URI changes.

The same endpoint supports both MCP protocol eras. Legacy clients negotiate `2024-11-05`, `2025-06-18`, or `2025-11-25` through `initialize`; the bridge does not assign the optional `MCP-Session-Id`, and subsequent requests identify their revision with `MCP-Protocol-Version` (optional for `2024-11-05`; headerless stateless requests use that revision). Modern clients call `server/discover`, select `2026-07-28`, and send sessionless requests containing matching protocol metadata and standard MCP routing headers. Do not send a legacy session ID on behalf of a modern client; the server deliberately keeps the two lifecycles separate.

If a widget cannot create its Salesforce UI session, see [Troubleshooting](TROUBLESHOOTING.md) for the bootstrap error categories and configuration checks.
