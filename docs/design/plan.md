# Kubernetes Escape Room: Architecture & Implementation Playbook
## Ready for CLI Agent Execution

**Audience:** Platform, SRE, and Software Engineers (~55 min session: 10 min talk, 35–45 min hands-on, 5 min debrief)

---

## 1. Architectural Decisions & System Contracts

### D1: Automation Harness Dependency Policy
- **Contract:** Pure POSIX Bash (`#!/usr/bin/env bash`). Zero external runtime dependencies beyond standard macOS/Linux utilities (`curl`, `awk`, `sed`, `grep`).
- **No `jq` or Python requirement** for the core runner to avoid local attendee environment failures.
- **Windows:** a PowerShell port of the harness follows the same contract with built-in cmdlets only (see Amendment 9).
- Cluster state tracked via a local plain-text file `.room-state` containing `CURRENT_LEVEL`, `HINT_LEVEL`, and `COMPLETED_LEVELS`.

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
- Attendees use web copilots (Gemini, ChatGPT, Claude), CLI agents, or MCP-enabled agentic harnesses.
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

- **Simulated Incident:** Pager alert: *"CRITICAL: frontend-service is returning 504 Gateway Time-out / 502 Bad Gateway to end users. All pods are reporting Running 1/1."*
- **Intentional Bug:**
  1. Frontend Pod and Backend Pod are both healthy (`Running 1/1`).
  2. Backend Service has `spec.ports[0].targetPort: 8080`, but the Backend container listens on port `9000`.
  3. A strict `NetworkPolicy` (`backend-firewall`) was applied that only allows ingress from pods labeled `role: api-consumer`, but Frontend Pod is labeled `role: web-frontend`.
- **Attendee Symptoms:**
  - `kubectl get pods -n escape-level-03` shows everything green (`Running`).
  - Executing curl through Frontend to Backend returns `504` (timeout while dropped by `NetworkPolicy`) or `502` (connection refused while `targetPort` is mismatched).
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
  - When payment method is `"coupon"`, `payment` service throws an unhandled NullPointerException buried inside 5,000 lines of standard log traffic (caused by `Deployment/payment` injecting `COUPON_VALIDATOR_URI` instead of `COUPON_VALIDATOR_URL` from `ConfigMap/payment-config`).
- **Attendee Symptoms:**
  - Standard healthchecks pass (`Running 1/1`).
  - Only synthetic requests with `{"payment_method":"coupon"}` trigger the error (`HTTP 500`).
- **Verification Logic (`verify.sh`):**
  - Sends 10 diverse synthetic transactions through `gateway`, including coupon and credit card payloads. All must return `HTTP 200`.
- **Tiered Hints:**
  - *Hint 1 (Conceptual):* Every pod is `Running 1/1` and `/healthz` passes, yet `gateway` intermittently returns `HTTP 500`. Follow the call chain (`gateway` $\to$ `cart` $\to$ `payment`) and beware of the log haystack (`--tail=20` only shows healthy traffic).
  - *Hint 2 (Kubernetes):* Filter each tier's logs for `ERROR` (`kubectl logs -n escape-level-04 deployment/<tier> | grep ERROR`), then extract the stack trace from `payment` (`kubectl logs -n escape-level-04 deployment/payment | grep -A 5 -E "ERROR|Exception"`) and compare the required env var with `Deployment/payment` and `ConfigMap/payment-config`.
  - *Hint 3 (AI Prompt):*
    > *"I am troubleshooting intermittent HTTP 500 errors in a 3-tier Kubernetes checkout pipeline (`gateway -> cart -> payment`). Here is the grep-filtered exception from `payment` logs: `<paste stack trace>`, the `payment` Deployment YAML: `<paste deployment>`, and `payment-config` ConfigMap: `<paste configmap>`. Why do only coupon checkouts fail and what minimal change fixes it?"*

---

## 3. CLI Harness Specification (`scripts/escape-room.sh`)

The `scripts/escape-room.sh` tool provides a unified, color-coded terminal experience:

