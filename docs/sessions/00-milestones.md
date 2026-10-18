# 🚀 Kubernetes Escape Room — Implementation Milestones

> **Timeline:** 5 milestones across the full implementation

---

## Overview

```
M1: Core Harness & Cluster Setup
  └── M2: Level 01 — The Ghost Image ──┐
  └── M3: Level 02 — The Crashing Config ──┼──► M5: Workshop Docs & AI Cheatsheet
  └── M4: Level 03 — The Silent Wall ──┘
```

---

## Milestone 1 — Core Harness & Cluster Setup

**Status:** ✅ Done — awaiting human review

**Deliverables:**
- `kind/cluster-config.yaml` — Kind cluster with port forwards `8080:30080` and `8443:30443`
- `scripts/escape-room.sh` — Executable Bash script (zero external deps, pure POSIX Bash)
- `.room-state` — State file tracking `CURRENT_LEVEL`, `HINT_LEVEL`, `COMPLETED_LEVELS`

**`./scripts/escape-room.sh` commands to implement:**

| Command | Behaviour |
|---|---|
| `./scripts/escape-room.sh setup` | Checks docker, creates kind cluster `escape-room` |
| `./scripts/escape-room.sh start <level>` | Resets namespace, applies broken manifests, shows incident alert |
| `./scripts/escape-room.sh status` | Shows active scenario, pod statuses, troubleshooting commands |
| `./scripts/escape-room.sh hint` | Displays next progressive hint (1 → 2 → 3) |
| `./scripts/escape-room.sh verify` | Runs `verify.sh`, prints ASCII celebration banner if fixed |
| `./scripts/escape-room.sh solve` | Applies reference solution (instructor/emergency only) |
| `./scripts/escape-room.sh reset` | Re-injects current level's broken state |
| `./scripts/escape-room.sh cleanup` | Tears down the kind cluster |

**Constraints:**
- No `jq`, no Python, no external runtime deps
- ANSI color-coded output and clear status banners
- State persisted to `.room-state` as plain INI text

**Review checklist (human must approve before M2/M3/M4 start):**
- [ ] `./scripts/escape-room.sh setup` creates cluster and verifies `kubectl` connectivity
- [ ] `./scripts/escape-room.sh start level-01` applies broken manifests to `escape-level-01` namespace
- [ ] State file updates correctly on every command
- [ ] All commands are idempotent (can re-run without error)
- [ ] Script passes `shellcheck scripts/escape-room.sh`

---

## Milestone 2 — Level 01: "The Ghost Image" (Warm-up)

**Status:** ⬜ Not started  
**Namespace:** `escape-level-01`  
**Duration target:** 8–10 min

**Bug:** `image: nginx:1.27.99-alpine` (non-existent tag)  
**Symptom:** `ImagePullBackOff`

**Deliverables:**
```
scenarios/level-01-ghost-image/
├── broken/          # Manifest with bad image tag
├── solution/        # Fixed manifest (nginx:alpine)
├── incident.md      # Realistic PagerDuty-style alert
├── hints.md         # 3 tiered hints + AI prompt recipe
└── verify.sh        # Probe: pod Running + HTTP 200
```

**Verification contract:**
1. Pod with `app=payment-gateway` in `Running` state, `Ready: 1/1`
2. In-cluster curl to `http://payment-gateway.escape-level-01.svc.cluster.local:80/` → `HTTP 200`
3. `verify.sh` exits `0` on pass, `1` on fail

**Review checklist (human must approve before M5 starts):**
- [ ] `broken/` manifests reproducibly cause `ImagePullBackOff`
- [ ] `solution/` applies cleanly and brings pod to `Running`
- [ ] `hints.md` has all 3 tiers (Conceptual → kubectl → AI Prompt)
- [ ] `verify.sh` runs idempotently from inside the cluster
- [ ] `incident.md` reads like a real pager alert

---

## Milestone 3 — Level 02: "The Crashing Config" (Core)

**Status:** ⬜ Not started  
**Namespace:** `escape-level-02`  
**Duration target:** 12–15 min

**Bugs (compound):**
1. ConfigMap key mismatch — app expects `DATABASE_URL`, ConfigMap has `DB_CONNECTION_STRING`
2. Memory limit `16Mi` → OOMKilled (Exit Code 137)

**Symptom:** Pod cycling between `CrashLoopBackOff`, `Error`, `OOMKilled`

