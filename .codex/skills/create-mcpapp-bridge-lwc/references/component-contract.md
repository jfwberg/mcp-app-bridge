# MCP App Bridge LWC contract

## Public inputs

Declare scalar values directly. Parse complex values from either already-deserialized input or JSON text.

```js
import { api, LightningElement } from 'lwc';

export default class AccountWorkbench extends LightningElement {
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
        if (this._connected) this.refreshFromInputs();
    }

    connectedCallback() {
        this._connected = true;
        this.refreshFromInputs();
    }
}
```

The schema property `recordIds` is rendered as the Lightning Out attribute `record-ids`.
Opening inputs are not guaranteed to be present during the first `connectedCallback`. MCP Apps hosts may deliver them afterward. Public setters must therefore update any rows, queries, or derived state that depend on those values. When several setters participate in one refresh, coalesce them into a microtask and ignore stale asynchronous responses.

## Outbound event

Use a JSON round trip to detach Lightning Web Security or Apex proxy values, then send JSON text:

```js
const payload = JSON.parse(JSON.stringify({ recordIds: this._recordIds }));
this.dispatchEvent(new CustomEvent('records_selected', {
    detail: JSON.stringify(payload),
    bubbles: true,
    composed: true
}));
```

The event mapping's `mcpapp__LWC_Event_Name__c` must exactly equal `records_selected`.
The component does not register a listener for its own outbound event. The shared host reads the component's event mappings and registers the listener after Lightning Out signals that the component is ready.

## Inbound event

Keep a stable handler reference so it can be removed:

```js
_handleRefresh = (event) => {
    const detail = typeof event.detail === 'string'
        ? JSON.parse(event.detail)
        : event.detail;
    // Validate detail before applying it.
};

connectedCallback() {
    this.addEventListener('refresh_records', this._handleRefresh);
}

disconnectedCallback() {
    this.removeEventListener('refresh_records', this._handleRefresh);
}
```

Handle malformed input without leaving an unhandled promise rejection.
The inbound mapping's `mcpapp__LWC_Event_Name__c` must exactly equal `refresh_records`. The shared host turns the configured MCP action result into this DOM event on the currently mounted component instance.

## Lightning Out and metadata

- Add the component to the org's Lightning Out 2.0 application.
- Store the generated custom-element name in `mcpapp__Component_Name__c`.
- Set `mcpapp__Static_Resource_Name__c` to `McpLightningOutHost`. This is a stored resource `Name`, not a metadata API reference, so the value isn't namespace-prefixed.
- Every installed bridge custom metadata type and field reference in a subscriber/extension project must begin with `mcpapp__`.
- The extension component keeps its own package namespace in the custom-element name; it does not become an `mcpapp` component.
