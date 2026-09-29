# Record creator demo

The packaged demo contains only two example LWCs:

- `mcpapp/lwcRecordCreator`
- `mcpapp/lwcRecordViewer`

The configuration records are disabled by default because Lightning Out app IDs are org-specific.

## Enable it

1. Create or reuse a Lightning Out 2.0 app containing both demo LWCs.
2. Set that app's 18-character ID on `demo_record_creator` and `demo_record_viewer` under **MCP App Bridge Lightning Out 2.0**.
3. Enable both records.
4. Confirm `demo_records_created` and `demo_records_viewed` event mappings are enabled.
5. Reconnect the MCP client.

## Primary prompt

> Open the record creator for three Technology prospect Accounts in London. Show Name, Industry, Type, and BillingCity, and let me edit them before saving.

Expected tool input:

```json
{
  "objectApiName": "Account",
  "recordCount": 3,
  "fieldValues": {
    "Industry": "Technology",
    "Type": "Prospect",
    "BillingCity": "London"
  },
  "fieldNames": ["Name", "Industry", "Type", "BillingCity"],
  "allowEditing": true
}
```

Enter names and create the records. The creator sends names and IDs to chat. The mapping asks the model to open `open_demo_record_viewer`; the viewer renders the records and its button returns the rows for a Markdown table.

## Supported demo metadata

- Account: `Name`, `Industry`, `Type`, `Phone`, `Website`, `BillingCity`
- Contact: `FirstName`, `LastName`, `Email`, `Phone`, `Title`
- Record count: 1–3

The Apex controller verifies that objects and fields exist, enforces the example allowlist, checks CRUD/FLS, and uses user-mode queries and DML. The activity panels expose inbound inputs, metadata checks, save/load results, and outbound events.

## Negative checks

With a direct MCP tester, try an unknown object, an unknown field, a disallowed field, or more than three records. The widget should show a readable error instead of silently ignoring invalid configuration.
