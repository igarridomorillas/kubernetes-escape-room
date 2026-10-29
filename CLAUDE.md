# AGENTS.md — Kubernetes Escape Room

> This file defines the rules, conventions, and commands that every AI agent and human contributor **must** follow when working in this repository. Read it fully before making any changes.

---

## Project Context

This is a **Kubernetes Escape Room** — a hands-on collaborative workshop (~55 min: 10 min talk, three levels, debrief) for Platform/SRE/Software engineers. Attendees debug intentionally broken Kubernetes scenarios with the help of AI copilots, CLI agents, and agentic harnesses.

**Key files:**
- [`docs/design/plan.md`](docs/design/plan.md) — Full architecture & implementation plan (source of truth)
- [`docs/sessions/00-milestones.md`](docs/sessions/00-milestones.md) — Milestone tracker & human review gates
- [`AGENTS.md`](AGENTS.md) — This file
- `.room-state` — Runtime state (gitignored, auto-managed by `./scripts/escape-room.sh`)

---

## Repository Rules

### Non-negotiable constraints

1. **Zero external runtime dependencies** in `./scripts/escape-room.sh` and all `verify.sh` scripts.
   - Sole exception: the optional `glow` Markdown renderer, used only when already installed (`cat` fallback).
   - Pure POSIX Bash only (`#!/usr/bin/env bash`).
   - Allowed: `curl`, `awk`, `sed`, `grep`, `kubectl`, `kind`, `docker`.
   - **Forbidden:** `jq`, `python`, `ruby`, `yq`, or any package-manager-installed tool.
   - **PowerShell port (Windows):** the same rule applies to `scripts/escape-room.ps1`, the harness targets of `scripts/make.ps1` and all `verify.ps1` scripts. They must run on Windows PowerShell 5.1 and PowerShell 7+ with built-in cmdlets only; besides `kubectl`, `kind`, `docker` and the optional `glow`, only the Windows built-in `icacls` is allowed.

2. **Namespaces are sacred.** Each level owns exactly one namespace:
   - Level 01 → `escape-level-01`
   - Level 02 → `escape-level-02`
   - Level 03 → `escape-level-03`
   - Level 04 → `escape-level-04`
   - Never cross-contaminate resources between namespaces.

3. **`verify.sh` is the contract.** Every scenario's `verify.sh` and its PowerShell twin `verify.ps1` must:
   - Exit `0` on success, `1` on failure — no other exit codes.
   - Be **idempotent** — safe to run multiple times without side effects.
   - Run **in-cluster** using ephemeral probe pods (`curlimages/curl` or `kubectl exec`).
   - Print a clear message on failure: what is still broken (without giving away the fix).

4. **Broken state must be reproducible.** Applying manifests in `scenarios/<level>/broken/` must always produce the intended failure mode. If a base image is required, use only publicly available images with pinned digests or well-known tags.

5. **No secrets or credentials** in any manifest, script, or documentation. Simulated `DATABASE_URL` values must be clearly fake (e.g., `postgresql://fake-host:5432/fakedb`).

6. **No absolute or user home paths** in any file. Never commit or write `/Users/<name>`, `/home/<name>`, or machine-specific paths into scripts, manifests, markdown docs, prompts, or links. Always use relative repository paths or environment-agnostic variables.

7. **Script placement and permissions.** CLI tools and automation scripts must live under `scripts/` (no root wrappers or root aliases). Executable scripts must be set to `chmod 750` (`-rwxr-x---`). PowerShell scripts (`.ps1`) need no executable bit but must be saved as UTF-8 **with BOM**: Windows PowerShell 5.1 reads BOM-less files as ANSI and garbles their emoji and box-drawing characters.

---

## Directory Layout

