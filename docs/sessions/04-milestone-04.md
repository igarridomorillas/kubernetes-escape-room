# Session 04 — Milestone 4: Level 03: "The Silent Wall"

> **Date:** 2026-10-20  
> **Status:** 🔍 In review (PR merged; human sign-off pending)  
> **PR:** [#6](https://github.com/unai-ttxu/kubernetes-escape-room/pull/6) (`feat/M4`)

---

## 🎯 Objectives

Implement Level 03 ("The Silent Wall") under [`scenarios/level-03-silent-wall/`](../../scenarios/level-03-silent-wall/) in namespace `escape-level-03`. All pods report `Running 1/1`, but the frontend returns `504` / `502` for `GET /api/data` because of two compound faults: a Service port mismatch and a NetworkPolicy label mismatch.

---

## 📦 Deliverables Created

| File | Purpose |
|---|---|
| [`scenarios/level-03-silent-wall/broken/frontend-deployment.yaml`](../../scenarios/level-03-silent-wall/broken/frontend-deployment.yaml) | Frontend nginx (`nginx:1.27-alpine`), pod labelled `role: web-frontend` |
| [`scenarios/level-03-silent-wall/broken/frontend-config.yaml`](../../scenarios/level-03-silent-wall/broken/frontend-config.yaml) | ConfigMap with the frontend proxy (`/api/*` → `backend-service`) |
| [`scenarios/level-03-silent-wall/broken/frontend-service.yaml`](../../scenarios/level-03-silent-wall/broken/frontend-service.yaml) | ClusterIP `frontend-service` port 80 → 80 |
| [`scenarios/level-03-silent-wall/broken/backend-deployment.yaml`](../../scenarios/level-03-silent-wall/broken/backend-deployment.yaml) | Backend nginx listening on **9000** |
| [`scenarios/level-03-silent-wall/broken/backend-config.yaml`](../../scenarios/level-03-silent-wall/broken/backend-config.yaml) | ConfigMap serving `{"data":"backend-connected"}` at `/api/data` on port 9000 |
| [`scenarios/level-03-silent-wall/broken/backend-service.yaml`](../../scenarios/level-03-silent-wall/broken/backend-service.yaml) | ClusterIP `backend-service` port 80 with **`targetPort: 8080`** (bug 1) |
| [`scenarios/level-03-silent-wall/broken/networkpolicy.yaml`](../../scenarios/level-03-silent-wall/broken/networkpolicy.yaml) | `backend-firewall` allowing ingress only from `role: api-consumer` (bug 2) |
| [`scenarios/level-03-silent-wall/solution/`](../../scenarios/level-03-silent-wall/solution/) | Same set with `targetPort: 9000` and the NetworkPolicy selecting `role: web-frontend` |
| [`scenarios/level-03-silent-wall/incident.md`](../../scenarios/level-03-silent-wall/incident.md) | Pager alert `#INC-8103` describing symptoms only |
| [`scenarios/level-03-silent-wall/hints.md`](../../scenarios/level-03-silent-wall/hints.md) | 3 tiered hints (concept → `get ep` / `get netpol` investigation → AI prompt recipe) |
| [`kind/cluster-config.yaml`](../../kind/cluster-config.yaml) | `disableDefaultCNI: true`, explicit pod/service subnets (`10.10.0.0/16`, `10.11.0.0/16`) |
| [`kind/cni/cilium.yaml`](../../kind/cni/cilium.yaml) | Pinned Cilium 1.20.2 manifest (helm-rendered, Hubble enabled) so NetworkPolicy is enforced |
| [`scripts/escape-room.sh`](../../scripts/escape-room.sh) | `setup` installs Cilium and writes `kind/.kube/config`; `KUBECONFIG` pinning; `wait_for_level_rollout` after `start`/`reset`; `solve` warns on a stalled rollout; `cleanup` removes `kind/.kube/` and `.room-state` |
| [`scenarios/level-03-silent-wall/verify.sh`](../../scenarios/level-03-silent-wall/verify.sh) | Pin `KUBECONFIG` to `kind/.kube/config` (also in levels 01–02); rollout check for both Deployments, then a detached in-cluster probe of `/api/data` through the frontend that checks HTTP 200 **and** the backend payload (chmod 750) |

---

## 💡 Key Design Decisions

1. **End-to-end verification:** the probe goes through `frontend-service`, so it only passes when the frontend → backend hop works. A bare HTTP 200 is not enough: the body must contain `"data":"backend-connected"`, read from the probe pod's logs (no shell pipeline needed in the `curlimages/curl` probe).
2. **Frontend proxy uses a runtime resolver:** `proxy_pass` goes through a variable and `resolver kube-dns...`, so nginx does not fail at startup if the backend Service DNS record is not yet visible.
3. **Nginx-only workloads:** both tiers use pinned `nginx:1.27-alpine` with the configuration mounted from a ConfigMap, so no custom image has to be built or loaded into kind.
4. **Fix location for bug 2:** the NetworkPolicy is corrected to select `role: web-frontend` (the frontend's real label) rather than relabelling the frontend, so the policy still expresses the intended "only the frontend may call the backend" rule.
5. **Pinned kubeconfig:** `kind/.kube/config` is written by `kind export kubeconfig` on every `setup` and exported as `KUBECONFIG` by the harness; each `verify.sh` pins it as well. kind still updates `~/.kube/config`, so manual `kubectl` use is unchanged.
6. **Rollout wait helper:** `wait_for_level_rollout` (level-03 only for now) makes `start` and `reset` block until the Deployments are Ready; level 01 must stay broken, so it is skipped.
7. **Hint discipline:** Hints 1–2 name the places to look (Service port vs. container port, policy `from` selector vs. pod labels) without giving the corrected values. Hint 3 is the SRE copilot prompt.

---

## 🔧 Infrastructure & Context Hardening

- **NetworkPolicy enforcement with Cilium CNI:** kind's default CNI (kindnet) does **not** enforce NetworkPolicy, so the cluster uses `networking.disableDefaultCNI: true` and `setup` installs a pinned Cilium 1.20.2 (`kind/cni/cilium.yaml`). See [`plan.md` Amendment 3](../design/plan.md).
- **kubectl context safety:** the harness previously ran `kubectl` against the *current* context, which on the machine used for this session was a remote EKS cluster, so `start level-03` could have applied the broken manifests there. `setup` now writes a repo-local kubeconfig, `kind/.kube/config`, with `kind export kubeconfig` (re-run on every `setup`). The harness exports `KUBECONFIG` to it and each `verify.sh` pins it too, so no `kubectl` call uses the current context. kind still updates `~/.kube/config` as usual. The file is gitignored and removed by `cleanup`.

---

## ✅ Verification & Smoke Test Lifecycle

> Run on a kind cluster with Cilium (default kubeconfig emptied to prove the pinning). The review items below stay unticked until the human approves (AGENTS.md rules 17–18).

Checks that **were** run:

- `shellcheck` clean on `scripts/escape-room.sh` and `scenarios/*/verify.sh`; `bash -n` OK.
- All 14 level-03 manifests parse as YAML; each container has `requests` and `limits`; every object sets `namespace: escape-level-03` and `level: "03"`.
- `setup` twice (idempotent): Cilium and Hubble up, nodes `Ready`; `kind/.kube/` is 700, `config` is 600. `cleanup` removes the cluster and `kind/.kube/`; `status` without the file prints the "run setup" hint.
- Level 03: `verify` 1 broken, 0 after `solve`, 1 after `reset`; fixing only the Service port still fails `verify`.
- After the final refactor (`wait_for_level_rollout`, kubeconfig error handling): level 03 `start`, `reset`, `verify`, `solve` and a level 01 `start` re-run OK.
- Levels 01 and 02: `verify` 1 broken, 0 after `solve`, 1 after `reset`. One level 02 `verify` immediately after `solve` failed once and passed on three repeats (not reproduced; possible timing flake).
- `scripts/escape-room.sh` and the `verify.sh` files are mode `750` (AGENTS.md rule 7).

Not run: the hint renderer (`./scripts/escape-room.sh hint`) on level 03, and a clean-machine `setup` (the pre-event gate).

Checklist for the human reviewer:

- [ ] **Linting**: `shellcheck scenarios/level-03-silent-wall/verify.sh` clean (not run: shellcheck not installed).
- [ ] **Broken state**: `kubectl get ep -n escape-level-03` shows backend endpoints on port `8080`.
- [ ] **Broken state**: `kubectl get netpol -n escape-level-03 -o yaml` shows `role: api-consumer` vs. frontend pod label `role: web-frontend`.
- [ ] **Broken state**: frontend `/api/data` returns `504` / `502` while all pods are `Running 1/1`.
- [ ] **Verification failure**: `./scripts/escape-room.sh verify` exits `1` while broken.
- [ ] **Hints**: `./scripts/escape-room.sh hint` renders Hints 1–3.
- [ ] **Solution**: `./scripts/escape-room.sh solve` applies cleanly; both rollouts reach `1/1`.
- [ ] **Verification success**: `./scripts/escape-room.sh verify` exits `0` after `solve`.
- [ ] **Reset**: `./scripts/escape-room.sh reset` restores broken state and clears the completed mark.
- [ ] **Cilium setup**: `./scripts/escape-room.sh setup` creates the cluster, installs Cilium, and reports all nodes `Ready`.
- [ ] **NetworkPolicy enforced**: on the Cilium cluster, fixing only the port still fails verify (both bugs required).

---

## ⏭️ Next Step

Human review of Milestone 4, including a decision on the NetworkPolicy/CNI gap and the kubectl context pinning. After approval, proceed to **Milestone 5**: AI-assisted troubleshooting best practices (workshop docs follow in Milestone 6).
