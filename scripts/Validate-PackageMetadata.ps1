$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$metadataRoot = Join-Path $projectRoot 'force-app\main\default'

# Sample records must remain visible and editable after managed-package install.
$records = Get-ChildItem -LiteralPath (Join-Path $metadataRoot 'customMetadata') -Filter '*.md-meta.xml'
foreach ($record in $records) {
    [xml]$xml = Get-Content -Raw -LiteralPath $record.FullName
    $protected = $xml.SelectSingleNode('/*[local-name()="CustomMetadata"]/*[local-name()="protected"]')
    if ($null -eq $protected -or $protected.InnerText -ne 'false') {
        throw "Package sample metadata must be public: $($record.Name) must contain <protected>false</protected>."
    }
}

# Public types and subscriber-controlled fields let extension packages and
# subscriber administrators inspect and configure the bridge records.
$typeNames = @(
    'MCP_App_Bridge_Core_Config__mdt',
    'MCP_App_Bridge_LO2_Config__mdt',
    'MCP_App_Bridge_Event_Mapping__mdt'
)
foreach ($typeName in $typeNames) {
    $typeFile = Join-Path $metadataRoot "objects\$typeName\$typeName.object-meta.xml"
    [xml]$xml = Get-Content -Raw -LiteralPath $typeFile
    $visibility = $xml.SelectSingleNode('/*[local-name()="CustomObject"]/*[local-name()="visibility"]')
    if ($null -eq $visibility -or $visibility.InnerText -ne 'Public') {
        throw "Bridge metadata type must remain Public: $typeName."
    }
}

$appIdField = Join-Path $metadataRoot 'objects\MCP_App_Bridge_LO2_Config__mdt\fields\App_Id__c.field-meta.xml'
[xml]$appIdXml = Get-Content -Raw -LiteralPath $appIdField
$manageability = $appIdXml.SelectSingleNode('/*[local-name()="CustomField"]/*[local-name()="fieldManageability"]')
if ($null -eq $manageability -or $manageability.InnerText -ne 'SubscriberControlled') {
    throw 'Lightning Out App ID must remain SubscriberControlled so each subscriber can configure its org-specific app ID.'
}

function Get-CustomMetadataValue([xml]$Xml, [string]$FieldName) {
    $node = $Xml.SelectSingleNode("/*[local-name()='CustomMetadata']/*[local-name()='values'][*[local-name()='field' and text()='$FieldName']]/*[local-name()='value']")
    if ($null -eq $node) { return $null }
    return $node.InnerText
}

$coreRecord = Join-Path $metadataRoot 'customMetadata\MCP_App_Bridge_Core_Config.Default.md-meta.xml'
[xml]$coreXml = Get-Content -Raw -LiteralPath $coreRecord
if ((Get-CustomMetadataValue $coreXml 'Enabled__c') -ne 'false') {
    throw 'The packaged Default core configuration must remain disabled.'
}
if ((Get-CustomMetadataValue $coreXml 'Logging_Enabled__c') -ne 'false') {
    throw 'The packaged logging switch must remain disabled.'
}
foreach ($fieldName in @('ECA_Consumer_Key__c', 'ECA_Certificate_Name__c', 'Allowed_Origins__c')) {
    if (-not [string]::IsNullOrWhiteSpace((Get-CustomMetadataValue $coreXml $fieldName))) {
        throw "The packaged Default core configuration must not contain $fieldName."
    }
}

$demoRecords = Get-ChildItem -LiteralPath (Join-Path $metadataRoot 'customMetadata') -Filter 'MCP_App_Bridge_LO2_Config.*.md-meta.xml'
foreach ($record in $demoRecords) {
    [xml]$xml = Get-Content -Raw -LiteralPath $record.FullName
    if ((Get-CustomMetadataValue $xml 'Enabled__c') -ne 'false') {
        throw "Packaged Lightning Out sample must remain disabled: $($record.Name)."
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-CustomMetadataValue $xml 'App_Id__c'))) {
        throw "Packaged Lightning Out sample must not contain an org-specific app ID: $($record.Name)."
    }
}

$eventRecords = Get-ChildItem -LiteralPath (Join-Path $metadataRoot 'customMetadata') -Filter 'MCP_App_Bridge_Event_Mapping.*.md-meta.xml'
foreach ($record in $eventRecords) {
    [xml]$xml = Get-Content -Raw -LiteralPath $record.FullName
    if ((Get-CustomMetadataValue $xml 'Enabled__c') -ne 'true') {
        throw "Packaged event-mapping sample must remain enabled: $($record.Name)."
    }
}

Write-Host "PASS package metadata is subscriber-configurable ($($records.Count) public sample records)."