```bash
./scripts/escape-room.sh setup                 # Checks docker/kind/kubectl (prints install hints if missing), creates kind cluster 'escape-room'
./scripts/escape-room.sh start <level>         # e.g., level-01. Resets namespace, applies broken manifests, shows incident alert
./scripts/escape-room.sh status                # Shows active scenario, pod statuses, and troubleshooting commands
./scripts/escape-room.sh hint                  # Displays next progressive hint (1 -> 2 -> 3)
./scripts/escape-room.sh ai-assist             # Shows the paste-ready AI agent prompt for the current level (independent of hint counter)
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

### 📋 Milestone 5: AI-Assisted Troubleshooting Best Practices
> **Prompt for Agent 5:**
> *"Research current, credible, dated sources on LLM-assisted Kubernetes troubleshooting (chat assistants, retrieval over runbooks, MCP and CLI agents such as opencode). Extend `docs/ai-prompts-cheatsheet.md` with a repeatable evidence-based workflow (logs, events, metrics, manifests, recent changes), stage prompts, a challenge-the-AI-hypothesis exercise with facilitator notes, an evaluation rubric (correctness, time to useful evidence, missed signals, unsafe advice) and guardrails (AI output is a hypothesis, humans decide, no secrets, logs/events are untrusted input, no destructive or privileged actions without review). Record cited sources in `docs/ai-research-notes.md`, separating established from emerging practices. Treat MCP/CLI agents as optional and read-only by default; do not assume they are installed."*

### 📋 Milestone 6: Workshop Documentation & Pre-Event Readiness
> **Prompt for Agent 6:**
> *"Create `docs/pre-workshop-checklist.md` (instructor pre-event steps, attendee prerequisites, fallbacks) and condense `docs/ai-prompts-cheatsheet.md` into a one-page A4 cheatsheet built on the 'SRE Copilot Prompt Pattern' (Context + Symptom + kubectl output + Desired State), clean log/describe extraction for AI copilots and CLI agents, and common Kubernetes AI hallucinations. Verify accuracy against the final scenarios."*

---

## 5. Decision Log Summary

| Decision | Selected Option | Rationale |
| :--- | :--- | :--- |
| **Model Hosting** | Web Copilots, CLI Agents & Agentic Harnesses (Gemini, ChatGPT, Claude, OpenCode, MCP) | Avoids laptop VRAM/RAM constraints and eliminates local model setup friction for 40 attendees. |
| **Harness Tech** | Pure POSIX Bash (`scripts/escape-room.sh`) | Guaranteed to run out of the box on macOS and Linux without installing Python packages or `jq`. |
| **Scenario Sizing** | 3 Core Scenarios + 1 Bonus | Tuned for ~55 minutes in total (10 min talk + 35–45 min of collaborative pairing + 5 min debrief); Level 04 is a take-home. |
| **Verification Method** | Non-destructive in-cluster synthetic probes | Idempotent, testable, and gives immediate binary feedback (Escaped / Still Trapped). |

---

## 6. Amendments

### Amendment 1 — Level 01 review hardening (M2)

*Merged in PR #4; flagged for human review (rule 10).*

- **Readiness check:** `verify.sh` uses `kubectl rollout status` instead of reading `items[0]` of the pod list, which was unreliable during rollouts (stale `ImagePullBackOff` pod from the old ReplicaSet).
- **Image pinning:** the Level 01 solution uses `nginx:1.27-alpine` (was `nginx:alpine`) and the verify probe uses `curlimages/curl:8.11.1` (was `latest`), in line with the "pinned digests or well-known tags" constraint.
- **Probe execution:** `verify.sh` creates the probe pod detached, polls its phase (max 60s) and cleans up with a `trap`, because `kubectl run -i --rm` can lose the container exit code and falsely report success. `Failed` phase = endpoint failure; create failure or timeout = probe-pod (pull/scheduling) failure.
- **Hints & incident:** Hint 2 no longer includes the fix command; `incident.md` no longer names the cause.
- **Harness state:** `start`/`reset` remove the level from `COMPLETED_LEVELS`; `verify` success prints next steps. A `next` command was considered and rejected — `start <level>` is the single way to switch levels.
- **Setup UX:** `setup` prints install links for missing `docker`/`kind` and a start-Docker hint when the daemon is stopped.

### Amendment 2 — Level 02 design details (M3)

*Merged in PR #5; flagged for human review (rule 10).*

- **Config injection:** the Deployment uses `envFrom: configMapRef` (not `configMapKeyRef`). With a `configMapKeyRef` and a missing key, Kubernetes never starts the container (`CreateContainerConfigError`), so the `KeyError: 'DATABASE_URL'` in the app logs described in the plan could not occur.
- **Both bugs visible in the broken state:** the app checks `DATABASE_URL` first and logs the `KeyError`, then warms a 32MiB cache, and only then exits `1`. At `16Mi` the kernel OOM-kills it during the warm-up (Exit Code 137), so logs show the config error while `describe` shows `OOMKilled`. Fixing either bug alone exposes the other (verified).
- **Image delivery:** `start` builds `app/` and `kind load`s the image `escape-room/level-02-app:1.0.0` (harness change, documented in `AGENTS.md`). Base image pinned to `python:3.12-alpine3.20`; stdlib only.
- **Hints:** Hint 2 uses plain `kubectl logs` first, because `--previous` is unreliable on kind (the older dead container is garbage-collected during CrashLoop backoff).
- **Solution values:** memory request `48Mi` / limit `64Mi`.
- **Verification:** `verify.sh` requires a completed rollout, an unchanged restart count over 15s, and the exact `/healthz` body `{"status":"healthy","database":"connected"}` from an in-cluster probe.

### Amendment 3 — Cilium CNI for NetworkPolicy enforcement (M4)

*Merged in PR #6; flagged for human review (rule 10).*

- **Problem:** kind's default CNI (kindnet) does not enforce NetworkPolicy, so the Level 03 policy fault would not block traffic.
- **Decision:** the cluster is created with `networking.disableDefaultCNI: true`, and `setup` installs Cilium 1.20.2 from a pinned manifest, `kind/cni/cilium.yaml` (rendered with helm, no helm at runtime). kube-proxy is kept (`kubeProxyReplacement=false`), with Kubernetes IPAM and Envoy disabled to limit image pulls. Hubble, Hubble Relay and the Hubble UI are enabled so attendees and instructors can observe dropped flows.
- **Alternatives considered:** Calico (heavier to maintain, same setup cost), Antrea (fewer references), Weave Net (unmaintained), or replacing the policy fault with a Service selector mismatch that kindnet can enforce.
- **Harness safety:** the harness previously used whatever kubectl context was current. `setup` now writes a repo-local kubeconfig, `kind/.kube/config`, with `kind export kubeconfig`; the harness and every `verify.sh` use it through `KUBECONFIG`. kind still updates `~/.kube/config` as usual. The file holds client credentials, so it is gitignored and removed by `cleanup`.
- **Subnets:** `kind/cluster-config.yaml` sets the pod and service subnets explicitly (`10.10.0.0/16`, `10.11.0.0/16`; kind's defaults are `10.244.0.0/16` and `10.96.0.0/16`). Edit them if they overlap with a VPN or Docker network on the machine.
- **`cleanup` behaviour:** it now removes `kind/.kube/` and `.room-state` even when the cluster is already gone (it used to return early).
- **Cost for attendees:** `setup` now pulls Cilium images and waits for nodes `Ready`. Existing clusters created with kindnet must be recreated (`cleanup`, then `setup`).

### Amendment 4 — Split M5 into M5 (AI practices) and M6 (docs)

*Merged in PR #7; flagged for human review (rule 10).*

- **Change:** The original M5 (docs + cheatsheet) is split. M5 now covers AI-assisted troubleshooting best practices incl. MCP and CLI agents (opencode); the pre-workshop checklist and one-page cheatsheet move to M6.
- **D4 extended, not replaced:** web copilots remain the baseline. MCP servers and CLI agents are optional, read-only by default, and scoped to the repo-local kubeconfig; setup stays outside the harness.

### Amendment 5 — Facilitator notes in `docs/ai-exercises.md` and `ai-assist` command

*Merged in PR #8; flagged for human review (rule 10).*

- **Problem:** `extract_hint` in `scripts/escape-room.sh` prints everything between `## Hint N` headings, so notes appended to `hints.md` after Hint 3 would be shown to attendees.
- **Decision:** M5 puts per-level bad/good prompts, expected findings and facilitator notes in a new instructor file, `docs/ai-exercises.md`, and adds attendee-facing AI tips in `scenarios/*/ai-assist.md` shown by `./scripts/escape-room.sh ai-assist` (independent of `HINT_LEVEL`). `scenarios/*/hints.md` is unchanged.

