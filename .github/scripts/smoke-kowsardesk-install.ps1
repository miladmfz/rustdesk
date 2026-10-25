# This script installs a service: run only on a disposable GitHub-hosted runner.
param([Parameter(Mandatory)][string]$Installer)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Installation smoke test requires a disposable GitHub-hosted runner.'
}
$installed = Join-Path $env:ProgramFiles 'KowsarDesk\KowsarDesk.exe'
if (Test-Path -LiteralPath $installed) { throw 'Smoke test requires a clean machine.' }
$legacyRoot = Join-Path $env:LOCALAPPDATA 'rustdesk'
if (Test-Path -LiteralPath $legacyRoot) { throw 'Smoke test requires an unused legacy cache.' }
$legacyProcess = $null
try {
    # Prove the new build replaces an already saved permanent password.
    $configDir = Join-Path $env:APPDATA 'KowsarDesk\config'
    $configFile = Join-Path $configDir 'KowsarDesk.toml'
    if (Test-Path -LiteralPath $configFile) { throw 'Password smoke requires a clean user profile.' }
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    @('password = "previous-fixture-password"', 'salt = "previous-fixture-salt"') | Set-Content -LiteralPath $configFile -Encoding utf8
    # Reproduce the old package: rustdesk.exe keeps a native DLL locked in the
    # shared cache. A leftover file must never be copied into the new installation.
    Copy-Item -LiteralPath 'rustdesk' -Destination $legacyRoot -Recurse
    Rename-Item -LiteralPath (Join-Path $legacyRoot 'KowsarDesk.exe') -NewName 'rustdesk.exe'
    Set-Content -LiteralPath (Join-Path $legacyRoot 'legacy-only.txt') -Value 'legacy cache sentinel'
    $legacyDll = (Get-FileHash -LiteralPath (Join-Path $legacyRoot 'librustdesk.dll')).Hash
    $legacyProcess = Start-Process -FilePath (Join-Path $legacyRoot 'rustdesk.exe') -WorkingDirectory $legacyRoot -ArgumentList '--tray' -PassThru
    Start-Sleep -Seconds 5
    if ($legacyProcess.HasExited) { throw 'Legacy process fixture did not remain alive.' }
    python3 .github/scripts/check-kowsardesk-preset.py --config $configFile
    if ($LASTEXITCODE -ne 0) { throw 'Runtime preset override verification failed.' }
    Write-Host 'Previous local password override retired; compiled hashed preset is effective.'
    $locked = $false
    try {
        $handle = [IO.File]::Open((Join-Path $legacyRoot 'librustdesk.dll'), 'Open', 'ReadWrite', 'None')
        $handle.Dispose()
    } catch [IO.IOException] { $locked = $true }
    if (!$locked) { throw 'Legacy fixture did not lock its native DLL.' }
    Write-Host 'Legacy portable process is running with its native DLL locked.'
    # Start-Process -Wait waits for descendants too, including the persistent tray.
    # Poll the actual installation result instead of waiting for that process tree.
    Start-Process -FilePath (Resolve-Path -LiteralPath $Installer).Path -ArgumentList '--silent-install'
    Write-Host 'Portable launcher started; waiting for the installed executable and running service.'
    $deadline = (Get-Date).AddSeconds(90)
    do {
        $service = Get-CimInstance Win32_Service -Filter "Name='KowsarDesk'"
        if ((Test-Path -LiteralPath $installed) -and $service -and $service.State -eq 'Running') { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (!(Test-Path -LiteralPath $installed)) { throw 'Installed KowsarDesk.exe is missing.' }
    if (!$service -or $service.State -ne 'Running') { throw 'KowsarDesk service did not start.' }
    if (!$legacyProcess.WaitForExit(20000)) { throw 'Installer did not retire the legacy portable process.' }
    if ((Get-FileHash -LiteralPath (Join-Path $legacyRoot 'librustdesk.dll')).Hash -ne $legacyDll) {
        throw 'Installer modified the legacy cache instead of isolating its payload.'
    }
    if (Test-Path -LiteralPath (Join-Path (Split-Path $installed) 'legacy-only.txt')) {
        throw 'Legacy cache contents leaked into the new installation.'
    }
    Write-Host 'Installed executable exists and KowsarDesk service is running.'
    if ($service.PathName -notlike "*$installed*") { throw 'Service uses an unexpected executable.' }
    $expected = (Get-FileHash -LiteralPath 'rustdesk\KowsarDesk.exe' -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash -ne $expected) {
        throw 'Installed executable differs from the packaged application.'
    }
    $staged = (Resolve-Path -LiteralPath 'rustdesk').Path
    foreach ($file in (Get-ChildItem -LiteralPath $staged -Recurse -File)) {
        $relative = $file.FullName.Substring($staged.Length + 1)
        $target = Join-Path (Split-Path $installed) $relative
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
            throw "Installed payload differs: $relative"
        }
    }
    $versionOut = Join-Path $env:RUNNER_TEMP 'kowsardesk-version.txt'
    $process = Start-Process -FilePath $installed -ArgumentList '--version' -PassThru -RedirectStandardOutput $versionOut
    if (!$process.WaitForExit(30000)) { throw 'Installed executable version check timed out.' }
    if ($process.ExitCode -ne 0 -or (Get-Content -LiteralPath $versionOut -Raw).Trim() -ne $env:VERSION) {
        throw 'Installed executable version check failed.'
    }
    $gui = Start-Process -FilePath $installed -WorkingDirectory (Split-Path $installed) -PassThru
    if ($gui.WaitForExit(30000)) { throw "Installed GUI exited early: $($gui.ExitCode)" }
    $gui.Refresh()
    if (!$gui.MainWindowHandle -or $gui.MainWindowTitle -ne 'KowsarDesk') { throw 'Installed GUI did not create its main window.' }
    Write-Host 'Legacy upgrade, complete payload hashes, service, version and 30-second GUI smoke checks passed.'
} finally {
    Stop-Service -Name KowsarDesk -Force -ErrorAction SilentlyContinue
    Get-Process -Name KowsarDesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if ($legacyProcess -and !$legacyProcess.HasExited) { Stop-Process -Id $legacyProcess.Id -Force -ErrorAction SilentlyContinue }
}
