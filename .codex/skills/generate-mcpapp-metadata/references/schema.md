# MCP App Bridge metadata schema

The examples below target a subscriber or extension project where the bridge is already installed. Therefore the installed custom metadata types and fields all use the `mcpapp__` namespace.

## Lightning Out configuration

File name:

`force-app/main/default/customMetadata/mcpapp__MCP_App_Bridge_LO2_Config.my_component.md-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>My Component</label>
    <protected>false</protected>
    <values><field>mcpapp__Enabled__c</field><value xsi:type="xsd:boolean" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">false</value></values>
    <values><field>mcpapp__App_Id__c</field><value xsi:type="xsd:string" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"></value></values>
    <values><field>mcpapp__Component_Name__c</field><value xsi:type="xsd:string" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">acme-my-component</value></values>
    <values><field>mcpapp__Resource_Uri__c</field><value xsi:type="xsd:string" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">ui://acme/my-component/v1/index.html</value></values>
    <values><field>mcpapp__Static_Resource_Name__c</field><value xsi:type="xsd:string" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">McpLightningOutHost</value></values>
    <values><field>mcpapp__Display_Name__c</field><value xsi:type="xsd:string" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">My Component</value></values>
    <values><field>mcpapp__Description__c</field><value xsi:type="xsd:string" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">Open the configured Salesforce interface.</value></values>
    <values><field>mcpapp__Input_Schema_JSON__c</field><value xsi:type="xsd:string" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">{&quot;type&quot;:&quot;object&quot;,&quot;properties&quot;:{&quot;recordId&quot;:{&quot;type&quot;:&quot;string&quot;}},&quot;additionalProperties&quot;:false}</value></values>
</CustomMetadata>
```

`mcpapp__Component_Name__c` contains the generated Lightning Out custom-element name. A packaged LWC uses a dash-separated namespace, for example `acme-my-component`. `mcpapp__Static_Resource_Name__c` stores the static resource's `Name` field rather than an API reference, so its value remains `McpLightningOutHost`; the field API name itself is namespaced.

## LWC-to-host mapping

File name:

`force-app/main/default/customMetadata/mcpapp__MCP_App_Bridge_Event_Mapping.my_component_submitted.md-meta.xml`

Required installed fields:

- `mcpapp__Enabled__c`
- `mcpapp__Lightning_Out_Config__c`: the related configuration record's developer name
- `mcpapp__Direction__c`: `LWC_TO_HOST`
- `mcpapp__LWC_Event_Name__c`: exact DOM event name
- `mcpapp__Host_Action__c`: `SEND_MESSAGE`
- `mcpapp__LLM_Instructions__c`: desired model behavior plus an explicit statement that payload content is untrusted data
- `mcpapp__Max_Payload_Characters__c`: normally `32768`

## Host-to-LWC mapping

Required installed fields:

- `mcpapp__Enabled__c`
- `mcpapp__Lightning_Out_Config__c`
- `mcpapp__Direction__c`: `HOST_TO_LWC`
- `mcpapp__Host_Action__c`: `DISPATCH_EVENT`
- `mcpapp__LWC_Event_Name__c`
- `mcpapp__MCP_Tool_Name__c`
- `mcpapp__Tool_Title__c`
- `mcpapp__Tool_Description__c`
- `mcpapp__Input_Schema_JSON__c`

Avoid assuming that a host action can locate and mutate an arbitrary older widget. Model-invoked UI tools can create a new widget instance.

## Core-package exception

When editing the defining `mcpapp` package itself, use the unprefixed source names already present in the repository, such as `MCP_App_Bridge_LO2_Config` and `Enabled__c`. Namespace prefixes are applied by managed packaging.