### Amendment 6 — Level 04 design details ("The Ghost in the Microservices")

*Merged in PR #9; flagged for human review (rule 10).*

- **Single self-contained image:** `scenarios/level-04-ghost-microservices/app/` builds `escape-room/level-04-app:1.0.0` (`python:3.12-alpine3.20`, stdlib only) and runs as `gateway`, `cart`, or `payment` via the `SERVICE_ROLE` environment variable.
- **5,000-line log haystack & configuration bug:** On startup, `payment` emits 5,000 lines of structured checkout logs. In `broken/payment-deployment.yaml`, the container environment variable is mapped as `COUPON_VALIDATOR_URI` instead of `COUPON_VALIDATOR_URL` (referencing `ConfigMap/payment-config` key `COUPON_VALIDATOR_URL`). Health checks (`/healthz`) and non-coupon payments succeed, while `"coupon"` checkouts log an unhandled `NullPointerException` stack trace (buried inside the 5,000 lines and emitted on live `"coupon"` requests) and return `HTTP 500` cascading through `cart` and `gateway`.
- **Immediate rollout on fix:** Placing the env name mismatch on `Deployment/payment` ensures that fixing the Deployment (or running `./scripts/escape-room.sh solve`) immediately triggers a Pod rollout without needing a manual `kubectl rollout restart`. `wait_for_level_rollout` in `scripts/escape-room.sh` waits for `payment`, `cart`, and `gateway` on `start` and `reset`.