```
kubernetes-escape-room/
├── AGENTS.md                        # ← You are here
├── README.md
├── Makefile                         # Task runner for slides, linting, validation & smoke tests
├── .mcp.json                        # Root Slidev MCP server config (CLI/IDE clients)
├── skills-lock.json                 # Agent skills lockfile
├── .agents/
│   ├── skills/
│   │   └── slidev/                  # Slidev skill (gitignored; restore: npx skills experimental_install)
│   └── plugins/
│       └── slidev/                  # Antigravity workspace plugin (plugin.json + mcp_config.json)
├── scripts/
│   ├── escape-room.sh               # Main CLI harness implementation (executable Bash, 750)
│   ├── escape-room.ps1              # PowerShell port of the harness for Windows (UTF-8 with BOM)
│   ├── make.ps1                     # PowerShell counterpart of the Makefile (same targets)
│   └── PSScriptAnalyzerSettings.psd1 # Lint settings for the PowerShell scripts
├── .room-state                      # Runtime state (gitignored)
├── kind/
│   ├── cluster-config.yaml          # Kind cluster definition (disableDefaultCNI)
│   ├── .kube/config                 # Repo-local kubeconfig (gitignored, written by `setup`)
│   └── cni/
│       └── cilium.yaml              # Pinned Cilium 1.20.2 CNI manifest (rendered by helm)
├── scenarios/
│   ├── level-01-ghost-image/
│   │   ├── broken/                  # Broken Kubernetes manifests
│   │   ├── solution/                # Reference fix manifests
│   │   ├── incident.md              # Pager-style alert shown to attendees
│   │   ├── hints.md                 # 3-tier progressive hints
│   │   ├── ai-assist.md             # Paste-ready AI agent prompt (shown by `ai-assist`, no spoilers)
│   │   ├── verify.sh                # Deterministic verification probe
│   │   └── verify.ps1               # PowerShell twin of verify.sh (same checks and messages)
│   ├── level-02-crashing-config/
│   │   ├── app/                     # Self-contained app source + Dockerfile (built by `start`)
│   │   ├── broken/
│   │   ├── solution/
│   │   ├── incident.md
│   │   ├── hints.md
│   │   ├── ai-assist.md
│   │   ├── verify.sh
│   │   └── verify.ps1
│   ├── level-03-silent-wall/
│   │   ├── broken/
│   │   ├── solution/
│   │   ├── incident.md
│   │   ├── hints.md
│   │   ├── ai-assist.md
│   │   ├── verify.sh
│   │   └── verify.ps1
│   └── level-04-ghost-microservices/  # Optional bonus
│       ├── app/                     # Self-contained 3-tier app + Dockerfile (built by `start`)
│       ├── broken/
│       ├── solution/
│       ├── incident.md
│       ├── hints.md
│       ├── ai-assist.md
│       ├── verify.sh
│       └── verify.ps1
└── docs/
    ├── design/
    │   └── plan.md                  # Architecture & implementation plan
    ├── presentation/
    │   ├── README.md                # Contributor guide for Slidev & MCP setup
    │   ├── package.json             # Slidev dependencies & scripts
    │   ├── slides.md                # Workshop presentation deck (M6)
    │   ├── style.css                # Deck theme (colors, cards, chips)
    │   └── global-bottom.vue        # Slide numbers (<n>/<total>)
    ├── sessions/
    │   ├── 00-milestones.md         # Milestone tracker & review gates
    │   ├── 01-milestone-01.md       # Session 1 log: Core harness & cluster setup
    │   ├── 02-milestone-02.md       # Session 2 log: Level 01 — The Ghost Image
    │   ├── 03-milestone-03.md       # Session 3 log: Level 02 — The Crashing Config
    │   ├── 04-milestone-04.md       # Session 4 log: Level 03 — The Silent Wall
    │   ├── 05-milestone-05.md       # Session 5 log: AI-assisted troubleshooting best practices
    │   ├── 06-level-04.md           # Session 6 log: Bonus Level 04 — The Ghost in the Microservices
    │   ├── 07-milestone-06.md       # Session 7 log: Workshop presentation, docs & pre-event readiness
    │   ├── 08-ai-assist-prompts.md  # Session 8 log: Agent-ready ai-assist prompts & optional glow rendering
    │   └── 09-powershell-port.md    # Session 9 log: PowerShell port for Windows
    ├── ai-prompts-cheatsheet.md     # One-page A4 SRE Copilot cheatsheet (M5/M6)
    ├── ai-exercises.md              # Instructor guide: bad vs good per level, challenge exercise (M5)
    ├── ai-research-notes.md         # Cited sources, established vs emerging (M5)
    └── pre-workshop-checklist.md    # Instructor & attendee pre-event checklist (M6)
```

