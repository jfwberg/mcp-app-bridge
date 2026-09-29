---
name: create-mcpapp-bridge-lwc
description: Create or adapt a Lightning Web Component for MCP App Bridge and Lightning Out 2.0, including schema-driven inputs, safely cloneable outbound events, optional inbound actions, and matching namespaced bridge metadata.
---

# Create an MCP App Bridge LWC

Build a clear, packageable LWC that obeys the bridge contract. Read [references/component-contract.md](references/component-contract.md), then use the `generate-mcpapp-metadata` skill for its configuration records.

## Workflow

1. Inspect existing project conventions, API version, namespace, controllers, tests, and Lightning Out app membership.
2. Define the smallest useful JSON Schema for the component's initial inputs.
3. Expose each schema property through `@api`. Parse arrays and objects defensively because Lightning Out can deliver complex values as JSON strings. Treat setters as asynchronous lifecycle inputs: values may arrive after `connectedCallback`, so rebuild or refresh dependent state when setters run after connection.
4. Keep the UI example-oriented and make validation failures visible in the component.
5. For LWC-to-host communication, dispatch a bubbling, composed `CustomEvent` whose `detail` is a JSON string created from detached plain data. Its name must exactly match the outbound mapping; the shared host installs that listener automatically.
6. For host-to-LWC communication, listen for the exact event named by the inbound mapping and add/remove the same bound DOM event handler during component lifecycle. The shared host dispatches that DOM event when its configured MCP action tool runs.
7. Add Apex only when Salesforce data access or mutation requires it. Validate object and field names with describe information, enforce CRUD/FLS, and return simple serializable DTOs.
8. Generate namespaced metadata for an extension project: all installed bridge objects and fields use `mcpapp__`. Do not prefix the extension LWC's own namespace with `mcpapp__`.
9. Test input parsing, error handling, event payloads, and Apex behavior; perform a check-only deployment when possible.

## Boundaries

- Never send functions, proxies, events, DOM nodes, Apex proxy objects, or other non-cloneable values across the iframe boundary.
- Do not put OAuth tokens, session IDs, frontdoor URLs, org URLs, or Lightning Out app IDs in reusable source.
- Do not add component-specific logic to the bridge Apex or shared host resource.
- Do not assume a command can update any previously rendered widget instance.
- Do not assume opening inputs exist during `connectedCallback`; hosts can deliver them later in the MCP Apps lifecycle.

## Naming

- LWC bundle: ordinary camel case, such as `accountWorkbench`.
- Packaged custom element: `<extension-namespace>-account-workbench`.
- Bridge CMDT type and field references in extension source: `mcpapp__MCP_App_Bridge_LO2_Config__mdt`, `mcpapp__Component_Name__c`, and so on.
- Within the bridge package itself, retain unprefixed source API names; packaging adds `mcpapp__`.
