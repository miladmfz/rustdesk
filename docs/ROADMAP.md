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