---

## Build & Test Commands

### Prerequisites

```bash
# Verify required tools are installed
docker --version       # Docker Desktop
kind --version         # >= 0.20.0
kubectl version        # >= 1.28

# Optional contributor/instructor setup (installs shellcheck, Slidev, Playwright Chromium & restores the pinned agent skills)
make setup-dev
```

### Cluster lifecycle

```bash
# Create the Kind cluster (first-time setup)
# Checks for docker, kind and kubectl (and that Docker is running); if any
# requirement is missing it prints an install link/hint and exits 1.
# Then installs the pinned Cilium CNI (kind/cni/cilium.yaml) and waits for Ready nodes.
make setup

# Tear down the cluster
make cleanup
```

### Running a level end-to-end

```bash
# Setup + pull every scenario image + build app images
make prepare

# Load and break a specific level
make start LEVEL=level-01     # level-02, level-03, level-04

# Check current status
make status

# Get the next hint
make hint

# Show the AI copilot tip for the current level (does not use a hint)
make ai-assist

# Verify the scenario is fixed
# (on success, prints next steps: start the next level, reset, or cleanup)
make verify

# Apply the reference solution (instructor use only)
make solve

# Re-inject broken state without restarting cluster
# (also removes the level from COMPLETED_LEVELS; `start` does the same)
make reset

# Cleanup
make cleanup
```

### Presentation (`Slidev`)

```bash
# Start the live-reloading Slidev server (http://localhost:3030)
make slides

# Build and export the presentation to PDF (docs/presentation/slides-export.pdf)
make slides-export
```

### Linting & shell script validation

```bash
# Run all static validations (shellcheck + 750 permissions + no user home paths)
make validate

# Individual validation targets
make lint          # shellcheck scripts/escape-room.sh scenarios/*/verify.sh (+ PSScriptAnalyzer on the .ps1 scripts when pwsh is installed)
make check         # enforce chmod 750 (git only tracks 755, so it re-applies 750), a UTF-8 BOM on .ps1 files and no hardcoded user home paths
```

### Smoke-testing a scenario

```bash
# Automated smoke test via Makefile (single level or all levels)
make test LEVEL=level-01          # or: make test LEVEL=all

# Manual scenario smoke test (broken → verify fails → solve → verify passes)
make start LEVEL=level-01
make verify    # Expected: exits 1 (still broken)
make solve
make verify    # Expected: exits 0 (escaped)
make reset
make verify    # Expected: exits 1 (re-broken)
```

### Windows (PowerShell)

Windows contributors and attendees use the PowerShell port: replace `make` with `.\scripts\make.ps1` (same targets; `LEVEL=level-02`, `-Level level-02` or a bare `level-02`). It runs on Windows PowerShell 5.1 and PowerShell 7+.

```powershell
# Only if Windows blocks running scripts (this terminal only)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\scripts\make.ps1 help
.\scripts\make.ps1 prepare
.\scripts\make.ps1 start LEVEL=level-01
.\scripts\make.ps1 verify
.\scripts\make.ps1 setup-dev          # PSScriptAnalyzer, shellcheck (winget), Slidev, Playwright, agent skills
.\scripts\make.ps1 validate           # PSScriptAnalyzer (+ shellcheck if installed), git executable bits, BOM, home paths
.\scripts\make.ps1 test LEVEL=all     # same smoke test as make test
```

---

## Coding Conventions

### Bash scripts

- Always use `#!/usr/bin/env bash` shebang.
- Always set `set -euo pipefail` at the top of every script.
- Use `readonly` for constants; use `local` for all function-scoped variables.
- Color output using ANSI codes defined as named constants, e.g.:
  ```bash
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly NC='\033[0m'  # No Color
  ```
