# This script installs a service: run only on a disposable GitHub-hosted runner.
param([Parameter(Mandatory)][string]$Installer)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Installation smoke test requires a disposable GitHub-hosted runner.'
}
$installed = Join-Path $env:ProgramFiles 'KowsarDesk\KowsarDesk.exe'
if (Test-Path -LiteralPath $installed) { throw 'Smoke test requires a clean machine.' }
try {
    Start-Process -FilePath (Resolve-Path -LiteralPath $Installer).Path -ArgumentList '--silent-install' -Wait
    $deadline = (Get-Date).AddSeconds(90)
    do {
        $service = Get-CimInstance Win32_Service -Filter "Name='KowsarDesk'"
        if ((Test-Path -LiteralPath $installed) -and $service -and $service.State -eq 'Running') { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (!(Test-Path -LiteralPath $installed)) { throw 'Installed KowsarDesk.exe is missing.' }
    if (!$service -or $service.State -ne 'Running') { throw 'KowsarDesk service did not start.' }
    if ($service.PathName -notlike "*$installed*") { throw 'Service uses an unexpected executable.' }
    $expected = (Get-FileHash -LiteralPath 'rustdesk\KowsarDesk.exe' -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash -ne $expected) {
        throw 'Installed executable differs from the packaged application.'
    }
    $versionOut = Join-Path $env:RUNNER_TEMP 'kowsardesk-version.txt'
    $process = Start-Process -FilePath $installed -ArgumentList '--version' -Wait -PassThru -RedirectStandardOutput $versionOut
    if ($process.ExitCode -ne 0 -or (Get-Content -LiteralPath $versionOut -Raw).Trim() -ne $env:VERSION) {
        throw 'Installed executable version check failed.'
    }
    Write-Host 'KowsarDesk installation, service, binary hash and version smoke checks passed.'
} finally {
    Stop-Service -Name KowsarDesk -Force -ErrorAction SilentlyContinue
}
