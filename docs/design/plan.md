# Kubernetes Escape Room: Architecture & Implementation Playbook
## Ready for CLI Agent Execution

**Audience:** Platform, SRE, and Software Engineers (40–50 min hands-on collaborative session)

---

## 1. Architectural Decisions & System Contracts

### D1: Automation Harness Dependency Policy
- **Contract:** Pure POSIX Bash (`#!/usr/bin/env bash`). Zero external runtime dependencies beyond standard macOS/Linux utilities (`curl`, `awk`, `sed`, `grep`).
- **No `jq` or Python requirement** for the core runner to avoid local attendee environment failures.
- Cluster state tracked via a local plain-text file `.room-state` containing `CURRENT_LEVEL` and `HINT_COUNT`.

### D2: Multi-Tenancy & Namespace Isolation
- Each scenario runs in its own dedicated namespace: `escape-level-01`, `escape-level-02`, `escape-level-03`, `escape-level-04`.
- **Benefit:** Resetting or breaking one level never affects other levels, and resources can be inspected independently.

### D3: Deterministic Verification Probes
- Every scenario includes an idempotent `verify.sh` returning exit code `0` on success, `1` on failure.
- Probes run via an ephemeral in-cluster probe (`curlimages/curl` or `kubectl exec`), avoiding localhost network routing/firewall quirks on different OS environments.
- Verification outputs an explicit status message:
  - If failing: actionable feedback on what symptom is still occurring (without giving away the root cause).
  - If passing: prints a unique ASCII badge and congratulatory flag.

### D4: Zero-API AI Pedagogy ("AI as Copilot, Not Autopilot")
- Attendees use free browser copilots (Gemini free, ChatGPT, Claude) or CLI tools.
- Each scenario teaches a specific **prompt engineering pattern for incident response**:
  1. *Level 1 (Logs & Events):* Parsing cryptic Kubernetes status events (`describe pod`).
  2. *Level 2 (Stack Traces & Exit Codes):* Analyzing container exit codes (137 OOM vs 1) and crash logs.
  3. *Level 3 (Topology & Packet Drops):* Providing multi-resource manifests (Service + NetworkPolicy + Pod) to correlate disconnected resources.
  4. *Pedagogical Warning:* Demonstrate where AI hallucinates (e.g., suggesting insecure workarounds like `hostNetwork: true` or deleting security policies) and why human SRE judgment is critical.

---

## 2. Detailed Scenario Specifications

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            SCENARIO PROGRESSION                                 │
│                                                                                 │
│  [Level 01: 8-10 min]    ──► [Level 02: 12-15 min]   ──► [Level 03: 15-20 min]  │
│  "The Ghost Image"           "The Crashing Config"       "The Silent Wall"      │
│  ImagePullBackOff / Typo     CrashLoopBackOff / OOM      NetworkPolicy / EP     │
│                                                                                 │
│                        [Optional Bonus: Level 04]                               │
│                        "The Ghost in the Microservices"                         │
│                        Cascading 500 / Log Haystack                             │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### Level 01: "The Ghost Image" (Warm-up)

- **Simulated Incident:** Pager alert: *"CRITICAL: payment-gateway service in escape-level-01 is reporting 0 healthy endpoints."*
- **Intentional Bug:** Deployment manifest specifies `image: nginx:1.27.99-alpine` (a non-existent tag) or `nginx:alpne` (typo).
- **Attendee Symptoms:**
  - `kubectl get pods -n escape-level-01` shows status `ErrImagePull` $\to$ `ImagePullBackOff`.
- **Verification Logic (`verify.sh`):**
  1. Pod in `escape-level-01` with label `app=payment-gateway` must be in `Running` state and `Ready: 1/1`.
  2. In-cluster curl to `http://payment-gateway.escape-level-01.svc.cluster.local:80/` returns `HTTP 200`.
- **Tiered Hints:**
  - *Hint 1 (Conceptual):* The container runtime cannot start your application. Where does Kubernetes download container files from?
  - *Hint 2 (Kubernetes):* Run `kubectl describe pod -n escape-level-01 -l app=payment-gateway` and read the `Events:` section at the bottom.
  - *Hint 3 (AI Prompt):* 
    > *"I have a Kubernetes Pod stuck in ImagePullBackOff. Here is the output of `kubectl describe pod`: `<paste describe output>`. What is the exact reason for the failure and what `kubectl` command or YAML change will fix it?"*

