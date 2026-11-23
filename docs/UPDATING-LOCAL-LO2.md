# Update the local modified Lightning Out loader

Use this procedure when Salesforce publishes a new LO2 loader, or periodically to check whether the hosted `latest` file has changed. The local copy is pinned; it does not update automatically. On 23 November 2026, the user confirmed the embedded-loader path in clean Firefox sessions for Teams and Slack. Chrome required a host-site third-party-cookie allowance. Prefer the hosted-loader route for Slack demos where it works.

## 1. Download and identify the upstream version

From the repository root, download the public loader from the org being tested. The current source URL is:

```text
https://ezform-dev-ed.my.salesforce.com/lightning/lightning.out.latest/index.iife.prod.js
```

For another org, substitute its My Domain. Do not include OAuth tokens or frontdoor URLs.

```powershell
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force .tmp/lo2-inspection | Out-Null
Invoke-WebRequest -Uri 'https://ezform-dev-ed.my.salesforce.com/lightning/lightning.out.latest/index.iife.prod.js' -OutFile '.tmp/lo2-inspection/index.iife.prod.js'
Get-FileHash '.tmp/lo2-inspection/index.iife.prod.js' -Algorithm SHA256
```

Keep a copy of the previous upstream file before overwriting it if you want a direct diff. The `.tmp` folder is ignored by Git. Confirm the downloaded body is JavaScript rather than a login/error page. Inspect its embedded `loVersion` and compare the SHA-256 with `expectedHash` in `scripts/build-lo2-modified.cjs`. A hash can change without a version-number change.

If the hash is unchanged, there is no new upstream loader to incorporate.

## 2. Inspect whether the origin patch is still needed

```powershell
rg -o 'loAppOrigin:.{0,160}|loVersion.{0,80}|sourceMappingURL[^\r\n]*' .tmp/lo2-inspection/index.iife.prod.js
```

The original LO2 2.2.5 snapshot contains exactly two occurrences of:

```js
loAppOrigin:window.location.origin
```

One supplies the application router's generated auth/component URLs; the other supplies the message-page URL. In a `srcdoc` document, `location.origin` is `"null"` even when the effective `window.origin` is a valid inherited HTTPS origin.

Check both paths in the new source. If Salesforce has fixed inherited-origin support, test the stock loader in srcdoc mode first. Prefer turning off the local-loader setting once the stock version is verified; do not force an obsolete patch onto corrected code.

If the implementation changed, inspect the surrounding URL construction, incoming origin/source checks, authentication flow, and additional asset loads. Do not blindly change the expected match count to make the build pass. Minified identifiers and exact expressions can change between releases.

## 3. Update the build recipe

Edit **`scripts/build-lo2-modified.cjs`**:

1. Set `expectedHash` to the inspected new upstream SHA-256, in lowercase. Never bypass the hash guard.
2. Update the LO2 version in the generated header.
3. If necessary, update `needle` and the expected occurrence count after reviewing the new implementation. The current recipe replaces exactly the two expressions above with `loAppOrigin:modifiedLo2Origin()`.
4. Preserve the resolver's safeguards: use the real effective `window.origin`; require HTTP(S); reject opaque origins and overrides that differ from the effective origin. Do not add wildcard messaging or spoof an origin.
5. Retain upstream copyright/license notices. Keep removing the upstream `sourceMappingURL` reference because its map is not packaged.

Do not manually patch only the minified static resource. The build recipe must remain reproducible.

## 4. Rebuild both loader copies

```powershell
node scripts/build-lo2-modified.cjs
```

This writes identical files:

- `.testdata/lo2/lo2-modified.js` — served alongside the standalone reproduction page.
- `force-app/main/default/staticresources/McpLo2Modified.resource` — packaged Salesforce static resource.

The `.testdata` copy and browser reproduction helpers are local-only and ignored by Git. The build creates the loader copy's directory if needed. A fresh public checkout includes the build recipe, packaged resource, and automated tests, but not the private reproduction page or web server. Use your own normal/srcdoc host for browser comparison if those local helpers are unavailable.

