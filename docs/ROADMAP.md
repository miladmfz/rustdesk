# KowsarDesk packaging checkpoint — 2026-10-24

This fork had no docs/ROADMAP.md when inspected. Base: adfb9df.

Active work: repair Windows portable installation and rebuild the existing
KowsarDesk Windows/Android workflow. No upstream version migration is included.

The installer copies the extracted folder and registers KowsarDesk.exe as the
service and shortcut executable. The old workflow bundled rustdesk.exe, leaving
that registered path missing. Rename the staged executable before packing and
use KowsarDesk.exe as the packed entry point. Network settings remain as defined
by this fork.

Outputs after successful CI:

- KowsarDesk-windows-x64-portable: executable for use without installation;
  installation remains available from the app.
- KowsarDesk-windows-x64-installer: the same payload with an -install.exe filename,
  opening the existing installation UI on double-click.
- KowsarDesk-windows-x64-folder: complete extracted application folder.
- KowsarDesk-windows-x64-checksums: SHA256 for both executable downloads.
- Existing KowsarDesk-android-arm64 output.

Windows outputs are uploaded only after installation on a disposable hosted
runner verifies the installed file, running service, binary hash and version.
Windows artifacts are retained for 30 days; download and extract the artifact ZIP
before use. Keep all files together for the folder variant.

Verified locally: 5 packaging regression tests passed, zero failures. Workflow
YAML, 20 shell script blocks, embedded Python and the PowerShell smoke script
parsed successfully; git diff --check passed.

CI blocker: GitHub returned HTTP 422, `Actions has been disabled for this
repository`, when dispatching this branch. Repository permissions already report
enabled=true and the workflow reports active. Re-enabling the workflow and
reapplying the existing repository Actions permissions did not resolve it.
No new Windows/Android binary was produced; installation smoke is unexecuted.
The existing 1.4.9 application version and upstream baseline remain unchanged.

Next: resolve the GitHub Actions execution restriction, run this branch's
KowsarDesk workflow and obtain successful Windows build and installation smoke
evidence, then verify installation interactively on the affected user's Windows
machine. Compilation alone does not close this task.

## Actions diagnosis follow-up — 2026-10-24

Authenticated REST confirms administrator access, repository archived=false and
disabled=false, Actions enabled=true, and the KowsarDesk workflow active. Dispatch
still returns HTTP 422 before creating a run.

The public repository Actions page gives more specific evidence: workflows are
not being run on this fork due to the scale of GitHub Actions usage, and a
repository maintainer can choose to re-enable them. The ordinary Actions
permissions and per-workflow enable endpoints do not clear this fork state.

Separately, Flutter Nightly Build is disabled_inactivity. Its September 15 GitHub
notification states that scheduled workflows stop after 60 days of repository
inactivity. This is distinct from the fork-wide execution pause. Leave Nightly
disabled; the requested KowsarDesk workflow is manual-only.

Browser inspection was signed out. The user has been asked to sign in as
miladmfz at https://github.com/miladmfz/rustdesk/actions so the maintainer-only
re-enable control can be inspected. No sign-in credentials are requested in chat.
Next: use that control if available, dispatch codex/kowsardesk-portable-fix, and
verify build, installation smoke and downloadable artifacts. If GitHub instead
requires Support review, capture the exact signed-in message before escalating.

## Verified release checkpoint — 2026-10-24

The maintainer signed in and restored the fork-specific Actions execution state.
No Support request was needed. Flutter Nightly Build remains disabled.

Successful complete workflow:
https://github.com/miladmfz/rustdesk/actions/runs/40069595938
Built source commit: cff4d708dee86d0a4338b258dea695ca08db6617.
Both Windows x64 and Android arm64-v8a jobs completed successfully.

The first attempt, run 40066006305, compiled both platforms but its initial
installation smoke step timed out after five minutes: Start-Process -Wait also
waited for the persistent tray descendant. The corrected smoke script starts the
portable installer asynchronously, polls for the installed file and running
service for at most 90 seconds, and bounds the version process to 30 seconds.
It stops the service and tray on the disposable hosted runner afterward.

Verified evidence:

- Five packaging regression tests passed; the renamed binary and dependencies
  are validated before packing.
- One real local launcher/tray process validation passed. A separate bounded
  version-process check passed for exit code and redirected stdout.
- Workflow YAML, 20 shell script blocks, embedded Python and PowerShell syntax
  checks passed; git diff --check passed.
- Hosted Windows smoke passed: installed KowsarDesk.exe exists, its service runs
  from the expected path, its SHA256 matches the staged binary, and --version
  returns 1.4.9. Windows artifact uploads passed after this check.
