# 🚀 Kubernetes Escape Room — Implementation Milestones

> **Timeline:** 6 milestones across the full implementation

---

## Overview

```
M1: Core Harness & Cluster Setup
  └── M2: Level 01 — The Ghost Image ──────────┐
  └── M3: Level 02 — The Crashing Config ──────┼──► M5: AI Troubleshooting Best Practices
  └── M4: Level 03 — The Silent Wall ──────────┤          └── M6: Workshop Docs & Pre-Event Readiness
  └── Bonus: Level 04 — Ghost Microservices ───┘
```

---

## Milestone 1 — Core Harness & Cluster Setup

**Status:** ✅ Complete (PR #2 merged)

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
- [x] `./scripts/escape-room.sh setup` creates cluster and verifies `kubectl` connectivity
- [x] `./scripts/escape-room.sh start level-01` applies broken manifests to `escape-level-01` namespace
- [x] State file updates correctly on every command
- [x] All commands are idempotent (can re-run without error)
- [x] Script passes `shellcheck scripts/escape-room.sh`

---

## Milestone 2 — Level 01: "The Ghost Image" (Warm-up)

**Status:** 🔍 In review (PR #4 merged; human sign-off pending)  
**Namespace:** `escape-level-01`  
**Duration target:** 8–10 min

**Bug:** `image: nginx:1.27.99-alpine` (non-existent tag)  
**Symptom:** `ImagePullBackOff`

**Deliverables:**
```
scenarios/level-01-ghost-image/
├── broken/          # Manifest with bad image tag
├── solution/        # Fixed manifest (nginx:1.27-alpine)
├── incident.md      # Realistic PagerDuty-style alert
├── hints.md         # 3 tiered hints + AI prompt recipe
├── ai-assist.md     # AI copilot tip (added in M5)
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

**Status:** 🔍 In review (PR #5 merged; human sign-off pending)  
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
├── ai-assist.md     # AI copilot tip (added in M5)
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

**Status:** 🔍 In review (PR #6 merged; human sign-off pending)  
**Namespace:** `escape-level-03`  
**Duration target:** 15–20 min

**Bugs (compound):**
1. Backend Service `targetPort: 8080` but container listens on `9000`
2. `NetworkPolicy` allows ingress from `role: api-consumer` but Frontend Pod is labeled `role: web-frontend`

**Symptom:** All pods `Running 1/1`, but `curl` frontend → backend returns `504` / `502`

**Deliverables:**
```
scenarios/level-03-silent-wall/
├── broken/          # Mismatched targetPort + wrong NetworkPolicy label
├── solution/        # Aligned port + corrected NetworkPolicy
├── incident.md
├── hints.md
├── ai-assist.md     # AI copilot tip (added in M5)
└── verify.sh        # Curls /api/data through frontend → {"data":"backend-connected"}
```

**Prerequisite (Amendment 3 in `docs/design/plan.md`):** NetworkPolicy is only enforced with Cilium, which `setup` installs from `kind/cni/cilium.yaml` (clusters created with kindnet must be recreated).

**Verification contract:**
1. Probe pod in `escape-level-03` curls `http://frontend-service.escape-level-03.svc.cluster.local:80/api/data`
2. Returns `HTTP 200` with body `{"data":"backend-connected"}`

**Review checklist (human must approve before M5 starts):**
- [ ] `kubectl get ep -n escape-level-03` shows wrong port in broken state
- [ ] `kubectl get netpol -n escape-level-03 -o yaml` reveals label mismatch in broken state
- [ ] Both bugs must be fixed for `verify.sh` to pass
- [ ] `verify.sh` tests the full end-to-end path (not just individual services)

---

## Bonus — Level 04: "The Ghost in the Microservices"

**Status:** 🔍 In review (PR #9 merged; human sign-off pending)  
**Namespace:** `escape-level-04`  
**Duration target:** 15–20 min (optional bonus)

**Bug:** 3-tier checkout pipeline (`gateway` → `cart` → `payment`) where `Deployment/payment` injects `COUPON_VALIDATOR_URI` instead of `COUPON_VALIDATOR_URL` from `ConfigMap/payment-config`, causing `payment` to throw an unhandled `NullPointerException` on `"coupon"` transactions buried inside 5,000 lines of standard `INFO` log traffic.  
**Symptom:** All pods `Running 1/1` (`/healthz` passing) and standard card payments return `HTTP 200`, but `"coupon"` checkouts return `HTTP 500` cascading back through `cart` and `gateway`.

**Deliverables:**
```
scenarios/level-04-ghost-microservices/
├── app/             # Self-contained 3-tier Python/Alpine app (gateway, cart, payment)
├── broken/          # 3-tier manifests with COUPON_VALIDATOR_URI env mismatch on payment
├── solution/        # Aligned COUPON_VALIDATOR_URL env mapping on payment Deployment
├── incident.md
├── hints.md
├── ai-assist.md
└── verify.sh        # Sends 10 diverse synthetic checkout payloads through gateway (all HTTP 200)
```

**Verification contract:**
1. All three Deployments (`gateway`, `cart`, `payment`) in `escape-level-04` rolled out and Ready
2. Detached probe pod sends 10 diverse synthetic `POST /checkout` transactions through `gateway` (including `credit_card`, `debit_card`, `apple_pay`, `paypal`, `wallet`, `bank_transfer`, and `coupon`); all 10 return `HTTP 200` with `"payment":"approved"`

**Review checklist (human must approve):**
- [ ] App is self-contained (built and loaded into kind by `start level-04` without external registry)
- [ ] `payment` emits 5,000 log lines with the `"coupon"` `NullPointerException` buried inside standard log traffic
- [ ] Standard healthchecks and non-coupon transactions pass in the broken state while `"coupon"` returns `HTTP 500`
- [ ] `verify.sh` fails in the broken state, passes after `solve`, and fails again after `reset`

---

## Milestone 5 — AI-Assisted Troubleshooting Best Practices

**Status:** 🔍 In review (PR #8 merged; human sign-off pending)  
**Depends on:** M1–M4 complete (or near-complete)

**Goal:** Teach a repeatable, evidence-based way to use LLMs during an incident, from web copilots up to tool-connected workflows (MCP, CLI agents such as opencode). Web copilots remain the baseline (D1/D4); MCP and CLI agents are **optional** and must not be assumed available.

**Deliverables:**
```
docs/
├── ai-prompts-cheatsheet.md    # Extended: workflow, stage prompts, guardrails, evaluation rubric
├── ai-research-notes.md        # Cited sources (links + dates), established vs emerging practices
└── ai-exercises.md             # Instructor guide: bad vs good prompts per level, challenge exercise, facilitator notes
scenarios/*/ai-assist.md        # Attendee AI tip per level, shown by `./scripts/escape-room.sh ai-assist`
# Facilitator notes live in ai-exercises.md, not hints.md (the hint command prints everything under a hint heading)
```

**Must cover:**
- A repeatable workflow grounded in logs, events, metrics, manifests and recent changes (summarize evidence → hypothesize → decide next check → verify → communicate)
- Example prompts per stage, incl. how to give context and ask for evidence-based, uncertainty-aware answers
- At least one exercise to **challenge an AI-generated hypothesis** and correct it with new evidence (with facilitator notes and expected findings)
- **MCP integration:** a Kubernetes MCP server, read-only by default, scoped to the repo-local kubeconfig (`kind/.kube/config`); what it adds over copy-paste
- **CLI agents (opencode and similar):** tool-agnostic usage, permission modes, review before running commands
- Strengths and failure modes of chat assistance, retrieval over runbooks, and agentic workflows
- Guardrails: AI output is a hypothesis; verify against cluster evidence; humans own decisions; no secrets or sensitive incident data; logs/events are untrusted input (prompt injection); no destructive or privileged actions without explicit review
- Evaluating whether AI helped: correctness, time to useful evidence, missed signals, unsafe or unsupported recommendations

**Constraints:**
- No new runtime dependencies in `scripts/escape-room.sh` or `verify.sh`; MCP/CLI-agent setup stays out of the harness
- Claims in research notes cite credible primary sources with publication dates; unverified items are flagged
- Any harness change updates `AGENTS.md` (rule 8); design changes go in `docs/design/plan.md` (rule 10)

**Review checklist (human must approve before M6 starts):**
- [ ] All cited links resolve and dates are accurate
- [ ] Established practices are clearly separated from emerging ideas
- [ ] The challenge-the-hypothesis exercise has facilitator notes and expected findings
- [ ] Guardrails section covers all six rules above
- [ ] MCP / opencode steps were tested, or are explicitly flagged as untested
- [ ] Workflow is coherent with the existing level hints (Concept → Investigation → AI prompt)

---

## Milestone 6 — Workshop Docs & Pre-Event Readiness

**Status:** ⬜ Not started  
**Depends on:** M5 complete

**Deliverables:**
```
docs/
├── ai-prompts-cheatsheet.md    # One-page A4 condensed version of the M5 content
└── pre-workshop-checklist.md   # Instructor setup & attendee prereqs
```

**`pre-workshop-checklist.md` must cover:**
- Instructor pre-event: cluster creation, image availability, level smoke-tests
- Attendee prereqs: `kubectl`, `kind`, Docker Desktop; optional MCP server / opencode setup
- Fallback options if local cluster fails, or if MCP/CLI agents are unavailable (web copilot path)

**Cheatsheet one-pager must keep:**
- The **SRE Copilot Prompt Pattern**: `Context + Symptom + kubectl output + Desired State`
- How to extract clean `kubectl logs` / `describe` output for web AI copilots
- Common AI hallucinations in Kubernetes (e.g., `hostNetwork: true`, deleting NetworkPolicies)
- The guardrails in short form

**Review checklist (final human gate before event):**
- [ ] Cheatsheet fits on one printed A4 page
- [ ] Hallucination section is clearly marked and pedagogically grounded
- [ ] Pre-workshop checklist can be followed by a non-SRE
- [ ] All docs reviewed for accuracy against the final implemented scenarios

---

## Decision Log

| Decision | Selected Option | Rationale |
|---|---|---|
| **Model Hosting** | Web Copilots, CLI Agents & Agentic Harnesses (Gemini, ChatGPT, Claude, OpenCode, MCP) | No local model VRAM/RAM constraints; flexible setup for 40 attendees |
| **Harness Tech** | Pure POSIX Bash (`scripts/escape-room.sh`) | Runs out-of-the-box on macOS and Linux; no Python/jq |
| **Scenario Sizing** | 3 Core + 1 Bonus | Tuned for 40–50 min collaborative pairing |
| **Verification** | In-cluster synthetic probes | Idempotent, binary feedback (Escaped / Still Trapped) |
| **AI Tooling Tiers** | Web copilot baseline; MCP and CLI agents (e.g. opencode) optional, read-only by default | Keeps zero-setup path for all attendees while teaching tool-connected workflows safely |
| **Milestone Split** | M5 = AI best practices, M6 = docs & readiness | Research-heavy AI content needs its own review gate before final docs are condensed |
