# Managed-package release checklist

## Teams local modified loader

The package includes `McpLo2Modified` and the subscriber-controlled **LO2 JS From Static Resource** core metadata checkbox. Keep its packaged Default value false so Salesforce's hosted latest loader remains the default. Subscribers can enable the local modified LO2 2.2.5 loader for Teams srcdoc origin failures, then start a fresh widget load. Preserve upstream license notices and rebuild both loader copies together when updating the pinned version. The standalone reproduction succeeds; packaged Teams validation is pending. See [Teams diagnosis](TROUBLESHOOTING.md#teams-lightning-out-fails-with-invalid-target-origin-null) and [loader maintenance](LO2-LOCAL-MODIFIED.md).

## Before creating a version

- Confirm namespace `mcpapp` and API version 68.0 are intentional.
- Confirm only the Record Creator and Record Viewer examples ship.
- Keep all org URLs, OAuth clients, secrets, tokens, and Lightning Out app IDs out of package source.
- Keep the packaged core and demo configuration records disabled.
- Confirm logging is disabled and the package includes the log object, tab, platform event, trigger, layout, fields, and permission-set access.
- Confirm `2024-11-05`, `2025-06-18`, `2025-11-25`, and `2026-07-28` endpoint tests pass.
- Keep configuration custom metadata public and configurable fields subscriber-controlled.
- Keep `MCP_Session__c` private.
- Verify the `MCP App Bridge` permission set includes all bridge and demo Apex classes.
- Run all local Apex tests and the code analyzer.
- Run `scripts/Validate-PackageMetadata.ps1`; it fails if packaged defaults are enabled or org-specific JWT identifiers are present.
- Install the beta into a fresh org and execute `docs/DEMO.md` from end to end.

## Create a 2GP package

Create the package only once in the Dev Hub, then add the returned `0Ho...` ID to `packageAliases` and the package directory configuration in `sfdx-project.json`.

```powershell
sf package create --name "MCP App Bridge" --package-type Managed --path force-app --target-dev-hub <DEV_HUB_ALIAS>
```

Configure the package directory with a version name and `0.1.0.NEXT`, then create a beta version:

```powershell
sf package version create --package "MCP App Bridge" --installation-key-bypass --code-coverage --wait 60 --target-dev-hub <DEV_HUB_ALIAS>
```

Do not promote the first version until installation, upgrade, OAuth, Lightning Out, CSP, creator, viewer, and both outbound event paths have been tested in a clean subscriber org.

Before publishing the repository, confirm `.testdata/`, `.sf/`, `.sfdx/`, `.env*`, logs, coverage, and temporary validation output are ignored. Search the complete source tree for consumer keys, client secrets, access tokens, scratch-org domains, usernames, frontdoor URLs, and certificate names. OAuth consumer keys are identifiers rather than bearer secrets, but package source must still remain org-neutral.