- Android APK build and embedded custom-configuration verification passed.
- All five release ZIPs were downloaded. Their SHA256 values match GitHub artifact
  metadata and ZIP integrity checks passed. Both Windows executable hashes match
  the published checksum file, and both PE headers identify Windows x64.

Local deliverables are in Downloads/KowsarDesk-1.4.9-verified-20261024, including
the installer, portable, full folder, Android APK, checksums and verification.json.
The application version remains 1.4.9; this release repairs packaging and CI.

Changed project files:

- .github/workflows/kowsardesk-build.yml
- .github/scripts/prepare-kowsardesk.py
- .github/scripts/test_kowsardesk_packaging.py
- .github/scripts/smoke-kowsardesk-install.ps1
- docs/ROADMAP.md

No technical verification blocker remains. Human acceptance on the affected
user's machine has not been inferred from CI. Next: install the verified Windows
package on that target machine and confirm its interactive support workflow.

## 2026-10-24: Target-machine portable upgrade diagnosis

The affected machine reproduced the immediate GUI exit. The installed executable
matched the new release, but librustdesk.dll in both Program Files/KowsarDesk and
LocalAppData/rustdesk differed from the verified folder artifact. A legacy
rustdesk.exe process remained in the shared portable cache; GUI logs reported
Access denied on the KowsarDesk query IPC endpoint and exited with code -1.

Local repair preserved the user's configuration and backed up the installation.
After replacing and validating all 104 payload files, an elevated termination of
the legacy cached process and service restart allowed the GUI to stay open.
The actual portable installer was then rerun with --silent-install. This updated
the registry BuildDate from the old July build to the October release. The
portable GUI passed a 30-second stability check. A subsequent launch from
Program Files also remained open for 30 seconds and its accessibility state
reported Ready, without the obsolete-installation warning. The service remained
Running. Both core connection configuration files retained their original hashes.

No application source or release binary changed during this local repair.
Installation smoke evidence alone does not cover upgrades with a legacy
rustdesk.exe holding the shared extraction directory. Next: add an upgrade
regression covering occupied legacy caches and prevent mixed payload extraction;
also verify an authorized real remote session. Remote-session acceptance has not
been inferred from GUI readiness.

## 2026-10-24: Portable legacy-upgrade fix verified

Portable payloads now extract under LocalAppData/KowsarDesk/portable/<payload-id>,
independent of the old shared rustdesk directory and of other release payloads.
Extraction propagates decompression, checksum and filesystem errors rather than
launching a mixture of old and new files. Existing matching files are reused
without deleting a directory another running copy may use.

The elevated installer retires rustdesk.exe only at the exact legacy cache or
selected installation path and only when its ProductName is KowsarDesk. Failure
to stop that process aborts installation before uninstalling the existing service.
Stock RustDesk and unrelated paths are excluded. Configuration is preserved.

CI now tests the extraction code and simulates an actual running, DLL-locking
legacy portable before installation. Uploads require legacy-process retirement,
complete installed-payload hash checks, service/version checks and a 30-second
installed GUI check. Build and artifact verification results are recorded below.
Application version and server settings are unchanged.

Verification completed in workflow run 40089911358, source commit
35626d8d5bc66e94481c33587e41a9acd41deadc. Both Windows x64 and Android arm64 jobs
succeeded. Fifteen local regression cases passed: six extraction/cache cases,
four legacy-process policy cases and five packaging cases. The policy cases cover
an original caller cache passed across elevation, a custom installation path and
exclusion of stock RustDesk/unrelated paths. The installer sets UTF-8 before
invoking the migration helper. The same tests also passed in the hosted build.

The hosted Windows smoke confirmed a real legacy-layout rustdesk.exe remained
alive with librustdesk.dll locked before installation. The installer retired it
without manual termination, preserved the legacy DLL hash and excluded its
sentinel file from the installation. Every staged application file matched its
installed SHA256. The service used the expected path and ran successfully,
--version returned 1.4.9, and the installed GUI remained open for 30 seconds.

All five release ZIPs were downloaded into
Downloads/KowsarDesk-1.4.9-upgrade-fix-20261024. Their SHA256 matched GitHub artifact
metadata and ZIP integrity checks passed. Both Windows executable checksums match
the published checksums and both PE headers identify x64. verification.json records
the exact source and successful workflow. No technical blocker remains for this
packaging/upgrade task. Next: verify an authorized real remote session on a second
supported Windows computer; session acceptance has not been inferred from the
installation and GUI checks.
