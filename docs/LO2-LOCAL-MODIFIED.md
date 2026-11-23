# Local modified Lightning Out loader

For the step-by-step download, inspection, rebuild, embedded-delivery, and client-validation procedure, see [Update the local modified LO2 loader](UPDATING-LOCAL-LO2.md).

This is a locally modified build of the downloaded Salesforce LO2 2.2.5 loader. It replaces exactly two `loAppOrigin:window.location.origin` assignments with an effective-origin resolver. It retains upstream license notices. The original SHA-256 is recorded in the generated files and build script.

The resolver uses `window.origin`, or the script's optional `data-lo-app-origin` attribute. Any override must equal the real HTTP(S) effective origin. Opaque origins are rejected; the patch does not bypass sandboxing or weaken message origin checks.

## Local comparison

1. Run `.testdata/lo2/webserver.bat` and open `lo2-origin-repro.html`.
2. Select **srcdoc** mode and **Leave URL and attributes unchanged** for the origin experiment, to isolate the loader change.
3. Select **Local modified effective-origin loader**. Leave the origin override at the test host origin.
4. Supply a fresh frontdoor URL and run. Compare with the stock loader using another fresh URL.
5. Check component readiness, inputs, events, and session behavior. The user confirmed the local modified loader works in Teams and the other tested clients, including Slack, on 26 October 2026. Revalidate inputs, events, and session behavior whenever updating the loader.

When hosting the reproduction page elsewhere, upload `lo2-modified.js` alongside it.

## Salesforce resource

`McpLo2Modified` contains the generated JavaScript as a separate static resource with Public cache control. Enable **LO2 JS From Static Resource** on **MCP App Bridge Core Configuration ? Default** to select this loader in `McpLightningOutHost`. The setting is subscriber-controlled and defaults to false; disabled uses Salesforce's hosted latest loader. When enabled, `resources/read` reads the packaged loader server-side and embeds it in the HTML, executing it after bootstrap. The browser makes no separate static-resource request, so loader delivery does not depend on a Salesforce browser session or cache. When disabled, the loader is omitted from the HTML and the hosted loader is fetched as before. The resource is under `force-app`, so it will be included in future package builds unless excluded or removed deliberately.

For a separate host page, load the deployed resource's actual URL as the script source instead of the stock loader, respecting the host's CSP. Never load both loaders into the same document. This loader still contacts Salesforce for authentication, components, and other assets; it is not a fully offline runtime.

Rebuild with `node scripts/build-lo2-modified.cjs` after placing the original inspected file at `.tmp/lo2-inspection/index.iife.prod.js`. The build rejects a different upstream hash. Run `node --test scripts/lo2-loader.test.mjs` to verify the copies and resolver. This pins an upstream snapshot; future Salesforce changes are not automatically incorporated.

Before embedded delivery, the local static-resource request could redirect from My Domain to the package-specific Visualforce host (for example, `https://ORG--mcpapp.vf.force.com`). When the local loader is enabled, MCP resource metadata includes that exact host in `ui.csp.resourceDomains`, resolved with Salesforce DomainCreator. Both resources/list and resources/read share this policy. Start a fresh widget/resource load after upgrading so the host receives the updated CSP; an already-mounted iframe retains its old policy. A script-src rejection for that host indicates missing or cached resource CSP metadata, not an OAuth failure.

The resource CSP also allows the org's exact files/content origin, resolved with `DomainCreator.getContentHostname()` (typically `https://ORG.file.force.com`), in resourceDomains and frameDomains. The loader checkbox is included in the Core Configuration page layout under Configuration Details. Existing subscriber layout customizations may require adding the field manually after upgrade.

Static-resource requests can also pass through the Lightning origin's `/visualforce/session` endpoint before reaching the Visualforce resource. When the local loader is enabled, resourceDomains includes the Lightning origin as well. Inclusion in connectDomains or frameDomains alone does not permit a script redirect there. This addresses CSP only; if the session endpoint subsequently returns HTML, authentication or resource delivery still needs investigation.

The build removes the upstream sourceMappingURL comment because its map is not packaged. This prevents DevTools from requesting the unavailable map; it does not change runtime behavior. Successful loading in Teams was confirmed by the user on 26 October 2026; The user subsequently confirmed it works in all tested clients, including Slack, with the setting enabled.

Embedded loader delivery requires no new Visualforce trusted domain. Existing resource-domain allowances remain for compatibility; Salesforce authentication and component frames still need their existing host and Salesforce CSP settings. Validate a fresh Teams and Slack widget after upgrading; old mounted widgets retain their original HTML.

## Clean-session findings (23 November 2026)

The former browser fetch of the static resource returned HTML 404/login content without a Salesforce session, producing MIME/nosniff failures. Public caching did not make that route reliable. Embedded delivery removes this bootstrap dependency; it does not remove Salesforce iframe authentication. Teams and Slack were confirmed working in clean Firefox sessions. Chrome Incognito worked after third-party cookies were allowed for the host site. No new Visualforce trusted domain is required by embedding. Use the normal hosted loader for Slack demos where it works, and revalidate both cookie and origin behaviour before retiring the modified loader.