---

### Level 02: "The Crashing Config" (Core)

- **Simulated Incident:** Pager alert: *"CRITICAL: order-processor service in escape-level-02 is constantly restarting (CrashLoopBackOff). Order queue backlog rising."*
- **Intentional Bug (Compound):**
  1. The container requires an environment variable `DATABASE_URL` referenced from a ConfigMap `order-config`, but the key in the ConfigMap is named `DB_CONNECTION_STRING` (key mismatch).
  2. Memory limit is set to an aggressive `16Mi`, causing Python/Go to get `OOMKilled` (Exit Code 137) during initialization.
- **Attendee Symptoms:**
  - Pod status flips between `CrashLoopBackOff`, `Error`, and `OOMKilled`.
  - `kubectl logs -n escape-level-02 <pod>` shows `KeyError: 'DATABASE_URL'` or memory termination.
- **Verification Logic (`verify.sh`):**
  1. Pod must be `Running` with `Ready: 1/1` and restart count remaining stable for at least 15 seconds.
  2. Synthetic health endpoint `http://order-processor.escape-level-02.svc.cluster.local:8080/healthz` returns `{"status":"healthy","database":"connected"}`.
- **Tiered Hints:**
  - *Hint 1 (Conceptual):* The pod is crashing after launch. Is it failing its internal code checks or being killed by the Linux kernel?
  - *Hint 2 (Kubernetes):* Check both `kubectl logs -n escape-level-02 -l app=order-processor --previous` and `kubectl describe pod -n escape-level-02` (look at `Last State: Terminated` and `Exit Code`).
  - *Hint 3 (AI Prompt):*
    > *"My Kubernetes Pod is in CrashLoopBackOff with Exit Code 1. Here are the last 30 lines of container logs: `<paste logs>` and here is the pod resource specification: `<paste yaml>`. What caused the crash and how do I fix the ConfigMap/Deployment?"*

---

### Level 03: "The Silent Wall" (Boss Level)

- **Simulated Incident:** Pager alert: *"CRITICAL: frontend-api is returning 502 Bad Gateway to end users. All pods are reporting Running 1/1."*
- **Intentional Bug:**
  1. Frontend Pod and Backend Pod are both healthy (`Running 1/1`).
  2. Backend Service has `spec.ports[0].targetPort: 8080`, but the Backend container listens on port `9000`.
  3. A strict `NetworkPolicy` (`backend-firewall`) was applied that only allows ingress from pods labeled `role: api-consumer`, but Frontend Pod is labeled `role: web-frontend`.
- **Attendee Symptoms:**
  - `kubectl get pods -n escape-level-03` shows everything green (`Running`).
  - Executing curl from Frontend pod to Backend times out or returns `502`.
- **Verification Logic (`verify.sh`):**
  1. Probe pod runs inside `escape-level-03`: `curl -fsS http://frontend-service.escape-level-03.svc.cluster.local:80/api/data`.
  2. Returns `HTTP 200` with payload `{"data":"backend-connected"}`.
- **Tiered Hints:**
  - *Hint 1 (Conceptual):* All pods are running, yet communication between them is failing. Inspect the routing layer (Services and Network Policies).
  - *Hint 2 (Kubernetes):* Check `kubectl get ep -n escape-level-03` (are Endpoints pointing to the right port?) and `kubectl get netpol -n escape-level-03 -o yaml`.
  - *Hint 3 (AI Prompt):*
    > *"In my Kubernetes cluster, Pod A cannot communicate with Pod B. Both pods are Running. Here is the Service YAML: `<paste service>`, Pod B YAML: `<paste pod>`, and NetworkPolicy YAML: `<paste netpol>`. Why is traffic being dropped and how do I fix the NetworkPolicy and Service?"*

---

### Level 04: "The Ghost in the Microservices" (Optional Bonus)

