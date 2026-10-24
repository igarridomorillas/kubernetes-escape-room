# Session 03 — Milestone 3: Level 02: "The Crashing Config"

> **Date:** 2026-10-19  
> **Status:** ✅ Completed & Merged  
> **PR:** [#5](https://github.com/unai-ttxu/kubernetes-escape-room/pull/5) (`feat/M3`)  

---

## 🎯 Objectives

Implement Level 02 ("The Crashing Config") under `scenarios/level-02-crashing-config/`. Attendees debug an `order-processor` Deployment in `escape-level-02` that crash-loops because of two compound bugs: a ConfigMap key mismatch and a `16Mi` memory limit.

---

## 📦 Deliverables Created

| File | Purpose |
|---|---|
| [`scenarios/level-02-crashing-config/app/app.py`](../../scenarios/level-02-crashing-config/app/app.py) | Stdlib-only Python app: checks `DATABASE_URL`, warms a 32MiB cache, serves `/healthz` on 8080 |
| [`scenarios/level-02-crashing-config/app/Dockerfile`](../../scenarios/level-02-crashing-config/app/Dockerfile) | `python:3.12-alpine3.20`, non-root |
| [`scenarios/level-02-crashing-config/broken/`](../../scenarios/level-02-crashing-config/broken/) | ConfigMap with key `DB_CONNECTION_STRING`, Deployment with `16Mi` limit, Service |
| [`scenarios/level-02-crashing-config/solution/`](../../scenarios/level-02-crashing-config/solution/) | ConfigMap with key `DATABASE_URL`, Deployment with `64Mi` limit, Service |
| [`scenarios/level-02-crashing-config/incident.md`](../../scenarios/level-02-crashing-config/incident.md) | Pager alert `#INC-8134`, symptoms only |
| [`scenarios/level-02-crashing-config/hints.md`](../../scenarios/level-02-crashing-config/hints.md) | 3-tier progressive hints + AI prompt recipe |
| [`scenarios/level-02-crashing-config/verify.sh`](../../scenarios/level-02-crashing-config/verify.sh) | Rollout + 15s restart stability + exact `/healthz` body check (chmod 750) |
| [`scripts/escape-room.sh`](../../scripts/escape-room.sh) | `start` now builds and `kind load`s `app/` when a `Dockerfile` exists; mode set to 750 |

---

## 💡 Key Design Decisions & Iterations

1. **`envFrom` instead of `configMapKeyRef`**: a missing key under `configMapKeyRef` gives `CreateContainerConfigError` and no app logs. `envFrom` lets the app start and report `KeyError: 'DATABASE_URL'`.
2. **Both bugs visible at once**: the app logs the config error, then warms the cache, then exits. At `16Mi` the OOM kill hits first (`Exit Code 137`) while the logs still show the `KeyError`. Each bug alone reproduces the other symptom (checked by patching one at a time).
3. **Self-contained image**: built locally and loaded into kind by the harness; no registry. See [`plan.md` Amendment 2](../design/plan.md).
4. **`--previous` caveat**: unreliable on kind during backoff, so Hint 2 leads with plain `kubectl logs`.
5. **Compact JSON**: the app serializes `/healthz` without spaces so the body matches the contract exactly.

---

## ✅ Verification & Smoke Test Lifecycle

Smoke test on a local Kind cluster: `start level-02` → pod `OOMKilled` (137) with `KeyError` in logs → verify exit `1` → memory-only fix shows `KeyError`/`Error` → key-only fix shows `OOMKilled` → `solve` → verify exit `0` (twice) → `reset` → verify exit `1`; `COMPLETED_LEVELS` cleared on reset. `shellcheck` is clean on `scripts/escape-room.sh` and `verify.sh`. Reviewed and merged in PR #5.

- [x] **Broken State**: both failure modes reproducible
- [x] **Independent fixes**: each bug alone leaves the pod failing
- [x] **Verification**: fails while broken, passes after `solve`, idempotent
- [x] **Reset**: restores the broken state and clears the completed mark

---

## ⏭️ Next Step

Proceed to **Milestone 4**: Level 03 — "The Silent Wall" (`scenarios/level-03-silent-wall/`).
