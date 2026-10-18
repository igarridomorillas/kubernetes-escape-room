# AGENTS.md — Kubernetes Escape Room

> This file defines the rules, conventions, and commands that every AI agent and human contributor **must** follow when working in this repository. Read it fully before making any changes.

---

## Project Context

This is a **Kubernetes Escape Room** — a hands-on collaborative workshop (40–50 min) for Platform/SRE/Software engineers. Attendees debug intentionally broken Kubernetes scenarios with the help of free AI copilots.

**Key files:**
- [`docs/design/plan.md`](docs/design/plan.md) — Full architecture & implementation plan (source of truth)
- [`docs/sessions/00-milestones.md`](docs/sessions/00-milestones.md) — Milestone tracker & human review gates
- [`AGENTS.md`](AGENTS.md) — This file
- `.room-state` — Runtime state (gitignored, auto-managed by `./scripts/escape-room.sh`)

---

## Repository Rules

### Non-negotiable constraints

1. **Zero external runtime dependencies** in `./scripts/escape-room.sh` and all `verify.sh` scripts.
   - Pure POSIX Bash only (`#!/usr/bin/env bash`).
   - Allowed: `curl`, `awk`, `sed`, `grep`, `kubectl`, `kind`, `docker`.
   - **Forbidden:** `jq`, `python`, `ruby`, `yq`, or any package-manager-installed tool.

2. **Namespaces are sacred.** Each level owns exactly one namespace:
   - Level 01 → `escape-level-01`
   - Level 02 → `escape-level-02`
   - Level 03 → `escape-level-03`
   - Level 04 → `escape-level-04`
   - Never cross-contaminate resources between namespaces.

3. **`verify.sh` is the contract.** Every scenario's `verify.sh` must:
   - Exit `0` on success, `1` on failure — no other exit codes.
   - Be **idempotent** — safe to run multiple times without side effects.
   - Run **in-cluster** using ephemeral probe pods (`curlimages/curl` or `kubectl exec`).
   - Print a clear message on failure: what is still broken (without giving away the fix).

4. **Broken state must be reproducible.** Applying manifests in `scenarios/<level>/broken/` must always produce the intended failure mode. If a base image is required, use only publicly available images with pinned digests or well-known tags.

5. **No secrets or credentials** in any manifest, script, or documentation. Simulated `DATABASE_URL` values must be clearly fake (e.g., `postgresql://fake-host:5432/fakedb`).

---

## Directory Layout

```
kubernetes-escape-room/
├── AGENTS.md                        # ← You are here
├── README.md
├── scripts/
│   └── escape-room.sh               # Main CLI harness implementation (executable Bash)
├── .room-state                      # Runtime state (gitignored)
├── kind/
│   └── cluster-config.yaml          # Kind cluster definition
├── scenarios/
│   ├── level-01-ghost-image/
│   │   ├── broken/                  # Broken Kubernetes manifests
│   │   ├── solution/                # Reference fix manifests
│   │   ├── incident.md              # Pager-style alert shown to attendees
│   │   ├── hints.md                 # 3-tier progressive hints
│   │   └── verify.sh                # Deterministic verification probe
│   ├── level-02-crashing-config/
│   │   ├── app/                     # Self-contained app source + Dockerfile
│   │   ├── broken/
│   │   ├── solution/
│   │   ├── incident.md
│   │   ├── hints.md
│   │   └── verify.sh
│   ├── level-03-silent-wall/
│   │   ├── broken/
│   │   ├── solution/
│   │   ├── incident.md
│   │   ├── hints.md
│   │   └── verify.sh
│   └── level-04-ghost-microservices/  # Optional bonus
│       └── ...
└── docs/
    ├── design/
    │   └── plan.md                  # Architecture & implementation plan
    ├── ai-prompts-cheatsheet.md
    └── pre-workshop-checklist.md
```

---

## Build & Test Commands

### Prerequisites

```bash
# Verify required tools are installed
docker --version       # Docker Desktop or Colima
kind --version         # >= 0.20.0
kubectl version        # >= 1.28
```

### Cluster lifecycle