Keep `McpLo2Modified.resource-meta.xml` as JavaScript (`application/javascript`). Do not rename the resource without updating its consumers.

## 5. Update version references and embedded delivery

Search the current references:

```powershell
rg -n '2\.2\.5|2\.2\.5-origin-1|McpLo2Modified' scripts docs force-app/main/default/classes force-app/main/default/objects
```

Update these as appropriate:

| File | What to update |
| --- | --- |
| `force-app/main/default/classes/McpLightningOutService.cls` | Keep the hosted URL when disabled and no external loader URL when enabled. The modified loader is embedded by `McpResourceRegistry`, not fetched through a cache-key URL. |
| `force-app/main/default/classes/McpLightningOutServiceTest.cls` | Keep checkbox selection and enabled/disabled HTML embedding tests. |
| `scripts/widget-origin.test.mjs` | Preserve origin diagnostics and external-script origin checks. |
| `scripts/lo2-loader.test.mjs` | Adjust structural assertions only when the reviewed patch structure changes; retain syntax, origin-safety, and absent-source-map checks against the packaged resource. |
| `force-app/main/default/objects/MCP_App_Bridge_Core_Config__mdt/fields/LO2_JS_FROM_STATIC_RESOURCE__c.field-meta.xml` | Update the pinned version in description/help text if it changes. Keep the checkbox subscriber-controlled and default false. |
| `force-app/main/default/staticresources/McpLo2Modified.resource-meta.xml` | Update its version description if it changes. |
| `docs/LO2-LOCAL-MODIFIED.md`, `docs/SETUP.md`, and other Teams guidance | Record the new pinned version and actual validation results. Preserve dated historical observations. |

The resource registry reads the packaged static resource server-side. Do not hardcode an org hostname or namespace into the modified JavaScript.

## 6. Run local and Salesforce validation

```powershell
node --test scripts/lo2-loader.test.mjs scripts/widget-origin.test.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Validate-PackageMetadata.ps1
git diff --check
```

Run the relevant Apex tests through your normal Salesforce validation/package build, particularly `McpLightningOutServiceTest`. Local Node tests do not validate Apex or actual Salesforce session behavior.

In `.testdata/lo2/lo2-origin-repro.html`, select **Leave URL and attributes unchanged**, then compare stock and local modified loaders in both normal and srcdoc frame modes. Use a fresh single-use frontdoor URL for every run. Verify readiness, inputs, component events, session expiry/refresh where available, and absence of source-map requests. Do not share the expanded frontdoor URL inspection output.

## 7. Package and check the real clients

Use the normal package build/release process. After installing the update, enable **LO2 JS From Static Resource** on **Core Configuration → Default**, then create a fresh widget instance.

Check Teams and Slack plus the other clients you support, with the setting enabled. Also check the default hosted-loader path with the setting disabled. With the checkbox enabled, confirm the `resources/read` HTML contains the modified loader and Network shows no separate request for `McpLo2Modified`. With it disabled, confirm the modified code is absent and the hosted loader is requested. Verify `COMPONENT_READY`, inputs, events, and session behavior using clean sessions, including Chrome cookie settings.

If redirects or assets change, inspect the actual `resources/read` response and effective CSP. Current resource domains include the org's My Domain and files host; the local-loader option also allows Lightning and the package's Visualforce host. Resolve added hosts through Salesforce's domain APIs rather than introducing broad wildcards. There is no static-resource redirect in the embedded-loader route. Investigate remaining redirects as authentication/component requests; do not add `www.salesforce.com` to suppress a frame error.

## Rollback and review

Turning off **LO2 JS From Static Resource** selects Salesforce's hosted loader on the next widget load, but that may reintroduce the original srcdoc issue if Salesforce has not fixed it. To restore a previous local build, restore its build recipe/generated files, deploy/package through the normal process, and start fresh widgets to retrieve the new HTML. Do not assume installed managed-package versions can be downgraded.

Before committing, review the source diff, keep credentials/frontdoor URLs out of tracked files, and record the upstream version/hash, patch changes, and client checks performed.
