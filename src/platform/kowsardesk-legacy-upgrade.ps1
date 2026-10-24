# Invoked by the elevated installer, before starting the replacement service.
param(
    [string]$InstallDirectory = (Join-Path $env:ProgramFiles 'KowsarDesk'),
    [string]$LegacyCacheDirectory = (Join-Path $env:LOCALAPPDATA 'rustdesk')
)
$ErrorActionPreference = 'Stop'
try {
    $legacyPaths = @(
        [IO.Path]::GetFullPath((Join-Path $LegacyCacheDirectory 'rustdesk.exe')),
        [IO.Path]::GetFullPath((Join-Path $InstallDirectory 'rustdesk.exe'))
    )
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='rustdesk.exe'")) {
        if (!$process.ExecutablePath) { continue }
        $legacy = [IO.Path]::GetFullPath($process.ExecutablePath)
        if ($legacyPaths -inotcontains $legacy) { continue }
        # Stock RustDesk and unrelated executables must remain untouched.
        if ((Get-Item -LiteralPath $legacy).VersionInfo.ProductName -ne 'KowsarDesk') { continue }
        $result = Invoke-CimMethod -InputObject $process -MethodName Terminate -Arguments @{ Reason = [uint32]0 }
        if ($result.ReturnValue -ne 0) { throw 'Unable to stop the legacy KowsarDesk portable process.' }
        $deadline = (Get-Date).AddSeconds(20)
        while (Get-CimInstance Win32_Process -Filter "ProcessId=$($process.ProcessId)") {
            if ((Get-Date) -ge $deadline) { throw 'Legacy KowsarDesk did not stop; installation aborted.' }
            Start-Sleep -Milliseconds 200
        }
    }
} catch {
    Write-Error $_
    exit 1
}
