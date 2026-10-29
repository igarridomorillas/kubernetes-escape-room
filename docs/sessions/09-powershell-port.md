# Session 09 — PowerShell Port for Windows

> **Date:** 2026-10-29  
> **Status:** 🔍 In review (human sign-off pending)  
> **Branch:** not committed yet

---

## 🎯 Objectives

1. Let Windows attendees run the workshop without `make`, Bash or WSL.
2. Port `scripts/escape-room.sh`, the `Makefile` and every `verify.sh` to PowerShell, with the same commands, messages and state.
3. Keep macOS and Linux on Bash and `make`, unchanged.
4. Record the decision as a plan amendment (rule 10).

---

## 📦 Deliverables Created / Updated

| File | Purpose |
|---|---|
| [`scripts/escape-room.ps1`](../../scripts/escape-room.ps1) | PowerShell port of the harness: `setup`, `prepare`, `start`, `status`, `hint`, `ai-assist`, `verify`, `solve`, `reset`, `cleanup`, `help` |
| [`scripts/make.ps1`](../../scripts/make.ps1) | PowerShell counterpart of the `Makefile`: same targets plus `lint-ps`; accepts `LEVEL=<level>`, `-Level <level>` or a bare level |
| [`scripts/PSScriptAnalyzerSettings.psd1`](../../scripts/PSScriptAnalyzerSettings.psd1) | Lint settings shared by `make lint` and `.\scripts\make.ps1 lint`, including the 5.1 syntax-compatibility rule |
| [`scenarios/*/verify.ps1`](../../scenarios/) | One twin per level, with the same checks, probe image and messages as `verify.sh` |
| [`scenarios/*/ai-assist.md`](../../scenarios/) | The prompt rule now forbids "any make target or script under scripts/" |
| [`Makefile`](../../Makefile) | `lint` runs PSScriptAnalyzer when `pwsh` is installed; `check` enforces a UTF-8 BOM on `.ps1` files and also catches Windows home paths; `setup-dev` installs PSScriptAnalyzer when `pwsh` is installed |
| [`README.md`](../../README.md), [`docs/pre-workshop-checklist.md`](../pre-workshop-checklist.md), [`docs/presentation/slides.md`](../presentation/slides.md) | Windows prerequisites and commands, PowerShell `KUBECONFIG`, opencode deny rules for the PowerShell `solve`, a Windows smoke-test step, and speaker notes |
| [`docs/design/plan.md`](../design/plan.md) | D1 note and Amendment 9 |
| [`AGENTS.md`](../../AGENTS.md), `CLAUDE.md` | Rule 1/3/5/7/8/9 updates, directory tree, Windows commands, PowerShell conventions, harness behaviour of the port |

---

## 💡 Key Design Decisions & Learnings

1. **Add, don't replace.** A PowerShell-only harness would force macOS/Linux attendees to install `pwsh`. The port sits next to the Bash scripts and shares `.room-state`, `kind/.kube/config` and `scenarios/`. The price is that every change must be made twice (rule 8).
2. **Target Windows PowerShell 5.1, not only PowerShell 7.** 5.1 ships with every Windows 10/11 laptop, so the port keeps the zero-install promise of rule 1. Four 5.1 behaviours shaped the code:
   - **BOM:** without one, 5.1 reads a script as ANSI and garbles emoji and box-drawing characters, so every `.ps1` is UTF-8 with BOM and `check` enforces it.
   - **Native stderr:** when redirected, it becomes a terminating error under `$ErrorActionPreference = 'Stop'`. The harness wraps native calls in `Invoke-Native` / `Test-Native` / `Get-NativeOutput`; the `verify.ps1` scripts use `'Continue'` and `$LASTEXITCODE`.
   - **Double quotes:** 5.1 strips them from native arguments (checked: `'a "b c" d'` arrives as `a b c d`). Level 02's restart-count jsonpath is space-separated, and level 04 sends its probe pod as a manifest on stdin with the same `sh` script in a YAML block scalar.
   - **Missing programs:** a command that isn't found is a statement-terminating error, which a surrounding `try` catches. The helpers turn it into exit code 127, so a missing `kind` gives the same "cluster does not exist" message as Bash.