- Wrap long pipelines in functions with descriptive names.
- No inline `awk` programs longer than 3 lines — extract into a named function.

### PowerShell scripts

- Every `.ps1` file starts with `#Requires -Version 5.1` and sets `Set-StrictMode -Version 3.0`. Save it as UTF-8 **with BOM** (`make check` and `.\scripts\make.ps1 check` enforce it); editors and tools that strip the BOM break Windows PowerShell 5.1.
- Code must run on Windows PowerShell 5.1 and PowerShell 7+: no `` `e `` escape (use `[char]27`), ternary, `??`, `&&`/`||` chains or `-Parallel`, and use `[Environment]::OSVersion.Platform` instead of `$IsWindows`. PSScriptAnalyzer's `PSUseCompatibleSyntax` rule (`scripts/PSScriptAnalyzerSettings.psd1`) checks this.
- Harness and `make.ps1`: `$ErrorActionPreference = 'Stop'`, and every native command goes through `Invoke-Native`, `Test-Native` or `Get-NativeOutput`. They relax the preference locally (5.1 turns redirected native stderr into a terminating error) and treat a missing program as exit code 127, as Bash does.
- `verify.ps1`: `$ErrorActionPreference = 'Continue'`, check `$LASTEXITCODE` after every native command, and delete the probe pod and restore `KUBECONFIG` in a `finally` block (the `trap ... EXIT` equivalent).
- Never put double quotes inside native command arguments, because 5.1 strips them. Use quote-free jsonpath, or send a manifest on stdin (`$manifest | kubectl create -f -`) with LF line endings.
- Use approved verbs (Windows PowerShell 5.1 has no `Build` or `Deploy`) and singular nouns. `Write-Host` is the right call for user-facing output. Run `.\scripts\make.ps1 lint` (or `make lint` with `pwsh` installed) after every change.
- Keep messages, emoji, colours and banners identical to the Bash twin; only `make <target>` becomes `.\scripts\make.ps1 <target>`.

### Terminal formatting & ASCII art

- **Use open-ended horizontal divider bars** (e.g. `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`) instead of fixed-width 3-sided boxes (`╔══...║`).
  - *Rationale:* `printf "%-Ns"` pads by byte count, not visual display columns. Multi-byte emojis (`🚀`, `🔥`, `📊`, `🔓`, `♻️` take 4–6 bytes) and unicode symbols (`—`) cause jagged right borders.
- **ASCII art width constraint:** All ASCII art headers must be designed for a max line width of $\le 78$ columns. This prevents line-wrapping and corrupted art on standard 80-column terminal windows (e.g. macOS Terminal default or split-pane editors).
- **Multiline banner stacking:** If an ASCII art phrase exceeds 78 columns, stack it into multiline sections (e.g. `K8S    ESCAPE` on row 1, `ROOM` centered beneath it on row 2).
- **Inspect ASCII letterforms:** Always trace and verify ASCII letters character-by-character to prevent typos or missing letter glyphs.

### Kubernetes manifests

- Every manifest **must** have `namespace` set explicitly (never rely on default namespace).
- Every workload **must** have `app` and `component` labels:
  ```yaml
  labels:
    app: payment-gateway
    component: backend
    level: "01"
  ```
- Resource requests and limits are **required** on every container.
- Use `apiVersion: apps/v1` and `kind: Deployment` — no bare Pods except for probe/debug use.

### `verify.sh` template

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="escape-level-XX"
APP_LABEL="app=your-app"
SERVICE_URL="http://your-service.${NAMESPACE}.svc.cluster.local:PORT/path"

echo "🔍 Verifying Level XX..."

# Step 1: Check the rollout is complete (new pods Ready, old pods gone).
# Never read items[0] of a pod list: stale pods from an old ReplicaSet break it.
if ! kubectl rollout status deployment/your-app -n "${NAMESPACE}" --timeout=5s > /dev/null 2>&1; then
  echo "❌ Pod is not ready. Run: kubectl get pods -n ${NAMESPACE} -l ${APP_LABEL}"
  exit 1
fi

# Step 2: In-cluster HTTP probe (pinned image, detached pod).
# Do NOT use `kubectl run -i --rm`: it can return 0 when the pod exits before
# kubectl attaches, so a failing curl would look like a pass.
PROBE_POD="verify-probe-$$"
trap 'kubectl delete pod "${PROBE_POD}" -n "${NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true' EXIT

if ! kubectl run "${PROBE_POD}" --image=curlimages/curl:8.11.1 --restart=Never \
  -n "${NAMESPACE}" -- curl -fsS --max-time 5 -o /dev/null "${SERVICE_URL}" >/dev/null 2>&1; then
  echo "⚠️  Could not create the probe pod. Retry in a moment."
  exit 1
fi

PHASE=""
for _ in $(seq 1 60); do
  PHASE=$(kubectl get pod "${PROBE_POD}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "${PHASE}" == "Succeeded" || "${PHASE}" == "Failed" ]] && break
  sleep 1
done

case "${PHASE}" in
  Succeeded) ;;
  Failed) echo "❌ Endpoint probe failed: ${SERVICE_URL} did not return HTTP 200"; exit 1 ;;
  *) echo "⚠️  Probe pod did not finish (image pull or scheduling issue). Retry in a moment."; exit 1 ;;
esac

echo "✅ Level XX complete! You escaped!"
exit 0
```

