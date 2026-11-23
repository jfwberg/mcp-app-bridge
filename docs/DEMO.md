# MCP App Bridge demos

Choose the built-in record creator/viewer or the optional [FSC Process Demo](https://github.com/jfwberg/fsc-process-demo) extension. Both use the same bridge endpoint and authentication.

## Demo 1: Record creator and viewer

The packaged demo contains only two example LWCs:

- `mcpapp/lwcRecordCreator`
- `mcpapp/lwcRecordViewer`

The Lightning Out configuration records are disabled by default because app IDs are org-specific. Their event mappings are enabled by default and become active when their parent configuration is enabled.

### Enable it

1. Create or reuse a Lightning Out 2.0 app containing both demo LWCs.
2. Set that app's 18-character ID on `demo_record_creator` and `demo_record_viewer` under **MCP App Bridge Lightning Out 2.0**.
3. Enable both records.
4. Confirm the pre-enabled `demo_records_created` and `demo_records_viewed` event mappings remain enabled.
5. Reconnect the MCP client.

### Primary prompt

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

### Supported demo metadata

- Account: `Name`, `Industry`, `Type`, `Phone`, `Website`, `BillingCity`
- Contact: `FirstName`, `LastName`, `Email`, `Phone`, `Title`
- Record count: 1–3

The Apex controller verifies that objects and fields exist, enforces the example allowlist, checks CRUD/FLS, and uses user-mode queries and DML. The activity panels expose inbound inputs, metadata checks, save/load results, and outbound events.

### Negative checks

With a direct MCP tester, try an unknown object, an unknown field, a disallowed field, or more than three records. The widget should show a readable error instead of silently ignoring invalid configuration.

## Demo 2: Optional FSC Process Demo

The separate [FSC Process Demo package](https://github.com/jfwberg/fsc-process-demo) (namespace `wt`) adds `wt-fsc-process-demo` with three tabs:

- **KYC & Onboarding:** client information, document verification, risk assessment, and compliance decision.
- **Loan Application:** loan terms, financials, collateral, and underwriting.
- **Flow:** the packaged `KYC_Onboarding_Flow` screen flow.

### Install and configure

1. Install [MCP App Bridge 0.11.0-1](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tP3000002Ke1lIAC) and complete the [bridge setup](SETUP.md), including the integration user's permission set.
2. Install [FSC Process Demo 0.2.0-1](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000vJCPAA2).
3. Create or reuse a Lightning Out 2.0 app containing `wt/fscProcessDemo`. Set its real 18-character app ID on **MCP App Bridge Lightning Out 2.0 ? fsc_process_demo**. The extension ships enabled with placeholder `000000000000000000`; replace that value before use.
4. Confirm the configuration uses component `wt-fsc-process-demo` and resource URI `ui://wt/fsc-process-demo/v1/index.html`. Keep event mappings `fsc_kyc_completed` and `fsc_loan_decision` enabled and linked to `fsc_process_demo`.
5. Ensure the user can run the screen flow, then reconnect the MCP client. Confirm `tools/list` includes `open_fsc_process_demo`.
6. For Teams, rebuild and install the [Microsoft appPackage](../appPackage/README.md). Its pinned tool metadata does not install or configure the Salesforce extension.

### Sample prompts

> Open the FSC Process Demo on the KYC tab for Alex Morgan, client DEMO-001.

Expected tool input for `open_fsc_process_demo`:

```json
{
  "clientName": "Alex Morgan",
  "clientId": "DEMO-001",
  "initialTab": "kyc"
}
```

> Open a loan application for Alex Morgan for 250000 euros.

Use `initialTab: "loan"` and `loanAmount: 250000`. To show the screen flow, request `initialTab: "flow"`.

The package metadata exposes `clientName`, `clientId`, `startDate` (YYYY-MM-DD; defaults to today), `initialTab` (`kyc`, `loan`, or `flow`; defaults to `kyc`), and `loanAmount` (integer euros). Although the component also has date-of-birth and nationality properties, this version's bridge input schema does not expose them; enter those in the UI.

### Expected results

Complete a workflow with sample data. KYC and Flow completion emit `kyc_completed`; loan completion emits `loan_decision`. The configured bridge mappings send the results to chat for a summary and next steps. Verify the resource read, Lightning Out bootstrap, and returned event in Teams. These are demonstration compliance and underwriting outcomes.

The resource URI above is a local Teams override and must also be set in the installed Salesforce configuration; upstream metadata uses `ui://wt-fsc-process-demo/v1`.

The Teams metadata snapshot is pinned to upstream commit `0a9c0e5077aac0dcabcd4f8e10c2791c3067834a`; check the extension repository for later package releases and schema changes.
