# Session 02 — Milestone 2: Level 01: "The Ghost Image"

> **Date:** 2026-10-18  
> **Status:** 🔍 In review (PR merged; human sign-off pending)  
> **PR:** [#4](https://github.com/unai-ttxu/kubernetes-escape-room/pull/4) (`feat/M2`)  

---

## 🎯 Objectives

Implement Level 01 ("The Ghost Image") under `scenarios/level-01-ghost-image/` to serve as the initial warm-up scenario. Attendees diagnose an `ImagePullBackOff` failure on a critical `payment-gateway` deployment in the `escape-level-01` namespace, using kubectl diagnostics, tiered hints, and AI copilots.

---

## 📦 Deliverables Created

| File | Purpose |
|---|---|
| [`scenarios/level-01-ghost-image/broken/deployment.yaml`](../../scenarios/level-01-ghost-image/broken/deployment.yaml) | Deployment manifest specifying non-existent tag `nginx:1.27.99-alpine` |
| [`scenarios/level-01-ghost-image/broken/service.yaml`](../../scenarios/level-01-ghost-image/broken/service.yaml) | ClusterIP Service routing port 80 to backend pods |
| [`scenarios/level-01-ghost-image/solution/deployment.yaml`](../../scenarios/level-01-ghost-image/solution/deployment.yaml) | Reference fix Deployment with valid `nginx:1.27-alpine` image |
| [`scenarios/level-01-ghost-image/solution/service.yaml`](../../scenarios/level-01-ghost-image/solution/service.yaml) | Reference Service matching the deployment |
| [`scenarios/level-01-ghost-image/incident.md`](../../scenarios/level-01-ghost-image/incident.md) | Realistic PagerDuty alert (`#INC-8021`) reporting 0 healthy endpoints |
| [`scenarios/level-01-ghost-image/hints.md`](../../scenarios/level-01-ghost-image/hints.md) | 3-tier progressive hints + AI copilot SRE prompt recipe |
| [`scenarios/level-01-ghost-image/verify.sh`](../../scenarios/level-01-ghost-image/verify.sh) | In-cluster verification probe testing pod readiness and HTTP 200 response (chmod 750) |

---

## 💡 Key Design Decisions & Iterations

1. **Deterministic & Quiet In-Cluster Probing**:
   - `verify.sh` first checks rollout completion via `kubectl rollout status deployment/payment-gateway`, so stale pods from a previous ReplicaSet cannot cause false results.
   - Executes an in-cluster ephemeral probe (pinned `curlimages/curl:8.11.1`) against `http://payment-gateway.escape-level-01.svc.cluster.local:80/`.
   - The probe pod runs detached and its phase is polled (60s max) with a cleanup `trap`; `kubectl run -i --rm` was dropped after the end-to-end test showed it can return exit `0` for a failing curl. `Failed` = endpoint failure, create failure/timeout = probe-pod failure.
   - Idempotent and strictly exits `0` on success, `1` on failure.

2. **Strict Convention Adherence**:
   - Explicit `namespace: escape-level-01` set on all manifests.
   - Workload metadata includes required `app: payment-gateway`, `component: backend`, `level: "01"` labels and resource requests/limits.
   - Script permissions set to `chmod 750` (`-rwxr-x---`).

3. **Progressive AI Pedagogy**:
   - Hint 1 provides the conceptual mechanism (container runtime image pull).
   - Hint 2 provides `kubectl describe pod` and events triage commands without revealing the fix.
   - Hint 3 provides a reusable SRE Copilot Prompt Pattern (Context + Symptom + kubectl output + Goal) for free AI assistants.

4. **Review Hardening** (PR #4 review, see [`plan.md` Amendment 1](../design/plan.md)):
   - Pinned images (`nginx:1.27-alpine` solution, `curlimages/curl:8.11.1` probe) and rollout-based readiness in `verify.sh`.
   - Hint 2 and `incident.md` no longer leak the fix or root cause.
   - Review gates and smoke-test items intentionally left unticked until human review (AGENTS.md rules 17–18).

5. **Harness Improvements** (`scripts/escape-room.sh`):
   - `setup` prints install links for missing `docker`/`kind` and a hint when Docker is not running.
   - `start` and `reset` clear the level from `COMPLETED_LEVELS`; `verify` success matches levels exactly and prints a "What's next?" block.
   - No `next` command by design — `start <level>` is the only way to switch levels.

---

## ✅ Verification & Smoke Test Lifecycle

> An agent-run end-to-end smoke test passed on a local Kind cluster (start → verify 1 → hints 1–3 → solve → verify 0 ×3 → reset → verify 1; completed mark cleared on reset; no leaked probe pods). Items stay unticked until the human reviewer confirms.

- [ ] **Linting**: `shellcheck scenarios/level-01-ghost-image/verify.sh scripts/escape-room.sh` passed with 0 errors/warnings.
- [ ] **Broken State**: `./scripts/escape-room.sh start level-01` injected broken manifests; pods reliably entered `ImagePullBackOff`.
- [ ] **Verification Failure**: `./scripts/escape-room.sh verify` exited with code `1` while broken.
- [ ] **Hint Parsing**: `./scripts/escape-room.sh hint` properly parsed and rendered Hints 1, 2, and 3 sequentially, warning on 4th invocation.
- [ ] **Solution Rollout**: `./scripts/escape-room.sh solve` applied reference fix; deployment rolled out cleanly to `Running 1/1`.
- [ ] **Verification Success**: `./scripts/escape-room.sh verify` passed with code `0` and rendered the celebration banner.
- [ ] **Reset Idempotency**: `./scripts/escape-room.sh reset` restored broken state; subsequent verify failed as expected.

---

## ⏭️ Next Step

Proceed to **Milestone 3**: Level 02 — "The Crashing Config" (`scenarios/level-02-crashing-config/`).
