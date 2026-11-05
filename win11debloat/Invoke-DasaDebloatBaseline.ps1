<#
.SYNOPSIS
  DASA SMB Windows 11 baseline: runs vendored Win11Debloat with a reviewed JSON config, per user profile,
  then applies the services list. Designed to run as SYSTEM from NinjaOne (inside the DASA bundle zip).

.NOTES
  DRAFT - not yet run on a Windows endpoint. Pilot with -WhatIf first.
  Bundle layout:  upstream\ (untouched Win11Debloat release) + this script + dasa-smb-*.json
  Upstream supports SYSTEM only with -User / -Sysprep, so:
    Pass A  -Sysprep : Default profile (new users) + app removal for ALL users (config Deployment AppRemovalScopeIndex=0)
    Pass B  -User X  : tweaks only, once per existing local profile
#>
[CmdletBinding()]
param(
    [ValidateSet('Baseline','BaselinePlusOEM')][string]$Tier = 'Baseline',
    [switch]$WhatIf,            # passed through to upstream (preview only, services untouched)
    [switch]$SkipServices
)

$ErrorActionPreference = 'Stop'
$root     = $PSScriptRoot
$upstream = Join-Path $root 'upstream\Win11Debloat.ps1'
$logDir   = 'C:\ProgramData\DASA\Logs'
$tmpDir   = Join-Path $env:TEMP ('dasa-debloat-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $logDir, $tmpDir | Out-Null
Start-Transcript -Path (Join-Path $logDir 'DasaDebloatBaseline.log') -Append | Out-Null

function Invoke-Upstream([string[]]$Arguments) {
    # Upstream requires Windows PowerShell 5.1 (Appx module); always shell out to powershell.exe
    $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$upstream,'-Silent','-LogPath',$logDir) + $Arguments
    if ($WhatIf) { $a += '-WhatIf' }
    Write-Host ">> powershell.exe $($a -join ' ')"
    # Stream child output to the host only; the function's return value must be the exit code alone
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @a 2>&1 | ForEach-Object { Write-Host $_ }
    return [int]$LASTEXITCODE
}

$failures = 0
try {
    $build = [int](Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild)
    if ($build -lt 22000) { Write-Host "Windows build $build is not Windows 11 - skipping."; return }
    if (-not (Test-Path $upstream)) { throw "Missing $upstream" }

    # Merge optional OEM app list into a temp copy of the baseline (source files stay untouched)
    $base = Get-Content (Join-Path $root 'dasa-smb-baseline.json') -Raw | ConvertFrom-Json
    if ($Tier -eq 'BaselinePlusOEM') {
        $oem = Get-Content (Join-Path $root 'dasa-smb-oem-optional.json') -Raw | ConvertFrom-Json
        $base.Apps = @($base.Apps) + @($oem.Apps) | Select-Object -Unique
    }
    $fullCfg = Join-Path $tmpDir 'full.json'
    $base | ConvertTo-Json -Depth 6 | Set-Content $fullCfg -Encoding UTF8

    # Tweaks-only copy for per-user passes (no repeated app removal)
    $tweakCfg = Join-Path $tmpDir 'tweaks.json'
    $t = $base | Select-Object Version, Tweaks
    $t | ConvertTo-Json -Depth 6 | Set-Content $tweakCfg -Encoding UTF8

    # Pass A: Default profile + app removal for all users
    $rc = Invoke-Upstream @('-Config', $fullCfg, '-Sysprep', '-AppRemovalTarget', 'AllUsers')
    if ($rc -ne 0) { $failures++; Write-Warning "Pass A exit code $rc" }

    # Pass B: each existing local profile (skip system/service profiles)
    $profiles = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' |
        ForEach-Object { Get-ItemProperty $_.PSPath } |
        Where-Object { $_.ProfileImagePath -like 'C:\Users\*' -and ($_.PSChildName -like 'S-1-5-21-*' -or $_.PSChildName -like 'S-1-12-1-*') } |
        ForEach-Object { Split-Path $_.ProfileImagePath -Leaf } | Sort-Object -Unique
    foreach ($u in $profiles) {
        $rc = Invoke-Upstream @('-Config', $tweakCfg, '-User', $u)
        if ($rc -ne 0) { $failures++; Write-Warning "User '$u' exit code $rc" }
    }

    # Services
    if (-not $SkipServices -and $WhatIf) {
        $svc = Get-Content (Join-Path $root 'dasa-smb-services.json') -Raw | ConvertFrom-Json
        foreach ($s in $svc.Services) {
            $cur = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if ($cur) { Write-Host "[WhatIf] Service $($s.Name): $($cur.StartType) -> $($s.StartupType)" } else { Write-Host "[WhatIf] Service $($s.Name) not present - skip" }
        }
    }
    if (-not $SkipServices -and -not $WhatIf) {
        $svc = Get-Content (Join-Path $root 'dasa-smb-services.json') -Raw | ConvertFrom-Json
        foreach ($s in $svc.Services) {
            if (-not (Get-Service -Name $s.Name -ErrorAction SilentlyContinue)) { Write-Host "Service $($s.Name) not present - skip"; continue }
            try { Set-Service -Name $s.Name -StartupType $s.StartupType -ErrorAction Stop; Write-Host "Service $($s.Name) -> $($s.StartupType)" }
            catch { $failures++; Write-Warning "Service $($s.Name): $($_.Exception.Message)" }
        }
    }

    # Marker for NinjaOne custom field / compliance condition
    if (-not $WhatIf) {
        $k = 'HKLM:\SOFTWARE\DASA\Baseline'
        New-Item -Path $k -Force | Out-Null
        $ver = (Get-Content (Join-Path $root 'VERSION.txt') -ErrorAction SilentlyContinue) -join ''
        Set-ItemProperty $k -Name Win11DebloatBaseline -Value "$ver|$Tier|$((Get-Date).ToString('s'))|failures=$failures"
    }
}
catch { $failures++; Write-Error $_ }
finally {
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Transcript | Out-Null
}
exit ([int]($failures -gt 0))