3. **The harness runs in the caller's session.** Unlike a Bash child process, `$env:KUBECONFIG` would leak into the user's terminal. The harness restores it (and the console encoding) in a `finally` block, and `verify.ps1` does the same. `exit` inside `try` still runs `finally` and returns the exit code to the caller (checked in 5.1 and 7).
4. **Shared Markdown, translated commands.** `incident.md`, `hints.md` and `ai-assist.md` say `make <target>`. Instead of keeping Windows copies, the PowerShell harness rewrites known targets to `.\scripts\make.ps1 <target>` when printing. "make target" in the prompts is left alone.
5. **`make.ps1` keeps the `make` muscle memory.** `LEVEL=level-02` is parsed like `make`, so the docs can say "replace `make` with `.\scripts\make.ps1`".
6. **Probe pod names get a random suffix.** `$PID` is the same for every `verify.ps1` run in one PowerShell session (for example `make.ps1 test`), so `verify-probe-<pid>` alone could collide with a pod that is still terminating.
7. **Kubeconfig permissions on Windows** use `icacls` (inheritance removed, full control for the current user) as the `chmod 700/600` equivalent. A failure only warns.
8. **Lint tooling:** PSScriptAnalyzer runs with `PSUseCompatibleSyntax` for 5.1 and 7.0. Three rules are excluded with reasons in the settings file: `Write-Host` is intended, the functions are private, and `npm.ps1` shims trigger false positives on positional parameters. Windows PowerShell 5.1 has no `Build` verb, so the app-image function is `Publish-AppImage`.
9. **Process lessons:** Git for Windows ships GNU grep 3.0, which does not match `\\` before `U` in an ERE; the Makefile uses the POSIX bracket form `[\]` instead. Editing a `.ps1` with tools that drop the BOM breaks 5.1, which `check` now catches.

---

## ✅ Verification & Smoke Tests

Run on Windows 10 with Windows PowerShell 5.1 and PowerShell 7.6:

- All `.ps1` files parse without errors in both versions.
- PSScriptAnalyzer 1.25 (module saved to a temp folder, not installed): no findings in either version.
- `.\scripts\make.ps1 check`: passes in both versions, and fails as expected on a planted BOM-less `verify.ps1` and a planted Windows home path.
- Image discovery: the PowerShell version finds the same images as the Bash `discover_images` (`curlimages/curl:8.11.1`, `nginx:1.27-alpine`, `python:3.12-alpine3.20`).
- With a hand-written `.room-state`, the output of `hint` (all 3 hints plus the repeat warning) and `ai-assist` is byte-identical to the Bash harness on all four levels, apart from the `make` → `.\scripts\make.ps1` swap. `HINT_LEVEL` and `COMPLETED_LEVELS` are written back with LF line endings.
- Error paths: unknown target, `start` without a level or with an invalid one, `setup` with `kind` missing (Windows install hint), `status` without a cluster, `hint` without state, and `verify.ps1` without a kubeconfig all print the Bash messages and exit `1`.
- The new `Makefile` recipe lines (BOM loop, home-path grep) were run in Git Bash. `make` itself is not installed on the build machine.

Not run, left unchecked below: the cluster flows (`setup`, `prepare`, `start`, `verify`, `solve`, `reset`, `cleanup`, `test LEVEL=all`), because `kind` is not installed on the build machine. Also not run: `glow` rendering on Windows, `setup-dev`, `slides`, `slides-export`, and the port under `pwsh` on macOS/Linux.

---

## Review checklist

- [ ] `.\scripts\make.ps1 setup` creates the cluster, installs Cilium and writes `kind/.kube/config` restricted to the current user (`icacls kind\.kube\config`)
- [ ] `.\scripts\make.ps1 test LEVEL=all` passes in Windows PowerShell 5.1 and in PowerShell 7
- [ ] `verify` on level 04 creates the probe pod from the stdin manifest and reports a failing transaction when broken
- [ ] After any command, `$env:KUBECONFIG` in the calling terminal is unchanged
- [ ] `.\scripts\make.ps1 prepare` pulls the images and builds both app images (also with the repo checked out with CRLF line endings)
- [ ] `glow` on Windows: styled hints and AI tips, plain text with `$env:NO_COLOR = '1'`
- [ ] Mixed use: a level started with `make` on macOS/Linux can be continued with the PowerShell harness (`pwsh`) and the other way round
- [ ] `make validate` on macOS/Linux with `pwsh` installed runs PSScriptAnalyzer through `make.ps1 lint-ps`
