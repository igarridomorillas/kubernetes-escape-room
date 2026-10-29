I've finished the PowerShell port, but haven't been able to run it against a real cluster yet. Nothing is committed.

The port sits next to the Bash scripts rather than replacing them, so macOS and Linux keep make exactly as before. On Windows, attendees replace make with .\scripts\make.ps1: the targets are the same and LEVEL=level-02 works the same way. It runs on the Windows PowerShell 5.1 that comes with Windows as well as on PowerShell 7, so attendees don't need to install anything extra.

What I added

- scripts/escape-room.ps1: the PowerShell version of the harness. It uses the same .room-state, kubeconfig and scenarios as the Bash one.
- scripts/make.ps1: the PowerShell version of the Makefile, with the same targets.
- scenarios/\*/verify.ps1: one per level, doing the same checks as verify.sh.
- scripts/PSScriptAnalyzerSettings.psd1: settings for the PowerShell linter.
- Hints, incident alerts and AI tips still come from the shared Markdown files. On Windows, make verify in those files is shown as .\scripts\make.ps1 verify.

Tested on this machine (5.1 and 7)

- All scripts load without errors, and the PowerShell linter reports nothing.
- check passes. It also fails as expected when I planted a script with a broken encoding and a hardcoded C:\Users\… path.
- Image discovery finds the same images as the Bash version.
- hint and ai-assist print the same output as the Bash harness on all four levels, apart from the command swap.
- The error messages match the Bash ones: missing kind, no cluster, no active level, bad level.

Not tested: anything that needs a cluster (setup, start, verify, solve, reset, cleanup, test). kind isn't installed here, and downloading it was blocked by the permission check. To run it yourself:
winget install Kubernetes.kind
.\scripts\make.ps1 setup
.\scripts\make.ps1 test LEVEL=all
kind will also switch your default kubectl context away from minikube, the same as make setup does. glow on Windows is also untested. The session log lists all of this as unticked review items.

Things I changed beyond the scripts

- AI prompts: the four ai-assist.md prompts now forbid "any make target or script under scripts/". Otherwise an AI agent on Windows could run .\scripts\make.ps1 solve.
- Makefile:
  - make lint also lints the PowerShell scripts when pwsh is installed.
  - make check now catches PowerShell scripts saved without the encoding marker (BOM) that Windows PowerShell 5.1 needs, and Windows home paths.
  - make setup-dev installs the PowerShell linter when pwsh is installed.
- Docs: Amendment 9 in plan.md, plus updates to the README (Windows section), the pre-workshop checklist, the slide speaker notes, and a new docs/sessions/09-powershell-port.md.
- AGENTS.md and CLAUDE.md: both got the same edits, including a new rule that every Bash change must be mirrored in its PowerShell twin. Your own uncommitted formatting edits in AGENTS.md are untouched. CLAUDE.md doesn't have them, so the two files still differ by those edits.

The main ongoing cost is that every change to the harness, the Makefile or a verify.sh now has to be made twice.
