param([switch]$AllowUnconfigured)
$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\appPackage'))
$plugin = Get-Content -LiteralPath (Join-Path $packageRoot 'ai-plugin.json') -Raw | ConvertFrom-Json
if (!$AllowUnconfigured -and $plugin.runtimes[0].auth.reference_id -like 'REPLACE_*') {
    throw 'Set MCP_OAUTH_VAULT_ID and run node scripts/build_microsoft_app_package.cjs first. Use -AllowUnconfigured only to create a template ZIP.'
}
Add-Type -AssemblyName System.Drawing
foreach ($size in @(192,32)) {
    $bitmap = New-Object Drawing.Bitmap $size,$size
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    if ($size -eq 192) { $graphics.Clear([Drawing.Color]::FromArgb(1,118,211)) }
    else { $graphics.Clear([Drawing.Color]::Transparent) }
    $pen = New-Object Drawing.Pen ([Drawing.Color]::White),($size / 16)
    $graphics.DrawRectangle($pen,($size * .25),($size * .18),($size * .5),($size * .64))
    foreach ($y in @(.36,.5,.64)) { $graphics.DrawLine($pen,($size * .36),($size * $y),($size * .64),($size * $y)) }
    $icon = if ($size -eq 192) {'color.png'} else {'outline.png'}
    $bitmap.Save((Join-Path $packageRoot $icon),[Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$files = @('manifest.json','declarativeAgent.json','ai-plugin.json','color.png','outline.png') | ForEach-Object { Join-Path $packageRoot $_ }
foreach ($file in $files | Where-Object { $_ -like '*.json' }) { $null = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json }
$zipName = if ($AllowUnconfigured -and $plugin.runtimes[0].auth.reference_id -like 'REPLACE_*') {'MCP-App-Bridge.template.zip'} else {'MCP-App-Bridge.zip'}
Compress-Archive -LiteralPath $files -DestinationPath (Join-Path $packageRoot $zipName) -Force
Write-Output "Created appPackage/$zipName"