- **Simulated Incident:** Pager alert: *"HIGH: Intermittent 500 Internal Server Errors in checkout flow under specific payment types."*
- **Intentional Bug:**
  - 3-tier setup: `gateway` $\to$ `cart` $\to$ `payment`.
  - When payment method is `"coupon"`, `payment` service throws an unhandled NullPointerException buried inside 5,000 lines of standard log traffic.
- **Attendee Symptoms:**
  - Standard healthchecks pass.
  - Only synthetic requests with `{"payment_method":"coupon"}` trigger the error.
- **Verification Logic (`verify.sh`):**
  - Sends 10 diverse synthetic transactions through `gateway`, including coupon and credit card payloads. All must return `HTTP 200`.

---

## 3. CLI Harness Specification (`scripts/escape-room.sh`)

The `scripts/escape-room.sh` tool provides a unified, color-coded terminal experience:

```bash
./scripts/escape-room.sh setup                 # Checks docker/kind/kubectl (prints install hints if missing), creates kind cluster 'escape-room'
./scripts/escape-room.sh start <level>         # e.g., level-01. Resets namespace, applies broken manifests, shows incident alert
./scripts/escape-room.sh status                # Shows active scenario, pod statuses, and troubleshooting commands
./scripts/escape-room.sh hint                  # Displays next progressive hint (1 -> 2 -> 3)
./scripts/escape-room.sh verify                # Runs scenario verify.sh, prints ASCII celebration banner + next steps if fixed
./scripts/escape-room.sh solve                 # (Emergency/Instructor) Applies reference solution
./scripts/escape-room.sh reset                 # Re-injects current level's broken state (and clears its completed mark)
./scripts/escape-room.sh cleanup               # Tears down kind cluster
```

### State Storage (`.room-state`)
```ini
CURRENT_LEVEL=level-01
HINT_LEVEL=0
COMPLETED_LEVELS=
```

---

## 4. Implementation plan

### 📋 Milestone 1: Core Harness & Cluster Setup
> **Prompt for Agent 1:**
> *"Implement the automation harness for the Kubernetes Escape Room at the repository root. Create the `kind/cluster-config.yaml` with port forwards (8080:30080, 8443:30443). Implement `scripts/escape-room.sh` as an executable Bash script supporting `setup`, `start <level>`, `status`, `hint`, `verify`, `solve`, `reset`, and `cleanup`. Ensure zero external dependencies (pure Bash, no jq). Manage state in `.room-state`. Format output with ANSI colors and clear status banners."*

### 📋 Milestone 2: Implement Level 01 ("The Ghost Image")
> **Prompt for Agent 2:**
> *"Create Level 01 under `scenarios/level-01-ghost-image/`. Structure: `broken/` (manifest with non-existent image tag `nginx:1.27.99-alpine` in namespace `escape-level-01`), `solution/` (valid `nginx:1.27-alpine`), `incident.md` (realistic PagerDuty alert), `hints.md` (3-tier hints + AI prompt recipe), and `verify.sh` (deterministic probe testing Pod readiness and HTTP 200). Ensure `verify.sh` exits 0 on success, 1 on failure."*

### 📋 Milestone 3: Implement Level 02 ("The Crashing Config")
> **Prompt for Agent 3:**
> *"Create Level 02 under `scenarios/level-02-crashing-config/` in namespace `escape-level-02`. Create a self-contained lightweight Python/Alpine application that reads `DATABASE_URL` from a ConfigMap and validates memory limits. In `broken/`, make the ConfigMap key misnamed (`DB_CONNECTION_STRING`) and memory limit set to `16Mi` causing crashloop/OOM. In `solution/`, provide the fixed ConfigMap and `64Mi` memory limit. Provide `incident.md`, `hints.md`, and `verify.sh`."*

### 📋 Milestone 4: Implement Level 03 ("The Silent Wall")
> **Prompt for Agent 4:**
> *"Create Level 03 under `scenarios/level-03-silent-wall/` in namespace `escape-level-03`. Deploy a Frontend service and a Backend service. In `broken/`, make the Backend service target port mismatch (`targetPort: 8080` while container listens on `9000`), and apply a `NetworkPolicy` restricting ingress to an mismatched label. In `solution/`, align the targetPort and NetworkPolicy labels. Provide `incident.md`, `hints.md`, and `verify.sh` that curls the frontend endpoint."*

