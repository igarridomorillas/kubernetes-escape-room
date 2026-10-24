# Session 06 — Bonus Level 04: "The Ghost in the Microservices"

> **Date:** 2026-10-24  
> **Status:** ✅ Completed & Merged  
> **PR:** [#9](https://github.com/unai-ttxu/kubernetes-escape-room/pull/9) (`feat/level-04`)

---

## 🎯 Objectives

Implement Bonus Level 04 ("The Ghost in the Microservices") under [`scenarios/level-04-ghost-microservices/`](../../scenarios/level-04-ghost-microservices/) in namespace `escape-level-04`. Attendees debug intermittent `HTTP 500` checkout errors across a 3-tier microservice chain (`gateway` → `cart` → `payment`) where all pods report `Running 1/1` and `/healthz` passes, but `"coupon"` transactions trigger an unhandled `NullPointerException` buried inside 5,000 lines of standard log traffic.

---

## 📦 Deliverables Created

| File | Purpose |
|---|---|
| [`scenarios/level-04-ghost-microservices/app/app.py`](../../scenarios/level-04-ghost-microservices/app/app.py) | Stdlib-only Python app running as `gateway`, `cart`, or `payment` via `SERVICE_ROLE`; emits 5,000 log lines on `payment` startup |
| [`scenarios/level-04-ghost-microservices/app/Dockerfile`](../../scenarios/level-04-ghost-microservices/app/Dockerfile) | Pinned `python:3.12-alpine3.20`, non-root (`65534:65534`) |
| [`scenarios/level-04-ghost-microservices/broken/`](../../scenarios/level-04-ghost-microservices/broken/) | Deployments & Services for `gateway`, `cart`, `payment`, plus `ConfigMap/payment-config`; `Deployment/payment` maps `COUPON_VALIDATOR_URI` instead of `COUPON_VALIDATOR_URL` |
| [`scenarios/level-04-ghost-microservices/solution/`](../../scenarios/level-04-ghost-microservices/solution/) | Reference manifests with `COUPON_VALIDATOR_URL` aligned on `Deployment/payment` |
| [`scenarios/level-04-ghost-microservices/incident.md`](../../scenarios/level-04-ghost-microservices/incident.md) | Pager alert `#INC-8192`, symptoms only |
| [`scenarios/level-04-ghost-microservices/hints.md`](../../scenarios/level-04-ghost-microservices/hints.md) | 3-tier progressive hints (concept → `kubectl logs` + `grep` investigation → SRE Copilot prompt recipe) |
| [`scenarios/level-04-ghost-microservices/ai-assist.md`](../../scenarios/level-04-ghost-microservices/ai-assist.md) | Spoiler-audited AI copilot guide for call-chain tracing and log haystack filtering |
| [`scenarios/level-04-ghost-microservices/verify.sh`](../../scenarios/level-04-ghost-microservices/verify.sh) | Rollout check for `gateway`, `cart`, `payment` + detached in-cluster probe sending 10 diverse synthetic checkout payloads (`chmod 750`) |
| [`scripts/escape-room.sh`](../../scripts/escape-room.sh) | `wait_for_level_rollout` extended to wait for `payment`, `cart`, and `gateway` on `level-04`; usage updated (`chmod 750`) |
| [`AGENTS.md`](../../AGENTS.md), [`README.md`](../../README.md), [`docs/design/plan.md`](../design/plan.md), [`docs/ai-exercises.md`](../ai-exercises.md), [`docs/ai-prompts-cheatsheet.md`](../ai-prompts-cheatsheet.md) | Synchronized directory trees, harness docs, Amendment 6, and Level 04 AI exercise notes |

---

## 💡 Key Design Decisions

1. **Single self-contained image for all 3 tiers**: `start level-04` builds `scenarios/level-04-ghost-microservices/app/` once as `escape-room/level-04-app:1.0.0` and loads it into kind. Each Deployment sets `SERVICE_ROLE` (`gateway`, `cart`, or `payment`).
2. **5,000-line log haystack**: On startup, `payment` emits exactly 5,000 lines of structured checkout logs. In the broken state, 3 intermittent `"coupon"` transactions (5 lines each) are buried at indices 1,250, 2,750, and 4,150, followed by ~850 healthy `INFO` lines so naive `kubectl logs --tail=30` misses the exception.
3. **Immediate rollout on manifest fix**: `ConfigMap/payment-config` defines `COUPON_VALIDATOR_URL`, while `broken/payment-deployment.yaml` injects it under the misnamed container env var `COUPON_VALIDATOR_URI`. Because the fix is in `Deployment/payment`, both `kubectl edit`/`patch`/`set env` and `./scripts/escape-room.sh solve` (`kubectl apply -f solution/`) immediately trigger a Pod rollout without needing a manual `kubectl rollout restart`.
4. **End-to-end 10-transaction verification**: `verify.sh` runs a single detached `curlimages/curl:8.11.1` probe pod that sends 10 diverse `POST /checkout` payloads (`credit_card`, `debit_card`, `coupon`, `apple_pay`, `paypal`, `wallet`, `bank_transfer`) through `gateway` and checks both `HTTP 200` and `"payment":"approved"`.

---

## ✅ Verification & Smoke Test Lifecycle

> Run on the local `escape-room` Kind cluster and reviewed/merged in PR #9.

Checks run:
- `shellcheck` passed with 0 warnings on `scripts/escape-room.sh` and `scenarios/*/verify.sh`.
- `./scripts/escape-room.sh start level-04`: built and loaded `escape-room/level-04-app:1.0.0`, rolled out `payment`, `cart`, `gateway` to `1/1 Running`.
- `./scripts/escape-room.sh verify` (broken state): exited `1` reporting `tx-03 (coupon) -> HTTP 500`.
- `./scripts/escape-room.sh ai-assist` and `./scripts/escape-room.sh hint` (Hints 1, 2, 3): rendered cleanly; `ai-assist.md` spoiler-audited.
- `./scripts/escape-room.sh solve` → `./scripts/escape-room.sh verify`: exited `0` (`10/10` synthetic transactions passed).
- `./scripts/escape-room.sh reset` → `./scripts/escape-room.sh verify`: exited `1` and cleared `level-04` from `COMPLETED_LEVELS`.
- Permissions verified (`chmod 750` on `scripts/escape-room.sh` and `scenarios/level-04-ghost-microservices/verify.sh`).

Review checklist:
- [x] **Linting**: `shellcheck scripts/escape-room.sh scenarios/level-04-ghost-microservices/verify.sh` clean
- [x] **Broken State**: all 3 deployments `Running 1/1`; `kubectl logs -n escape-level-04 deployment/payment | wc -l` outputs `5000` with `NullPointerException` on `payment_method=coupon`
- [x] **Verification Failure**: `./scripts/escape-room.sh verify` exits `1` while broken
- [x] **Hints & AI Assist**: `./scripts/escape-room.sh hint` (1–3) and `./scripts/escape-room.sh ai-assist` render cleanly without spoilers
- [x] **Solution & Verification Success**: `./scripts/escape-room.sh solve` rolls out `payment` and `./scripts/escape-room.sh verify` exits `0`
- [x] **Reset**: `./scripts/escape-room.sh reset` restores broken state, clears `COMPLETED_LEVELS`, and `verify` exits `1`

---

## ⏭️ Next Step

Proceed to **Milestone 6**: Workshop Docs & Pre-Event Readiness (`docs/pre-workshop-checklist.md` and condensing `docs/ai-prompts-cheatsheet.md` to one A4 page).
