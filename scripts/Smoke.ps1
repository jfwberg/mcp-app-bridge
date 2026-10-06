param([string]$TargetOrg = 'mcpappbridge')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

# org display includes credentials. Capture its output without printing it.
$savedPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $orgJson = & sf org display --target-org $TargetOrg --json 2>$null
    $orgExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $savedPreference
}
if ($orgExitCode -ne 0) { throw "Cannot access '$TargetOrg'. Authenticate the intended namespaced scratch org first." }

$org = ($orgJson | ConvertFrom-Json).result
$baseUrl = $org.instanceUrl.TrimEnd('/')
$endpoint = "$baseUrl/services/apexrest/mcpapp/mcp"
$client = [System.Net.Http.HttpClient]::new()
$legacySessionId = $null
$legacyProtocolVersion = '2025-11-25'
$requestUserAgent = $null

function Send-Rpc {
    param(
        [string]$Method,
        [hashtable]$Values = @{},
        [ValidateSet('Legacy', 'Modern')][string]$Protocol = 'Legacy',
        [switch]$Notification
    )
    $params = @{} + $Values
    if ($Protocol -eq 'Modern') {
        $params['_meta'] = @{
            'io.modelcontextprotocol/protocolVersion' = '2026-07-28'
            'io.modelcontextprotocol/clientInfo' = @{ name = 'MCP-App-Bridge-Smoke'; version = '1.0.0' }
            'io.modelcontextprotocol/clientCapabilities' = @{}
        }
    }
    $rpc = @{ jsonrpc = '2.0'; method = $Method; params = $params }
    if (-not $Notification) { $rpc.id = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
    $message = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $endpoint)
    try {
        $message.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $org.accessToken)
        $message.Headers.Add('Accept', 'application/json, text/event-stream')
        if ($requestUserAgent) { $message.Headers.Add('User-Agent', $requestUserAgent) }
        if ($Protocol -eq 'Modern') {
            $message.Headers.Add('MCP-Protocol-Version', '2026-07-28')
            $message.Headers.Add('Mcp-Method', $Method)
            if ($Method -eq 'tools/call') { $message.Headers.Add('Mcp-Name', [string]$Values.name) }
            if ($Method -eq 'resources/read') { $message.Headers.Add('Mcp-Name', [string]$Values.uri) }
        } elseif ($Method -ne 'initialize') {
            $message.Headers.Add('MCP-Protocol-Version', $legacyProtocolVersion)
            if ($legacySessionId) { $message.Headers.Add('MCP-Session-Id', $legacySessionId) }
        }
        $message.Content = [System.Net.Http.StringContent]::new(
            ($rpc | ConvertTo-Json -Depth 20 -Compress),
            [System.Text.Encoding]::UTF8,
            'application/json'
        )
        $response = $client.SendAsync($message).GetAwaiter().GetResult()
        try {
            if ($response.Headers.Contains('MCP-Session-Id')) {
                $script:legacySessionId = ($response.Headers.GetValues('MCP-Session-Id') | Select-Object -First 1)
            }
            $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if ($text -and $response.Content.Headers.ContentType.MediaType -eq 'text/event-stream') {
                $dataLine = ($text -split "`r?`n" | Where-Object { $_ -like 'data: *' } | Select-Object -First 1)
                $text = if ($dataLine) { $dataLine.Substring(6) } else { $null }
            }
            return @{
                Status = [int]$response.StatusCode
                Body = if ($text) { $text | ConvertFrom-Json } else { $null }
            }
        } finally {
            $response.Dispose()
        }
    } finally {
        $message.Dispose()
    }
}

function Assert-RpcSuccess($Reply, [string]$Label) {
    if ($Reply.Status -ne 200 -or $null -eq $Reply.Body.result -or $null -ne $Reply.Body.error) {
        throw "$Label failed (HTTP $($Reply.Status))."
    }
    Write-Host "PASS $Label"
}

