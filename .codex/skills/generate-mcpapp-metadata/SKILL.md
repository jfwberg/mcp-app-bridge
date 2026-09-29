---
name: generate-mcpapp-metadata
description: Generate or update MCP App Bridge Lightning Out and event-mapping custom metadata records in a subscriber or extension Salesforce DX project. Use when registering an LWC as an MCP UI tool or mapping LWC-to-host and host-to-LWC events.
---

# Generate MCP App Bridge metadata

Create deployable custom metadata records for the installed MCP App Bridge package. Read [references/schema.md](references/schema.md) before generating records.

## Workflow

1. Inspect the target project's `sfdx-project.json`, existing custom metadata records, LWC bundle, and Lightning Out configuration.
2. Determine whether the target is:
   - this bridge's own `mcpapp` package source; or
   - a subscriber/extension project consuming the installed bridge.
3. Generate one Lightning Out configuration record per exposed component and only the event mappings the component implements.
4. Validate every JSON schema as JSON before XML-escaping it.
5. Keep org-specific Lightning Out app IDs out of reusable package source. Use an empty value or disabled record and document the post-install value.
6. Run a check-only deployment when an authenticated target org is available. Do not deploy or overwrite subscriber configuration unless requested.

## Namespace rule

For subscriber and extension-package metadata, reference the installed type and every installed field with `mcpapp__`:

- type/file prefix: `mcpapp__MCP_App_Bridge_LO2_Config`
- field: `mcpapp__Enabled__c`
- type/file prefix: `mcpapp__MCP_App_Bridge_Event_Mapping`
- field: `mcpapp__Lightning_Out_Config__c`

Do not manually prefix definitions or field references inside this bridge's own package source. Salesforce applies `mcpapp__` when the managed package is built or installed. Adding it in the defining package would create incorrect names.

## Output expectations

- Use stable lowercase developer names with underscores.
- Set `<protected>false</protected>` so the record remains configurable.
- Give each UI resource a unique, versioned URI.
- Treat component payloads as untrusted data in LLM instructions.
- Report generated files, required post-install values, and validation performed.

