# Paste into NinjaOne as the script body (Run As: System, Windows PowerShell 5.1).
# Script variables: $env:tier (Baseline|BaselinePlusOEM), $env:whatif (true|false)
$ErrorActionPreference = 'Stop'
$Url    = 'https://github.com/DasaITS/endpoint-baseline/releases/download/2026.10.30-dasa2/DASA-Win11Debloat-2026.10.30-dasa2.zip'
$Sha256 = '51d37917ff3c0c6d32cb1ca8e68240de7c77e5dcf2372c2b75e93e6ca5bae3e0'
$dest   = 'C:\ProgramData\DASA\Win11Debloat'
$zip    = Join-Path $env:TEMP 'dasa-debloat.zip'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing
if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $Sha256) { Remove-Item $zip -Force; throw 'Bundle hash mismatch - refusing to run.' }
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive $zip -DestinationPath $dest -Force
Remove-Item $zip -Force
$p = @{ Tier = $(if ($env:tier) { $env:tier } else { 'Baseline' }) }
if ($env:whatif -eq 'true') { $p.WhatIf = $true }
& (Join-Path $dest 'Invoke-DasaDebloatBaseline.ps1') @p
exit $LASTEXITCODE