### Scenario authoring rules (learned from Level 01 review)

- **Pin every image** in `broken/`, `solution/` and probe pods to a specific version (e.g. `nginx:1.27-alpine`, `curlimages/curl:8.11.1`). Never use `latest` or floating tags like `nginx:alpine`.
- **`verify.sh` readiness:** use `kubectl rollout status deployment/<name> --timeout=5s` (or `kubectl wait`), never `items[0]` of a pod list — during a rollout the old failing pod can sort first.
- **`verify.sh` probe pods run detached:** create the pod, poll `.status.phase` (`Succeeded`/`Failed`, bounded loop) and clean up with a `trap`. Never rely on the exit code of `kubectl run -i --rm` — it can be lost and report success for a failing curl (found during the M2 end-to-end test).
- **`verify.sh` failures must be diagnosable:** distinguish an endpoint failure (`Failed` phase) from a probe-pod failure (could not create / did not finish: image pull or scheduling).
- **Hints are progressive:** Hint 1 = concept, Hint 2 = investigation commands (`describe`, `logs`, `events`) **without** the fix, Hint 3 = a short, light-hearted pointer to `make ai-assist` (no prompt text, no level facts). Never put the fix command or the correct value in Hints 1–2.
- **`incident.md` describes symptoms only:** no root cause, no "last deploy" hints, and no endpoints/paths that the workload does not actually serve.
- **`ai-assist.md` is an agent-ready prompt (learned from the ai-assist rewrite):** `docs/ai-prompts-cheatsheet.md` is the base technique; `ai-assist.md` only applies it. Structure: manual evidence commands, a terse bad prompt ending in "Fix it.", one paste-ready prompt (RULES, ISSUE, TASK), a follow-up prompt, a short "why". No placeholders: the agent gathers the evidence itself. ISSUE restates only the symptom from `incident.md` (no root cause, no fix). Level traps (logs alone, unfiltered logs, unsafe network shortcuts, invented image tags) go in RULES. Every prompt must forbid mutating commands, `make` targets and scripts under `scripts/` (Windows attendees run `.\scripts\make.ps1`), and reading Secrets. Do not use the section-sign symbol or absolute paths.
- **Executable scripts** must be `chmod 750`; re-check after editing with tools that reset modes.
- **Images must be discoverable (learned from `prepare`):** write every image as a literal `image: <ref>`, `--image=<ref>` or Dockerfile `FROM <ref>`, never built from shell/template variables, so `prepare` finds and pre-pulls it. Never list images by hand in scripts or docs; add them to the scenario and let `discover_images` pick them up.
- **Pull, don't `kind load` third-party images (learned from `prepare`):** with Docker's containerd image store, `kind load docker-image` fails on multi-arch images (`ctr: content digest ... not found`). Only locally built `escape-room/*` images are loaded; everything else is pulled by the node (or pre-pulled on the host). Do not silence stderr when debugging such failures.