**Deliverables:**
```
scenarios/level-02-crashing-config/
├── app/             # Lightweight Python/Alpine app reading DATABASE_URL
├── broken/          # Bad ConfigMap key + 16Mi memory limit
├── solution/        # Fixed key name + 64Mi memory limit
├── incident.md
├── hints.md
└── verify.sh        # /healthz returns {"status":"healthy","database":"connected"}
```

**Verification contract:**
1. Pod `Running`, `Ready: 1/1`, restart count stable for ≥15 seconds
2. `http://order-processor.escape-level-02.svc.cluster.local:8080/healthz` → `{"status":"healthy","database":"connected"}`

**Review checklist (human must approve before M5 starts):**
- [ ] App is self-contained (loadable into kind without pushing to external registry)
- [ ] `broken/` reliably shows both failure modes (key error in logs AND OOMKill)
- [ ] `solution/` fixes both bugs independently and together
- [ ] `verify.sh` waits for stable restart count before declaring success

---

## Milestone 4 — Level 03: "The Silent Wall" (Boss Level)

**Status:** ⬜ Not started  
**Namespace:** `escape-level-03`  
**Duration target:** 15–20 min

**Bugs (compound):**
1. Backend Service `targetPort: 8080` but container listens on `9000`
2. `NetworkPolicy` allows ingress from `role: api-consumer` but Frontend Pod is labeled `role: web-frontend`

**Symptom:** All pods `Running 1/1`, but `curl` frontend → backend returns `502` / times out

**Deliverables:**
```
scenarios/level-03-silent-wall/
├── broken/          # Mismatched targetPort + wrong NetworkPolicy label
├── solution/        # Aligned port + corrected NetworkPolicy
├── incident.md
├── hints.md
└── verify.sh        # Curls /api/data through frontend → {"data":"backend-connected"}
```

**Verification contract:**
1. Probe pod in `escape-level-03` curls `http://frontend-service.escape-level-03.svc.cluster.local:80/api/data`
2. Returns `HTTP 200` with body `{"data":"backend-connected"}`

**Review checklist (human must approve before M5 starts):**
- [ ] `kubectl get ep -n escape-level-03` shows wrong port in broken state
- [ ] `kubectl get netpol -n escape-level-03 -o yaml` reveals label mismatch in broken state
- [ ] Both bugs must be fixed for `verify.sh` to pass
- [ ] `verify.sh` tests the full end-to-end path (not just individual services)

---

## Milestone 5 — Workshop Docs & AI Cheatsheet

**Status:** ⬜ Not started  
**Depends on:** M1–M4 complete (or near-complete)

**Deliverables:**
```
docs/
├── ai-prompts-cheatsheet.md    # SRE Copilot Prompt Pattern + hallucination warnings
└── pre-workshop-checklist.md   # Instructor setup & attendee prereqs
```

**`ai-prompts-cheatsheet.md` must cover:**
- The **SRE Copilot Prompt Pattern**: `Context + Symptom + kubectl output + Desired State`
- How to extract clean `kubectl logs` / `describe` output for web AI copilots
- Common AI hallucinations in Kubernetes (e.g., `hostNetwork: true`, deleting NetworkPolicies)
- Per-level prompt recipe examples

**`pre-workshop-checklist.md` must cover:**
- Instructor pre-event: cluster creation, image availability, level smoke-tests
- Attendee prereqs: `kubectl`, `kind`, Docker Desktop / Colima
- Fallback options if local cluster fails

**Review checklist (final human gate before event):**
- [ ] Cheatsheet fits on one printed A4 page
- [ ] Hallucination section is clearly marked and pedagogically grounded
- [ ] Pre-workshop checklist can be followed by a non-SRE
- [ ] All docs reviewed for accuracy against the final implemented scenarios

---

## Decision Log

| Decision | Selected Option | Rationale |
|---|---|---|
| **Model Hosting** | Free Web/CLI Copilots (Gemini, ChatGPT, Claude) | No VRAM/RAM constraints; zero setup friction for 40 attendees |
| **Harness Tech** | Pure POSIX Bash (`scripts/escape-room.sh`) | Runs out-of-the-box on macOS and Linux; no Python/jq |
| **Scenario Sizing** | 3 Core + 1 Bonus | Tuned for 40–50 min collaborative pairing |
| **Verification** | In-cluster synthetic probes | Idempotent, binary feedback (Escaped / Still Trapped) |