```bash
# Create the Kind cluster (first-time setup)
./scripts/escape-room.sh setup

# Tear down the cluster
./scripts/escape-room.sh cleanup
```

### Running a level end-to-end

```bash
# Load and break a specific level
./scripts/escape-room.sh start level-01     # or level-02, level-03

# Check current status
./scripts/escape-room.sh status

# Get the next hint
./scripts/escape-room.sh hint

# Verify the scenario is fixed
./scripts/escape-room.sh verify

# Apply the reference solution (instructor use only)
./scripts/escape-room.sh solve

# Re-inject broken state without restarting cluster
./scripts/escape-room.sh reset

# Cleanup
./scripts/escape-room.sh cleanup
```

### Linting & shell script validation

```bash
# Lint the main harness
shellcheck scripts/escape-room.sh

# Lint all verify scripts
shellcheck scenarios/*/verify.sh

# Lint all scenario-level scripts (if any)
find scenarios/ -name "*.sh" -exec shellcheck {} \;
```

### Smoke-testing a scenario

```bash
# Full scenario smoke test (broken → verify fails → solve → verify passes)
./scripts/escape-room.sh start level-01
./scripts/escape-room.sh verify           # Expected: exits 1 (still broken)
./scripts/escape-room.sh solve
./scripts/escape-room.sh verify           # Expected: exits 0 (escaped)
./scripts/escape-room.sh reset
./scripts/escape-room.sh verify           # Expected: exits 1 (re-broken)
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

# Step 1: Check pod readiness
READY=$(kubectl get pods -n "${NAMESPACE}" -l "${APP_LABEL}" \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")

if [[ "${READY}" != "true" ]]; then
  echo "❌ Pod is not ready. Run: kubectl get pods -n ${NAMESPACE}"
  exit 1
fi

# Step 2: In-cluster HTTP probe
kubectl run verify-probe-$$ \
  --image=curlimages/curl:latest \
  --restart=Never \
  --rm \
  -it \
  -n "${NAMESPACE}" \
  -- curl -fsS --max-time 5 "${SERVICE_URL}" > /dev/null

echo "✅ Level XX complete! You escaped!"
exit 0
```

---

## Agent Behaviour Guidelines

These rules apply to any AI agent (Antigravity, Copilot, etc.) working in this repo:

### Before writing any code

1. Re-read [`docs/design/plan.md`](docs/design/plan.md) for the milestone you are implementing.
2. Check whether the target directory already exists — **never overwrite existing verified files** without explicit user instruction.
3. Confirm the correct namespace for the level you are building.

### When implementing

4. Implement **one milestone at a time** unless explicitly instructed otherwise.
5. After every file created, run `shellcheck` on any `.sh` file. Fix all `SC*` warnings before proceeding.
6. After applying broken manifests, validate the failure mode with `kubectl get pods -n <namespace>` before moving on.
7. After applying solution manifests, run `./scripts/escape-room.sh verify` and confirm exit code `0`.

### When making changes

8. **Never modify `scripts/escape-room.sh` without also updating the corresponding section in this `AGENTS.md`.**
9. **Never modify a `verify.sh` to make it pass without fixing the underlying scenario bug.**
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

---

## Human Review Gates

The human (repo owner) must review and explicitly approve before an agent proceeds past these checkpoints:

| Gate | Trigger | What to review |
|---|---|---|
| **M1 done** | After `scripts/escape-room.sh` is implemented | All 8 commands work; shellcheck passes; state file updates correctly |
| **M2 done** | After level-01 is implemented | Broken state shows `ImagePullBackOff`; verify fails; solve → verify passes |
| **M3 done** | After level-02 is implemented | Both bugs independently visible; healthz endpoint verifies correctly |
| **M4 done** | After level-03 is implemented | Both misconfiguration bugs visible; end-to-end probe works |
| **M5 done** | After docs are created | Cheatsheet fits one A4 page; checklist covers all attendee prereqs |
| **Pre-event** | 48h before workshop | Full smoke test of all levels on a clean machine |

---

## Gitignore Entries (ensure these exist)

```
.room-state
*.kubeconfig
kubeconfig
.DS_Store
```