### Harness behaviour (`scripts/escape-room.sh`)

- `setup` checks `docker`, `kind` and `kubectl`; for a missing `docker` or `kind` it prints an install link/hint and exits `1`. A stopped Docker daemon gets a "start Docker Desktop" hint.
- `setup` creates the cluster with `networking.disableDefaultCNI: true` (`kind/cluster-config.yaml`), then applies the pinned Cilium 1.20.2 manifest `kind/cni/cilium.yaml` and waits for the Cilium DaemonSet, operator, Hubble Relay, Hubble UI and all nodes `Ready`. Cilium enforces NetworkPolicy; kindnet does not. Regenerate the manifest with `helm template cilium cilium/cilium --version 1.20.2 --namespace kube-system --include-crds --set ipam.mode=kubernetes --set kubeProxyReplacement=false --set operator.replicas=1 --set hubble.enabled=true --set hubble.relay.enabled=true --set hubble.ui.enabled=true --set envoy.enabled=false > kind/cni/cilium.yaml` when bumping the version.
- `prepare` runs `setup`, then `pull_images` runs `docker pull` on the host for every image found by `discover_images` (never hardcoded: `image:`/`--image=` references in `scenarios/` manifests, `verify.sh` and docs, plus Dockerfile `FROM` lines; `escape-room/*` skipped; Cilium excluded because `setup` already pulls it). Images are only pulled, not loaded into the kind node. It then builds/loads every level's app image. Images whose tag does not exist are skipped silently and never listed (level 01's broken image would otherwise be a spoiler); any other pull failure is reported by name as a warning.
- If a cluster exists that was created with kindnet, `setup` exits `1` and asks for `cleanup` followed by `setup`.
- `setup` writes a repo-local kubeconfig `kind/.kube/config` (dir `700`, file `600`) with `kind export kubeconfig`, on every run, so it stays in sync with the cluster. kind still updates the default `~/.kube/config` and its current-context as usual. The harness exports `KUBECONFIG` to that file (via `require_cluster` and `setup`), so every `kubectl` call, including those in `verify.sh`, targets only the escape-room cluster and never the user's current context. Each `verify.sh` pins `KUBECONFIG` to the same file and exits `1` if it is missing. `cleanup` removes `kind/.kube/` and `.room-state` (also when the cluster is already gone); `require_cluster` tells the user to run `setup` if the file is missing.
- `start <level>` and `reset` re-break the level **and** remove it from `COMPLETED_LEVELS` in `.room-state`, so `status` never shows a broken level as completed. Only `cleanup` deletes `.room-state`.
- `start <level>` first deletes the namespaces of all other levels (completed marks in `.room-state` are kept), so a previous level never interferes with the new one.
- `start <level>` builds `scenarios/<level>-*/app/` when it contains a `Dockerfile` and loads the image into the kind cluster (`escape-room/<level>-app:1.0.0`, e.g. `escape-room/level-02-app:1.0.0`, `escape-room/level-04-app:1.0.0`), so no external registry is needed. Manifests reference that tag with `imagePullPolicy: IfNotPresent`. `reset` reuses the loaded image.
- `start` and `reset` wait (via `wait_for_level_rollout`, currently `level-03` and `level-04`; level 01 must stay broken) up to 120s for the Deployments to roll out before returning, so an immediate `verify` reports the real fault rather than "not ready". `solve` prints a warning (instead of silently continuing) if its rollout does not finish in 120s.
- `verify` success appends the level to `COMPLETED_LEVELS` (exact match, no substring grep) and prints a "What's next?" block (`make start LEVEL=<next-level>` when the next level's scenario directory exists, otherwise a "no further levels yet" note, plus `make reset` and `make cleanup`).
- `ai-assist` prints `scenarios/<level>-*/ai-assist.md` for the current level through `render_markdown` (no content parsing). It is independent of `HINT_LEVEL` and never changes `.room-state`. `ai-assist.md` follows the hint discipline: no fix, no root cause, no correct values. It is a separate file from `hints.md` on purpose, since `extract_hint` prints everything under a hint heading. `start` lists the command in its "Useful commands".
- `hint` advances `HINT_LEVEL` from 1 to 3. Once all 3 are used it prints the "already used all 3 hints" warning (with the `make solve` note) and shows Hint 3 again, without changing `HINT_LEVEL`.
- `render_markdown` (stdin → stdout) pipes `incident.md`, hints and `ai-assist.md` through `glow` (minimal zero-margin, zero-padding style embedded in the function, `-w 0`, so selected text pastes back exactly) when stdout is a terminal, `NO_COLOR` is unset and `glow` is installed; otherwise (or if glow itself fails) it is plain `cat`. `glow` is an optional prerequisite (listed as optional in `README.md` and `docs/pre-workshop-checklist.md`); the harness never installs it and never requires it.
- Levels are switched with `start <level>` only; there is intentionally no `next` command.
- **PowerShell port (`scripts/escape-room.ps1`, `scripts/make.ps1`):** mirrors every command above with the same messages, state file (`.room-state`, LF line endings) and repo kubeconfig, and runs the level's `verify.ps1` in the same session (exit code `0`/`1`). Differences: it restores `KUBECONFIG` and the console encoding on exit, because it runs in the caller's session; it restricts `kind/.kube/` with `icacls` on Windows (`chmod` elsewhere) and only warns if that fails; it prints the `make <target>` references in `incident.md`, `hints.md` and `ai-assist.md` as `.\scripts\make.ps1 <target>`; and `make.ps1` accepts `LEVEL=<level>`, `-Level <level>` or a bare level. Any change to the harness, the `Makefile` or a `verify.sh` must be mirrored in its twin.

### Presentation & `Makefile` rules (learned from M6)

- **Subdirectory isolation (`docs/presentation/`):** Keep Slidev's `package.json` and `slides.md` (the generated `package-lock.json` is gitignored) inside `docs/presentation/` so the repository root remains free of Node.js runtime dependencies for attendees running `./scripts/escape-room.sh`.
- **`npx` MCP binary resolution (`--prefix docs/presentation`):** On npm, the Slidev CLI package is `@slidev/cli` (which installs the local `slidev` binary into `docs/presentation/node_modules/.bin/slidev`); there is no standalone `slidev` package on the npm registry. Consequently, any MCP configuration or command executed from the repository root **must** pass `--prefix docs/presentation` (`npx --prefix docs/presentation slidev mcp docs/presentation/slides.md`).
- **Slidev PDF export prerequisites (`playwright-chromium`):** `slidev export` requires both `"playwright-chromium"` in `docs/presentation/package.json` and the Chromium browser binary installed via `npx --prefix docs/presentation playwright install chromium`. `make setup-dev` installs both (and restores the pinned agent skills from `skills-lock.json`); `make slides-export` runs `setup-dev` if the dependencies are missing and builds the deck (`slidev build`) before exporting.
- **Root `Makefile` conventions:** Keep `Makefile` targets concise and parameterized (`make start LEVEL=level-XX`, `make test LEVEL=level-XX` or `LEVEL=all`, `make setup-dev`, `make slides`, `make slides-export`, `make lint`, `make check`, `make validate`) rather than duplicating per-level targets.

---

## Agent Behaviour Guidelines

These rules apply to any AI agent (Antigravity, Copilot, etc.) working in this repo:

### Before writing any code

1. Re-read [`docs/design/plan.md`](docs/design/plan.md) for the milestone you are implementing.
2. Check whether the target directory already exists — **never overwrite existing verified files** without explicit user instruction.
3. Confirm the correct namespace for the level you are building.

### When implementing

4. Implement **one milestone at a time** unless explicitly instructed otherwise.
5. After every file created, run `shellcheck` on any `.sh` file. Fix all `SC*` warnings before proceeding. Run PSScriptAnalyzer (`.\scripts\make.ps1 lint`, or `make lint` with `pwsh` installed) on any `.ps1` file and fix every finding.
6. After applying broken manifests, validate the failure mode with `kubectl get pods -n <namespace>` before moving on.
7. After applying solution manifests, run `make verify` and confirm exit code `0`.

### When making changes

8. **Never modify `scripts/escape-room.sh` without also updating the corresponding section in this `AGENTS.md`.** The same goes for the PowerShell twins: a change to `escape-room.sh`, the `Makefile` or a `verify.sh` must be mirrored in `escape-room.ps1`, `make.ps1` or that level's `verify.ps1`, and the other way round.
9. **Never modify a `verify.sh` or `verify.ps1` to make it pass without fixing the underlying scenario bug.**
10. If a design decision must change (e.g., a base image is unavailable), document it in [`docs/design/plan.md`](docs/design/plan.md) under a new "Amendment" section and flag it for human review.

### Commit hygiene

11. **Never commit without explicit instruction from the repo owner.** Make all file changes, then stop and wait to be told to commit.
12. **No co-author attribution.** Do not add `Co-authored-by` or any agent/AI trailer lines to commit messages.
13. Commit message prefixes are limited to three types:
    ```
    feat: add broken manifests for ghost image scenario
    fix: handle missing .room-state on first run
    chore: add shellcheck to CI
    ```
14. Each milestone should land in its own commit (or small set of related commits). Do not bundle multiple milestones into one commit.
15. Never commit `.room-state`, cluster kubeconfigs, or any file matching `.gitignore`.

### Post-merge & session documentation

16. **Keep session records synchronized.** When a milestone PR is reviewed and merged:
    - Update `docs/sessions/00-milestones.md`: mark the milestone status as complete and check off all review checklist items (`[x]`).
    - Create a session log `docs/sessions/<NN>-milestone-<XX>.md` detailing deliverables, key design iterations, CLI commands, and verification gates.
    - Keep the directory trees in `README.md` and `AGENTS.md` up to date.
17. **Never pre-tick human review gates.** Review checklists in `00-milestones.md` and smoke-test items in session logs stay unchecked (status "🔍 In review") until the human has approved the PR; only then mark them complete (rule 16).
18. **State what you could not run.** If `kind`, `shellcheck` or a cluster is unavailable, say so in the PR/session log and leave the related verification items unchecked rather than asserting they passed.

---

## Human Review Gates

The human (repo owner) must review and explicitly approve before an agent proceeds past these checkpoints:

| Gate | Trigger | What to review |
|---|---|---|
| **M1 done** | After `scripts/escape-room.sh` is implemented | All 8 commands work; shellcheck passes; state file updates correctly |
| **M2 done** | After level-01 is implemented | Broken state shows `ImagePullBackOff`; verify fails; solve → verify passes |
| **M3 done** | After level-02 is implemented | Both bugs independently visible; healthz endpoint verifies correctly |
| **M4 done** | After level-03 is implemented | Both misconfiguration bugs visible; end-to-end probe works |
| **Bonus done** | After level-04 is implemented | 5,000-line log haystack with `"coupon"` `NullPointerException`; 10-transaction checkout probe verifies correctly |
| **M5 done** | After AI best-practices content is written | Sources cited and dated; challenge-the-hypothesis exercise has facilitator notes; guardrails present; MCP/CLI-agent steps tested or flagged |
| **M6 done** | After docs are created | Cheatsheet fits one A4 page; checklist covers all attendee prereqs |
| **Pre-event** | 48h before workshop | Full smoke test of all levels on a clean machine |

---

## Gitignore Entries (ensure these exist)

```
.room-state
*.kubeconfig
kubeconfig
.DS_Store
kind/.kube/
mcp-config.toml
opencode.json
node_modules/
docs/presentation/dist/
docs/presentation/.slidev/
docs/presentation/slides-export.pdf
docs/presentation/package-lock.json
.agents/skills/
```
