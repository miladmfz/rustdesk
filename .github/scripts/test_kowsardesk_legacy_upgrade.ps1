$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '../../src/platform/kowsardesk-legacy-upgrade.ps1'
$originalLocalAppData = $env:LOCALAPPDATA
$env:LOCALAPPDATA = Join-Path ([IO.Path]::GetTempPath()) 'kowsardesk-policy-fixture'
$global:kowsarTestTerminated = @()
$global:kowsarTestFixtures = @()
$global:kowsarTestProduct = 'KowsarDesk'
function Get-CimInstance {
    param($ClassName, $Filter)
    if ($Filter -like 'ProcessId=*') { return }
    return $global:kowsarTestFixtures
}
function Get-Item {
    param($LiteralPath)
    return [pscustomobject]@{ VersionInfo = [pscustomobject]@{ ProductName = $global:kowsarTestProduct } }
}
function Invoke-CimMethod {
    param($InputObject, $MethodName, $Arguments)
    $global:kowsarTestTerminated += $InputObject.ProcessId
    return [pscustomobject]@{ ReturnValue = 0 }
}
try {
    $legacy = Join-Path $env:LOCALAPPDATA 'rustdesk\rustdesk.exe'
    $global:kowsarTestFixtures = @(
        [pscustomobject]@{ ProcessId = 101; ExecutablePath = $legacy },
        [pscustomobject]@{ ProcessId = 102; ExecutablePath = 'C:\Program Files\RustDesk\rustdesk.exe' },
        [pscustomobject]@{ ProcessId = 103; ExecutablePath = $null }
    )
    & $script
    if ($global:kowsarTestTerminated.Count -ne 1 -or $global:kowsarTestTerminated[0] -ne 101) { throw 'Legacy path allowlist failed' }
    $global:kowsarTestTerminated = @()
    $global:kowsarTestFixtures = @([pscustomobject]@{ ProcessId = 104; ExecutablePath = 'D:\Custom KowsarDesk\rustdesk.exe' })
    & $script -InstallDirectory 'D:\Custom KowsarDesk'
    if ($global:kowsarTestTerminated.Count -ne 1 -or $global:kowsarTestTerminated[0] -ne 104) { throw 'Custom installation path migration failed' }
    $global:kowsarTestTerminated = @()
    $global:kowsarTestProduct = 'RustDesk'
    & $script -InstallDirectory 'D:\Custom KowsarDesk'
    if ($global:kowsarTestTerminated.Count -ne 0) { throw 'Stock RustDesk must remain running' }
    Write-Output '3 passed: legacy cache and custom installation migrated; unrelated and stock RustDesk preserved.'
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
}

