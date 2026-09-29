# Add your own Lightning Web Component

Codex users can use the project-local skills in `.codex/skills/create-mcpapp-bridge-lwc` and `.codex/skills/generate-mcpapp-metadata` to scaffold this contract and its records.

## Managed-package namespace

The bridge is installed with namespace `mcpapp`. In a subscriber org or a separate extension-package project, use the fully qualified API names for the installed bridge metadata:

- `mcpapp__MCP_App_Bridge_LO2_Config__mdt`
- `mcpapp__MCP_App_Bridge_Event_Mapping__mdt`
- fields such as `mcpapp__Enabled__c`, `mcpapp__Component_Name__c`, and `mcpapp__LWC_Event_Name__c`
- installed host field `mcpapp__Static_Resource_Name__c`, whose stored value remains `McpLightningOutHost` because it is queried as a resource `Name`, not used as a metadata API reference

The metadata record filename must also identify the installed type, for example `mcpapp__MCP_App_Bridge_LO2_Config.my_component.md-meta.xml`. Inside this bridge's own package source, keep the existing unprefixed names: Salesforce adds `mcpapp__` during managed packaging and installation.

## Component contract

Expose each initial value with `@api`. Lightning Out transports public values as HTML attributes, so `recordIds` becomes `record-ids`. Complex values arrive as JSON strings and should be parsed defensively.

Do not assume those inputs are available during the first `connectedCallback`. An MCP Apps host can deliver approved tool arguments after the component connects. Each public setter must therefore refresh dependent UI or data after connection. If several setters rebuild the same state, coalesce them into one microtask and guard asynchronous Apex responses so an older default-value request cannot overwrite the real inputs.

```js
import { api, LightningElement } from 'lwc';

export default class MyComponent extends LightningElement {
    _recordIds = [];
    _connected = false;

    @api
    get recordIds() {
        return this._recordIds;
    }
    set recordIds(value) {
        if (Array.isArray(value)) {
            this._recordIds = value;
        } else {
            try {
                this._recordIds = JSON.parse(value || '[]');
            } catch {
                this._recordIds = [];
            }
        }
        if (this._connected) this.scheduleRefresh();
    }

    connectedCallback() {
        this._connected = true;
        this.scheduleRefresh();
    }
}
```

For an outbound event, detach the payload and send JSON text across the Lightning Out boundary:

```js
const payload = JSON.parse(JSON.stringify({ recordIds: this._recordIds }));
this.dispatchEvent(new CustomEvent('records_selected', {
    detail: JSON.stringify(payload),
    bubbles: true,
    composed: true
}));
```

The shared host automatically listens for outbound events declared in enabled `LWC_TO_HOST` mappings. The dispatched event name must exactly match **LWC Event Name**; the LWC does not need to listen for its own event.

For a host-to-LWC action, register and remove a bound DOM event handler in the component lifecycle. Its DOM event name must exactly match the enabled `HOST_TO_LWC` mapping's **LWC Event Name**. The bridge dispatches that event on the currently mounted component when the configured MCP action tool runs.

## Lightning Out configuration

Create an **MCP App Bridge Lightning Out 2.0** record:

- Developer Name: stable component key.
- Enabled: publish or remove the generated tool.
- Lightning Out App ID: org-specific 18-character ID.
- Component Name: generated custom element, such as `acme-record-panel`.
- Resource URI: unique and versioned, such as `ui://acme/record-panel/v1/index.html`.
- Static Resource Name: `McpLightningOutHost`.
- Display Name and Description: model-facing tool information.
- Input Schema JSON: JSON Schema object describing public LWC inputs.

Only schema-declared input names cross into the component. Increment the resource URI version whenever the shared host behavior or component contract changes and clients could have cached the previous resource.

## Event mappings

Create an **MCP App Bridge Event Mapping** related to the component configuration.

### LWC to host

- Direction: `LWC_TO_HOST`
- LWC Event Name: exact custom event name.
- Host Action: `SEND_MESSAGE`
- LLM Instructions: what the model should do with the untrusted Salesforce payload.
- Maximum Payload Characters: explicit payload limit.

At runtime the host registers a listener for the configured event name after `lo.component.ready`. The LWC must emit a bubbling, composed event with detached JSON text in `detail`.

### Host to LWC

- Direction: `HOST_TO_LWC`
- Host Action: `DISPATCH_EVENT`
- LWC Event Name: DOM event handled by the component.
- MCP Tool Name, Title, Description, and Input Schema JSON: generated model-visible action tool.

At runtime the host maps the action result back to the configured DOM event and dispatches it on that widget's mounted LWC. The component is responsible for parsing and validating `event.detail`.

Model-invoked UI actions normally create a new widget. Do not design around mutating an arbitrary older widget instance.

## Extension-package guidance

Package your LWC, Apex controller, Lightning Out configuration record, and event mappings together. The bridge custom metadata types are public specifically so extension packages can contribute records. The target org must still create the Lightning Out app and populate its org-specific app ID after installation.
