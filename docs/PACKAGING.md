# Managed-package release checklist

## Before creating a version

- Confirm namespace `mcpapp` and API version 67.0 are intentional.
- Confirm only the Record Creator and Record Viewer examples ship.
- Keep all org URLs, OAuth clients, secrets, tokens, and Lightning Out app IDs out of package source.
- Keep the packaged core and demo configuration records disabled.
- Confirm logging is disabled and the package includes the log object, tab, platform event, trigger, layout, fields, and permission-set access.
- Confirm `2025-06-18`, `2025-11-25`, and `2026-07-28` endpoint tests pass.
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