### Amendment 7 — Slidev Workshop Presentation, MCP Integration & Makefile (M6)

*Flagged for human review (rule 10).*

- **Presentation deck in `docs/presentation/`:** Milestone 6 includes a self-contained [Slidev](https://sli.dev) deck (`docs/presentation/slides.md` and `docs/presentation/package.json`) covering the ~55 minute workshop (incident-management context, troubleshooting then vs now, AI best practices: 5-stage loop, 6 guardrails, tooling tiers with `k8sgpt` and MCP, sharing skills/MCP via the repo; Levels 01–03 briefings & debriefs, the Level 03 Challenge-the-AI-Hypothesis exercise, and the 4-criterion facilitator rubric; Level 04 is left as a take-home) with a shared `style.css` theme and slide numbers via `global-bottom.vue`; the generated `package-lock.json` is gitignored. Keeping `package.json` under `docs/presentation/` preserves the zero-dependency root layout for `./scripts/escape-room.sh`.
- **Agent skill & Slidev MCP server:** Pinned the official `slidevjs/slidev` agent skill in `skills-lock.json` (files under `.agents/skills/` are gitignored and restored by `make setup-dev` or `npx skills experimental_install`) and configured the Slidev stdio MCP server (`npx --prefix docs/presentation slidev mcp docs/presentation/slides.md`) in `.agents/plugins/slidev/mcp_config.json` (Antigravity workspace plugin) and `.mcp.json` (standard CLI/IDE MCP clients), documented for contributors in `docs/presentation/README.md`. `--prefix docs/presentation` is required when invoking `npx` from the repository root because the `slidev` binary is provided by `@slidev/cli` inside `docs/presentation/node_modules/.bin/`.
- **PDF export (`playwright-chromium`) & root `Makefile`:** Added `playwright-chromium` to `docs/presentation/package.json` and created a root `Makefile` providing `setup-dev` (installs `shellcheck`, Slidev dependencies, Playwright Chromium, and restores the pinned agent skills), `slides` (starts the live server), `slides-export` (builds and exports to PDF), `lint`, `check`, `validate`, cluster lifecycle wrappers (`setup`, `cleanup`, `start`, `status`, `hint`, `ai-assist`, `verify`, `solve`, `reset`), and parameterized end-to-end smoke testing (`make test LEVEL=level-01` or `make test LEVEL=all`).

### Amendment 8 — Agent-ready `ai-assist` prompts and optional `glow` rendering

*Flagged for human review (rule 10).*

- **Decision:** `docs/ai-prompts-cheatsheet.md` stays the base reference for prompting in this workshop. Each `scenarios/<level>/ai-assist.md` is a worked example of it: a self-contained prompt (RULES, ISSUE, TASK) with no placeholders, which an AI agent with `kubectl` access runs on its own, gathering the evidence itself with read-only commands. A bad-prompt example and a follow-up prompt sit next to it, and the exact `kubectl` commands stay as a manual fallback for chat assistants.
- **Why:** pasting evidence into a template with placeholders was slow and error-prone, and the prompt could not be reused as is. The ISSUE only restates the symptom already shown in `incident.md`, so the spoiler discipline is unchanged.
- **Trade-off:** letting the agent choose its evidence makes the level traps (logs alone in level 02, unfiltered logs in level 04) easier to fall into, so they are carried by short RULES lines. "Read-only" is an instruction to the agent, not an enforcement; the MCP/CLI-agent restrictions in `docs/pre-workshop-checklist.md` remain the real guardrail.
- **Optional `glow`:** `render_markdown` in `scripts/escape-room.sh` pipes `incident.md`, hints and `ai-assist.md` through `glow` (zero-margin style) when it is installed and falls back to `cat`. This is the only exception to rule 1 (zero runtime dependencies): glow is optional, listed as such in `README.md` and the pre-workshop checklist, and never installed or required by the harness.
- **Hint 3 becomes a pointer:** the Hint 3 prompt templates (with `<PASTE ...>` placeholders) duplicated `ai-assist` and asked for fixes directly, contradicting the agent-ready prompts. Hint 3 on every level is now a short, light-hearted nudge to run `make ai-assist`, with no prompt text and no level-specific facts. `extract_hint` still matches on the `## Hint 3` heading.
- **`hint` after all hints are used:** the "already used all 3 hints" warning is kept and Hint 3 is shown again (without changing `HINT_LEVEL`), so the pointer to `make ai-assist` stays visible.
- **`render_markdown` robustness:** stdin is buffered so a failing `glow` falls back to the plain text, and the embedded style defines `enumeration` so numbered lists keep their dot.

### Amendment 9 — PowerShell port for Windows attendees

*Flagged for human review (rule 10).*

- **Problem:** the harness needs Bash and `make`, so Windows attendees needed WSL2 or Git Bash plus a `make` install, and the README listed Windows as unsupported.
- **Decision:** add a PowerShell port next to the Bash scripts instead of replacing them. `scripts/escape-room.ps1` ports `scripts/escape-room.sh`, `scripts/make.ps1` ports the `Makefile` (same targets, `LEVEL=level-02` or `-Level level-02`), and every level gets a `verify.ps1` twin of its `verify.sh`. macOS and Linux keep Bash and `make` unchanged. Both harnesses share `.room-state` (same keys, LF line endings), `kind/.kube/config` and `scenarios/`.
- **Dependency policy (D1) for PowerShell:** Windows PowerShell 5.1 (built into Windows 10/11) or PowerShell 7+, built-in cmdlets only. External tools are the same as for Bash (`kubectl`, `kind`, `docker`, optional `glow`), plus the Windows built-in `icacls`. PSScriptAnalyzer is a contributor tool for `lint`, never a runtime dependency.
- **Windows PowerShell 5.1 constraints that shaped the code:**
  - Scripts without a BOM are read as ANSI, so every `.ps1` file is saved as UTF-8 with BOM (enforced by `check` in both `Makefile` and `make.ps1`).
  - Redirected stderr of a native command becomes a terminating error under `$ErrorActionPreference = 'Stop'`, so the harness wraps native calls in helpers (`Invoke-Native`, `Test-Native`, `Get-NativeOutput`) that relax the preference locally and use the exit code. `verify.ps1` scripts use `'Continue'` and check `$LASTEXITCODE` after every command.
  - Embedded double quotes in native arguments are stripped. Level 02's restart-count jsonpath is space-separated instead of using `{"\n"}`, and level 04 sends its probe pod as a manifest on stdin (the same `sh` script, in a YAML block scalar, with small resource requests/limits) instead of `kubectl run ... sh -c "<script>"`.
- **Behaviour differences, all deliberate:**
  - PowerShell scripts run in the caller's session, so the harness restores `KUBECONFIG` (and the console encoding) when it exits, and `verify.ps1` restores `KUBECONFIG` too. The user's own `kubectl` context is never changed, as with Bash.
  - The repo kubeconfig is restricted with `icacls` (one full-control entry for the current user) instead of `chmod 700/600`. A failure is a warning, not an abort.
  - `incident.md`, `hints.md` and `ai-assist.md` are shared. The PowerShell harness rewrites `make <target>` in them to `.\scripts\make.ps1 <target>` when printing, so the Markdown files need no Windows copy.
  - Probe pod names include a random suffix (`verify-probe-<pid>-<n>`), because `$PID` is the same for every `verify.ps1` run in one PowerShell session.
- **Guardrail update:** the `ai-assist.md` prompts now forbid "any make target or script under scripts/", since an agent on Windows would otherwise not read `.\scripts\make.ps1 solve` as a make target. The opencode example in the pre-workshop checklist denies the PowerShell `solve` forms too.
- **Cost:** every harness, `Makefile` or `verify.sh` change now has to be made twice. `AGENTS.md` makes the twins a rule, `make lint` runs PSScriptAnalyzer when `pwsh` is installed, and the analyzer's `PSUseCompatibleSyntax` rule keeps the code 5.1-compatible.
- **Alternatives considered:** documenting WSL2 or Git Bash plus `make` for Windows (one implementation, but more setup and path-conversion pitfalls on attendee laptops), and replacing Bash with PowerShell everywhere (would force macOS/Linux attendees to install `pwsh`).