function Test-LegacyVersion([string]$ProtocolVersion) {
    $script:requestUserAgent = $null
    $script:legacyProtocolVersion = $ProtocolVersion
    $script:legacySessionId = $null
    $initialize = Send-Rpc 'initialize' @{
        protocolVersion = $ProtocolVersion
        capabilities = @{}
        clientInfo = @{ name = 'MCP-App-Bridge-Smoke'; version = '1.0.0' }
    }
    Assert-RpcSuccess $initialize "$ProtocolVersion initialize"
    if ($initialize.Body.result.protocolVersion -ne $ProtocolVersion -or $legacySessionId) {
        throw "$ProtocolVersion initialization did not negotiate the expected stateless handshake."
    }
    $ready = Send-Rpc 'notifications/initialized' @{} Legacy -Notification
    if ($ready.Status -ne 202 -or $null -ne $ready.Body) {
        throw "$ProtocolVersion initialized notification must return empty HTTP 202."
    }
    Write-Host "PASS $ProtocolVersion notifications/initialized"
    Assert-RpcSuccess (Send-Rpc 'tools/list') "$ProtocolVersion tools/list"
}

function Test-OpenAiLegacyVersion {
    $script:legacyProtocolVersion = '2025-11-25'
    $script:legacySessionId = $null
    $script:requestUserAgent = 'openai-mcp/1.0.0'
    $initialize = Send-Rpc 'initialize' @{
        protocolVersion = $legacyProtocolVersion
        capabilities = @{}
        clientInfo = @{ name = 'openai-mcp'; version = '1.0.0' }
    }
    Assert-RpcSuccess $initialize 'OpenAI stateful SSE initialize'
    if (-not $legacySessionId) { throw 'OpenAI-shaped initialize did not return MCP-Session-Id.' }
    $ready = Send-Rpc 'notifications/initialized' @{} Legacy -Notification
    if ($ready.Status -ne 202 -or $null -ne $ready.Body) { throw 'OpenAI initialized notification must return empty HTTP 202.' }
    Assert-RpcSuccess (Send-Rpc 'tools/list') 'OpenAI stateful SSE tools/list'
    $script:requestUserAgent = $null
}

try {
    Test-LegacyVersion '2024-11-05'
    Test-LegacyVersion '2025-06-18'
    Test-LegacyVersion '2025-11-25'
    Test-OpenAiLegacyVersion

    $modernDiscover = Send-Rpc 'server/discover' @{} Modern
    Assert-RpcSuccess $modernDiscover 'modern server/discover'
    if ($modernDiscover.Body.result.supportedVersions -notcontains '2026-07-28') {
        throw 'Modern discovery did not advertise 2026-07-28.'
    }
    $modernTools = Send-Rpc 'tools/list' @{} Modern
    Assert-RpcSuccess $modernTools 'modern tools/list'
    if ($modernTools.Body.result.resultType -ne 'complete') {
        throw 'Modern tools/list did not return the required result type.'
    }
    $script:requestUserAgent = 'openai-mcp/1.0.0'
    $openAiModernDiscover = Send-Rpc 'server/discover' @{} Modern
    Assert-RpcSuccess $openAiModernDiscover 'OpenAI modern SSE server/discover'
    $openAiModernTools = Send-Rpc 'tools/list' @{} Modern
    Assert-RpcSuccess $openAiModernTools 'OpenAI modern SSE tools/list'
    $script:requestUserAgent = $null

    $metadataRequest = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::Get,
        "$endpoint/.well-known/oauth-protected-resource"
    )
    $metadataRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $org.accessToken)
    $metadataResponse = $client.SendAsync($metadataRequest).GetAwaiter().GetResult()
    try {
        if ([int]$metadataResponse.StatusCode -ne 200) {
            throw 'Protected-resource metadata endpoint failed.'
        }
        Write-Host 'PASS protected-resource metadata'
    } finally {
        $metadataResponse.Dispose()
        $metadataRequest.Dispose()
    }
} finally {
    $client.Dispose()
    $org = $null
    $orgJson = $null
}