### 📋 Milestone 5: Workshop Documentation & SRE AI Cheatsheet
> **Prompt for Agent 5:**
> *"Create `docs/ai-prompts-cheatsheet.md` and `docs/pre-workshop-checklist.md`. The cheatsheet should teach attendees the 'SRE Copilot Prompt Pattern' (Context + Symptom + kubectl output + Desired State), show how to extract logs/describe outputs cleanly for free web AI copilots, and caution against common AI hallucinations in Kubernetes."*

---

## 5. Decision Log Summary

| Decision | Selected Option | Rationale |
| :--- | :--- | :--- |
| **Model Hosting** | Free Web/CLI Copilots (Gemini, ChatGPT, Claude) | Avoids laptop VRAM/RAM constraints and eliminates setup friction for 40 attendees. |
| **Harness Tech** | Pure POSIX Bash (`scripts/escape-room.sh`) | Guaranteed to run out of the box on macOS and Linux without installing Python packages or `jq`. |
| **Scenario Sizing** | 3 Core Scenarios + 1 Bonus | Perfectly tuned for 40–50 minutes of collaborative pairing. |
| **Verification Method** | Non-destructive in-cluster synthetic probes | Idempotent, testable, and gives immediate binary feedback (Escaped / Still Trapped). |

---

## 6. Amendments

### Amendment 1 — Level 01 review hardening (M2)

*Flagged for human review.*

- **Readiness check:** `verify.sh` uses `kubectl rollout status` instead of reading `items[0]` of the pod list, which was unreliable during rollouts (stale `ImagePullBackOff` pod from the old ReplicaSet).
- **Image pinning:** the Level 01 solution uses `nginx:1.27-alpine` (was `nginx:alpine`) and the verify probe uses `curlimages/curl:8.11.1` (was `latest`), in line with the "pinned digests or well-known tags" constraint.
- **Probe execution:** `verify.sh` creates the probe pod detached, polls its phase (max 60s) and cleans up with a `trap`, because `kubectl run -i --rm` can lose the container exit code and falsely report success. `Failed` phase = endpoint failure; create failure or timeout = probe-pod (pull/scheduling) failure.
- **Hints & incident:** Hint 2 no longer includes the fix command; `incident.md` no longer names the cause.
- **Harness state:** `start`/`reset` remove the level from `COMPLETED_LEVELS`; `verify` success prints next steps. A `next` command was considered and rejected — `start <level>` is the single way to switch levels.
- **Setup UX:** `setup` prints install links for missing `docker`/`kind` and a start-Docker hint when the daemon is stopped.

### Amendment 2 — Level 02 design details (M3)

*Flagged for human review.*

- **Config injection:** the Deployment uses `envFrom: configMapRef` (not `configMapKeyRef`). With a `configMapKeyRef` and a missing key, Kubernetes never starts the container (`CreateContainerConfigError`), so the `KeyError: 'DATABASE_URL'` in the app logs described in the plan could not occur.
- **Both bugs visible in the broken state:** the app checks `DATABASE_URL` first and logs the `KeyError`, then warms a 32MiB cache, and only then exits `1`. At `16Mi` the kernel OOM-kills it during the warm-up (Exit Code 137), so logs show the config error while `describe` shows `OOMKilled`. Fixing either bug alone exposes the other (verified).
- **Image delivery:** `start` builds `app/` and `kind load`s the image `escape-room/level-02-app:1.0.0` (harness change, documented in `AGENTS.md`). Base image pinned to `python:3.12-alpine3.20`; stdlib only.
- **Hints:** Hint 2 uses plain `kubectl logs` first, because `--previous` is unreliable on kind (the older dead container is garbage-collected during CrashLoop backoff).
- **Solution values:** memory request `48Mi` / limit `64Mi`.
- **Verification:** `verify.sh` requires a completed rollout, an unchanged restart count over 15s, and the exact `/healthz` body `{"status":"healthy","database":"connected"}` from an in-cluster probe.
