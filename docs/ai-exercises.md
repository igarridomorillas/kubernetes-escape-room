# AI Exercises — Bad vs Good Prompting on the Real Scenarios (Instructor Guide)

> **Instructor material.** This file contains the answers to every level. Do not share it with attendees before they finish the level.
> Attendee-facing tips are in [`ai-prompts-cheatsheet.md`](ai-prompts-cheatsheet.md). Sources are in [`ai-research-notes.md`](ai-research-notes.md).
> (It is kept out of `hints.md` on purpose: `make hint` prints everything under a hint heading.)

## How to run an exercise

1. Attendee starts the level and reads the incident.
2. **Round A, "bad":** they use the *bad* prompt below with an AI copilot or agent and note what comes back.
3. **Round B, "good":** they collect the listed evidence, use the *good* prompt and compare.
4. Debrief with the rubric (cheatsheet section 5).

**Methodology & Caveat:** Model answers vary by model tier, version and day. The "observed in the cluster" blocks are real output from a fresh kind + Cilium cluster (captured 2026-10-23). The "Observed AI behavior" notes and the **Model Evaluation Matrix** below were empirically validated (2026-10-24) across two distinct model tiers (**Gemini Flash-Lite** and **Gemini Pro**) in zero-context sessions using only the pasted prompt text.

---

## Empirical Model Evaluation Matrix (Levels 01–03)

| Prompt / Scenario | Gemini Flash-Lite (Fast / Lightweight Tier) | Gemini Pro (Frontier Reasoning Tier) | Key Drift & Facilitator Takeaway |
|---|---|---|---|
| **L01 Bad** (`My pod is stuck in ImagePullBackOff, what do I do?`) | Generic 3-step checklist (`describe pod`, check tag existence, check typos and `imagePullSecrets`). | Generic 3-branch checklist separating `NotFound`, `401/403` (`imagePullSecrets`), and `i/o timeout` (network/DNS). | Without `Events`, both models must guess across all 3 failure classes; attendees waste time checking registry auth. |
| **L01 Good** (Full `describe pod` Events + negative constraint on inventing tags) | Quotes `code = NotFound ... nginx:1.27.99-alpine: not found`; rules out auth (403) and network (timeout); suggests `skopeo list-tags` or Docker Hub. | Quotes exact `NotFound` event; separates from 401/403 and timeout; provides Docker Hub v2 tags API `curl` command and `skopeo list-tags`. | Negative constraint (`Do not invent a replacement tag`) prevented both models from hallucinating a tag; both pointed to registry inspection. |
| **L02 Bad** (Pasting `kubectl logs` only: `KeyError` + `warming 32MiB`) | **Hyperfocuses 100% on `KeyError: 'DATABASE_URL'`**; completely misses the `OOMKilled` termination. | Diagnoses `DATABASE_URL` (with placeholder `<configmap-name>`), **and** spots `warming 32MiB order cache` as a clue to check `describe pod` for Exit 137 (`OOMKilled`). | Confirming [arXiv:2602.09937](https://arxiv.org/abs/2602.09937) (E7): smaller/faster models stop at the first log error; even frontier models cannot see `16Mi` or `DB_CONNECTION_STRING` without `describe` + `ConfigMap`. |
| **L02 Good** (`logs` + `describe` + `ConfigMap`, ask for all causes & order) | Identifies both causes (`KeyError` vs `DB_CONNECTION_STRING` and `OOMKilled` Exit 137 at `16Mi` vs `32MiB`). Orders **ConfigMap first, Memory second** (`64Mi`). | Identifies both causes with exact quotes. Orders **Memory first (`64Mi`), ConfigMap second**, and asks for `logs --previous` + probe specs to rule out probe kills. | **Order drift:** Fixing ConfigMap first removes `KeyError` from logs while the pod still OOMs; fixing Memory first lets the app survive cache warming and exit `1` cleanly on config. Both work if verified step-by-step. |
| **L03 Bad** (`backend-service` YAML only) | Lists 3 unverified possibilities: pod label mismatch, `targetPort: 8080` mismatch, or `NetworkPolicy` blocking traffic. | States Service YAML alone is insufficient; lists 4 hypotheses (selector, `targetPort`, `NetworkPolicy`, client DNS) and the `kubectl` commands to check each. | Single-resource prompts force guesswork. Impatient follow-ups ("just give me a quick fix") trigger unsafe advice (`kubectl delete netpol`, `hostNetwork: true`). |
| **L03 Good** (Endpoints + Service + Deployment ports + NetPol + pod labels) | Finds both disagreements (`8080` vs `9000`; `role: api-consumer` vs `role: web-frontend`) and keeps security intent, **but proposes curling `backend-service` after fixing only `targetPort`**. | Finds both disagreements, keeps security intent, verifies `targetPort` via `kubectl get endpoints` (`:9000`), and explains that fixing `NetworkPolicy` shifts curl from timeout (`504`) to immediate response/refusal (`502`). | **Verification-order trap (`Flash-Lite`):** Curling `backend-service` after fixing only `targetPort` still times out (`504`) because `backend-firewall` drops the SYN packet! Verify port via `get endpoints`, or fix `NetworkPolicy` first. |
| **L03 Challenge** (Step 1: `504` timeout only → Step 3: DNS `10.11.142.156` + Endpoint `10.10.0.167:8080`) | **Step 1:** Blames network block or port mismatch; suggests `kubectl exec ... curl` (violates read-only). **Step 3:** **Hallucinates an "IP mismatch between endpoints (`10.10.0.167`) and DNS (`10.11.142.156`)"**. | **Step 1:** Identifies packet drop (`NetworkPolicy`, 85% confidence) because TCP timeout != RST (`Connection refused`); checks `kubectl get netpol`. **Step 3:** Rules out DNS/ClusterIP (`10.11.142.156`) and empty endpoints; requests `netpol -o yaml`, `--show-labels`, and Deployment `containerPort`. | **Classic LLM hallucination (`Flash-Lite`):** Conflated the Service ClusterIP (`10.11.0.0/16`) with the Pod Endpoint IP (`10.10.0.0/16`). Great live teaching example of low *evidence closure* ([arXiv:2603.00468](https://arxiv.org/abs/2603.00468)). |

---

## Level 01: The Ghost Image (`escape-level-01`)

**Lesson:** raw evidence beats paraphrase, and AI must not invent facts it cannot check.

**Observed in the cluster (broken state):** pod `ImagePullBackOff`; Events include
`Failed to pull image "nginx:1.27.99-alpine": ... docker.io/library/nginx:1.27.99-alpine: not found`.

### 🚫 Bad prompt
```text
My pod is stuck in ImagePullBackOff, what do I do?
```
**Observed AI behavior (Flash-Lite & Pro):** Both models return a generic 3-branch checklist (`NotFound`/typo, `401`/`403` registry authentication / `imagePullSecrets`, and network/DNS/rate-limiting timeouts) because no event output was supplied. Attendees using this prompt often waste time inspecting ServiceAccounts and `imagePullSecrets` on a public image.

### ✅ Good prompt
```text
Namespace escape-level-01, Deployment payment-gateway. Expected: Running.
Actual: ImagePullBackOff. Full `kubectl describe pod` output below.
Quote the line that tells you WHY the pull failed, then say whether it is an auth,
network or "image does not exist" problem and what evidence separates them.
Do not invent a replacement tag: tell me how I can check which tags exist.
<PASTE describe pod>
```
**Observed AI behavior (Flash-Lite & Pro):** Both models quote `rpc error: code = NotFound ... docker.io/library/nginx:1.27.99-alpine: not found`, classify the issue as "image does not exist", explicitly separate `NotFound` from `401/403 Unauthorized` (auth) and `i/o timeout` (network), and respect the negative constraint by providing Docker Hub API / `skopeo list-tags` commands instead of guessing a tag.

### Facilitator notes
- **Expected finding:** the tag in the Deployment (`1.27.99`) does not exist; the Events say `not found`, which rules out credentials and network.
- **If an attendee gets a stray answer:** if the attendee omitted `"Do not invent a replacement tag"` and the LLM suggests a tag (e.g. `nginx:1.27-alpine` or `nginx:latest`), ask: *"Did the model verify that tag exists in the registry, or retrieve it from training memory? Why is `latest` disallowed by our production conventions?"*
- **Discussion:** what changed between "paraphrase" and "verbatim"? Which single line in `Events` eliminated two-thirds of the generic checklist?
- **Rubric hint:** *time to useful evidence* jumps from 1 (multi-turn checklist) to 2 (first-turn root cause).

---

## Level 02: The Crashing Config (`escape-level-02`)

**Lesson:** compound faults. The first visible error is not the only one. Ask for all causes and re-check after each fix.

**Observed in the cluster (broken state):**
```text
$ kubectl logs -n escape-level-02 -l app=order-processor
order-processor: loading configuration
ERROR config: KeyError: 'DATABASE_URL'
order-processor: warming 32MiB order cache

$ kubectl describe pod ... (excerpt)
    State:          Terminated
      Reason:       OOMKilled
      Exit Code:    137
```
Also: `kubectl logs --previous` can fail with *unable to retrieve container logs* between restarts, so a missing `--previous` is not always the attendee's fault.

The log shows the config error but stops at the cache line: the container is killed by the memory limit before it logs anything else. The kill itself appears only in `describe`.

### 🚫 Bad prompt (logs only, one cause)
```text
My pod keeps crashing. Logs:
<PASTE logs>
How do I fix it?
```
**Observed AI behavior (Flash-Lite vs Pro):**
- **Flash-Lite:** Diagnoses only `KeyError: 'DATABASE_URL'` and stops. An attendee applying that fix sees the pod *still* crashing (`OOMKilled`), illustrating **incomplete exploration** ([arXiv:2602.09937](https://arxiv.org/abs/2602.09937)).
- **Pro:** Gives a YAML snippet for `DATABASE_URL` (with placeholder `<configmap-name>` / `<key-name>` since the ConfigMap was omitted), but notices `warming 32MiB order cache` after the error line and warns the user to run `kubectl describe pod` to check for Exit Code 137 (`OOMKilled`). Even so, without `describe` and the ConfigMap, neither model knows the actual broken key name (`DB_CONNECTION_STRING`) or limit (`16Mi`).

### ✅ Good prompt
```text
Namespace escape-level-02, Deployment order-processor, config from ConfigMap order-config.
Expected: Running/Ready, /healthz on 8080 returns 200.
Symptom: restarts, status flips between Error/CrashLoopBackOff/OOMKilled.
Logs, `describe pod` (Last State + Limits) and the ConfigMap are below.
1. List EVERY distinct root cause you can see. For each, quote the evidence line.
2. Say which evidence you would still want to rule something out.
3. Give the order to fix them in and how I confirm each fix separately.
<PASTE logs, describe, configmap>
```
**Observed AI behavior (Flash-Lite & Pro):** Both models identify both distinct causes with exact evidence quotes: (1) `KeyError: 'DATABASE_URL'` vs `DB_CONNECTION_STRING` in `order-config`, and (2) `Reason: OOMKilled` / `Exit Code: 137` with `memory: 16Mi` against `warming 32MiB order cache`.

### Facilitator notes
- **Expected findings:** (1) the ConfigMap key does not match the name the app reads; (2) memory limit (`16Mi`) is lower than the app's working set (`32MiB` cache + Python runtime), shown by `OOMKilled` / exit 137.
- **Note drift on fix order (Flash-Lite vs Pro):**
  - `Flash-Lite` recommends fixing **ConfigMap first, Memory second**: if attendees do this, `ERROR config: KeyError: 'DATABASE_URL'` disappears from `kubectl logs`, while `describe pod` still shows `OOMKilled` (Exit 137).
  - `Pro` recommends fixing **Memory first (`64Mi`), ConfigMap second**: if attendees do this, `OOMKilled` disappears and the container survives cache warming to print `FATAL: cannot start without database configuration` (Exit Code 1).
  - Both sequences are valid **if** the attendee checks the symptom shift after the first change (stage 4 of the workflow).
- **Unsafe-advice check:** Both models suggested `64Mi` (roughly 2x the `32MiB` cache for Python runtime overhead). If a model proposes a huge limit (e.g. `1Gi` or removing limits entirely), ask attendees to justify the number from the `32MiB` log line.
- **Watch for:** `--previous` logs being empty. Point attendees to `describe` for `Last State`.

---

## Level 03: The Silent Wall (`escape-level-03`)

**Lesson:** topology problems need several related resources at once, and AI will happily "fix" an isolation problem by removing the isolation. This is the D4 pedagogical warning.

**Observed in the cluster (broken state):**
```text
$ kubectl get pods -n escape-level-03 --show-labels
backend-...    1/1  Running  ... app=backend,component=backend,level=03,...
frontend-...   1/1  Running  ... app=frontend,component=frontend,level=03,...,role=web-frontend

$ kubectl get endpoints -n escape-level-03
backend-service    10.10.0.167:8080
frontend-service   10.10.0.239:80

$ frontend access log / error log (excerpt)
[error] ... upstream timed out (110: Operation timed out) while connecting to upstream ...
"GET /api/data HTTP/1.1" 504

$ DNS from a pod in the namespace
10.11.142.156  backend-service.escape-level-03.svc.cluster.local     # resolves fine
```
**Symptom progression (`504` → `502`):** In the initial broken state, the `NetworkPolicy` drops packets silently, so the frontend proxy times out and returns **`504`**. A **`502`** (`Connection refused`) appears after the policy is fixed while the `targetPort` mismatch remains. `incident.md` and `hints.md` mention `504` / `502` to cover both stages.

### 🚫 Bad prompt
```text
Here is my Service YAML. The frontend can't reach the backend, but the pods are Running. Why?
<PASTE only backend-service YAML>
```
**Observed AI behavior (Flash-Lite & Pro):** Because only `backend-service` was pasted, both models guess across 3–4 hypotheses (pod label selector mismatch, `targetPort: 8080` vs container port, `NetworkPolicy` blocking traffic, or DNS failure). When attendees follow up impatiently (*"how do I quickly unblock traffic to test?"*), models frequently suggest `kubectl delete networkpolicy` or `hostNetwork: true`, which removes the security boundary while leaving the `targetPort` bug broken.

### ✅ Good prompt
```text
Namespace escape-level-03. Frontend Service (80) proxies /api/* to backend-service.
Pods are Running 1/1 but GET /api/data fails.
Evidence below: endpoints, backend-service YAML, backend Deployment (ports), the
NetworkPolicy YAML and `get pods --show-labels`.
1. Which fields disagree with each other? Quote both sides of each disagreement.
2. Give the MINIMAL change for each that keeps the intent "only the frontend may call
   the backend". Do not delete or loosen the policy.
3. How do I verify each fix separately before applying the other?
<PASTE evidence>
```
**Observed AI behavior (Flash-Lite vs Pro):** Both models quote the exact disagreements (`targetPort: 8080` vs `containerPort: 9000`; `role: api-consumer` vs `role: web-frontend`) and give minimal patches that preserve isolation. However, their **verification instructions diverge**:
- **Flash-Lite trap:** Suggests fixing `targetPort` first and running an in-cluster curl probe to `backend-service`. **This fails in practice** because `backend-firewall` still drops the packets, so curl still times out (`504`)!
- **Pro verification:** Verifies the `targetPort` fix via control-plane state (`kubectl get endpoints backend-service` → `10.10.0.167:9000`), and explains that fixing the `NetworkPolicy` changes the data-plane probe from a silent timeout (`504`) to an immediate response (or `502 Connection refused` if the port is still `8080`).

### Facilitator notes
- **Expected findings:** (1) Service `targetPort` (`8080`) does not match the backend `containerPort` (`9000`); (2) NetworkPolicy `from` selector (`role: api-consumer`) does not match the frontend pod's label (`role: web-frontend`).
- **Why order matters (highlight the `Flash-Lite` trap):** Ask attendees: *"If you fix `targetPort` first and test with `curl`, why does `curl` still time out?"* (Cilium drops the SYN packet before it reaches the backend pod; only `kubectl get endpoints` can confirm the port change while the firewall still blocks traffic, whereas fixing the `NetworkPolicy` first immediately shifts the HTTP status from `504` to `502`).
- **Unsafe-advice check:** Score `0` on safety if an attendee deleted `backend-firewall`, replaced `podSelector` with `{}` (allow-all), or enabled `hostNetwork`.
- **Teaching point:** Kubernetes docs list the NetworkPolicy and the selector/`targetPort` checks as separate steps ([research notes E2/E3](ai-research-notes.md)), and an AI answers only about what it sees.

---

## Level 04 (Bonus): The Ghost in the Microservices (`escape-level-04`)

**Lesson:** call-chain tracing and log haystack filtering. In a noisy microservice pipeline (`gateway` → `cart` → `payment`), `--tail=30` misses intermittent errors and dumping 5,000 raw log lines floods the context window. Trace the upstream `500` down the call chain and filter for the exception before prompting.

**Observed in the cluster (broken state):**
```text
$ kubectl get pods -n escape-level-04
cart-...      1/1  Running
gateway-...   1/1  Running
payment-...   1/1  Running

$ kubectl logs -n escape-level-04 deployment/payment | wc -l
5000

$ kubectl logs -n escape-level-04 deployment/payment | grep -A 4 "ERROR" | head -n 5
2026-10-24T11:14:08.312Z ERROR [payment-worker-2] PaymentProcessor — Unhandled exception processing checkout tx_id=tx-001250 payment_method=coupon amount_cents=2500
java.lang.NullPointerException: Cannot invoke "CouponValidator.redeem(String, int)" because "this.couponValidator" is null (required env COUPON_VALIDATOR_URL is not set)
	at com.escaperoom.payment.CouponPaymentHandler.redeem(CouponPaymentHandler.java:74)
	at com.escaperoom.payment.PaymentProcessor.process(PaymentProcessor.java:112)
	at com.escaperoom.payment.CheckoutHttpHandler.doPost(CheckoutHttpHandler.java:68)
```

### 🚫 Bad prompt (`--tail=30` on `payment` or only `gateway` logs)
```text
Users are getting intermittent 500 errors on checkout. Here are the last 30 lines of payment logs:
<PASTE kubectl logs -n escape-level-04 deployment/payment --tail=30>
Why is it failing?
```
**Observed AI behavior:** Because the last ~850 lines of `payment`'s 5,000-line startup log buffer are `INFO` lines (`status=200` for `credit_card`, `debit_card`, `/healthz`), the model sees zero errors in `payment` and guesses network flakiness, gateway timeouts, or database connection pool exhaustion.

### ✅ Good prompt (filtered stack trace + `Deployment/payment` + `ConfigMap/payment-config`)
```text
Namespace escape-level-04 (gateway -> cart -> payment). All pods Running 1/1.
Intermittent HTTP 500 on POST /checkout. Below are the upstream ERROR lines from gateway/cart,
the grep-filtered exception from payment's 5,000-line log, and payment's Deployment + ConfigMap.
1. Quote the exact exception line that explains which payment_method fails and why.
2. Quote the exact field in Deployment/payment vs ConfigMap/payment-config that disagrees.
3. Give the minimal fix that updates Deployment/payment and rolls out the pod.
<PASTE filtered ERROR lines + Deployment/payment + ConfigMap/payment-config>
```

### Facilitator notes
- **Expected findings:** (1) `gateway` logs an upstream `500` from `cart`, and `cart` logs an upstream `500` from `payment`; (2) inside `payment`'s 5,000 log lines, `payment_method=coupon` throws `java.lang.NullPointerException` because `COUPON_VALIDATOR_URL` is not set; (3) `ConfigMap/payment-config` defines key `COUPON_VALIDATOR_URL`, but `Deployment/payment` injects it into the container under the misnamed env var `COUPON_VALIDATOR_URI`.
- **Discussion:** Why did `--tail=30` fail here? Why is `grep -A 5 -E "ERROR|Exception"` better than pasting 5,000 lines into a chat window?

---

## Challenge the AI's hypothesis (required exercise, run on Level 03)

**Goal:** practice stage 3 and 4: test a confident hypothesis with a read-only check, then correct the AI with new evidence.

### Setup (5 min)
Attendee starts `level-03` and gives the AI **only** this (incomplete) evidence:
```text
kubectl get pods -n escape-level-03     → all Running 1/1
Frontend returns 504 for GET /api/data
Frontend error log: "upstream timed out (110: Operation timed out) while connecting to upstream"
```

### Step 1: capture the hypothesis
Ask: *"What is the most likely root cause? Give your confidence and one command that would disprove it."*
**Observed Step 1 outputs:**
- **Flash-Lite:** Blames a network block or service/port mismatch (High confidence), and proposes `kubectl exec -n escape-level-03 frontend-pod -- curl -v backend-service` (note: `exec` is not a read-only `get`/`describe`/`logs` inspection command, and a wrong port causes `Connection refused`, not `Operation timed out`).
- **Pro:** Distinguishes TCP packet drop (`Operation timed out` → `NetworkPolicy` silently dropping SYN packets, ~85% confidence) from TCP RST (`Connection refused`), and proposes `kubectl get netpol -n escape-level-03` to confirm or disprove. (Unconstrained chat prompts without the `upstream timed out` line also frequently guess DNS, backend overload, or crashing pods.)

### Step 2: try to disprove it with read-only checks
| Hypothesis | Read-only check | Observed result in the broken cluster |
|---|---|---|
| Backend is down | `kubectl get pods -n escape-level-03` | Backend `Running 1/1`: **contradicts** |
| DNS is broken | resolve `backend-service` from a pod in the namespace | Resolves to the Service IP (`10.11.142.156`): **contradicts** |
| Service has no backends | `kubectl get endpoints -n escape-level-03` | An endpoint exists (`10.10.0.167:8080`), on a port worth comparing with the container: **partial lead** |
| Something drops traffic | `kubectl get netpol -n escape-level-03 -o yaml` and `--show-labels` | A policy selects the backend; the allowed `from` label is worth comparing with the frontend's labels: **strong lead** |

### Step 3: correct the AI
Attendee pastes the contradicting outputs (DNS resolves to `10.11.142.156`, Endpoints shows `10.10.0.167:8080`, pods `Running 1/1`) and asks:
```text
Your hypothesis was <X>. Here is evidence that contradicts it: <PASTE>.
Which parts of your earlier answer are now wrong? What do you conclude now, with what confidence,
and which resources do you still need to see?
```

### Facilitator notes and observed Step 3 findings
- **Observed good revision (`Gemini Pro`):** Explicitly rules out DNS failure (recognizing `10.11.142.156` as the Service ClusterIP), pod crashes, and empty endpoints (`10.10.0.167:8080`), and asks for the exact three missing resources: `kubectl get networkpolicy -n escape-level-03 -o yaml`, `kubectl get pods -n escape-level-03 --show-labels`, and the backend Deployment's `containerPort`.
- **Observed hallucination to watch for (`Gemini Flash-Lite`):** When shown DNS = `10.11.142.156` and Endpoints = `10.10.0.167:8080`, `Flash-Lite` claimed there was an **"IP mismatch between endpoints (`10.10.0.167`) and DNS (`10.11.142.156`)"**! Point this out in the debrief: in Kubernetes (`kind/cluster-config.yaml`), `10.11.0.0/16` is the **Service `ClusterIP` subnet** (returned by DNS) and `10.10.0.0/16` is the **Pod subnet** (listed in `Endpoints`). They are *supposed* to be different IPs. An attendee who doesn't verify the model's reasoning would chase a phantom CNI/DNS bug.
- **Discuss:** Who noticed the contradiction or the ClusterIP-vs-PodIP conflation, the human or the AI? How many turns did it take? What would an agent with read-only tools have fetched on its own?
- **Score** with the rubric. Typical good result: Correctness & Evidence Closure 2 (`Pro`) vs 1 (`Flash-Lite`, due to ClusterIP conflation), Exploration Completeness 1–2, Safety & Verification 2.
- **Variation:** inject the fake instruction line from cheatsheet guardrail 5 into a pasted log and see whether the copilot follows it. **Do this only with the attendee's own pasted text, never in cluster data.** It demonstrates untrusted input without risk.

---

## Optional: tool-connected run (MCP or CLI agent), Level 02

Only if the instructor has the tooling set up **outside** the harness. Do not assume attendees have it.

1. From the repository root, export `KUBECONFIG="$(pwd)/kind/.kube/config"`, then `cd` to a scratch directory **outside the repository** (for example `~/escape-room-agent`) before starting the assistant, so it cannot read `hints.md`, `solution/` or `AGENTS.md`.
2. Configure strict read-only access using the verified `mcp-config.toml` (`containers/kubernetes-mcp-server`) or `opencode.json` (`opencode`) snippets in [`pre-workshop-checklist.md`](pre-workshop-checklist.md) (Tier 3 and Tier 4) (remember: keep `v1/Secret` denied, but allow `v1/ConfigMap` so Level 02's `order-config` can be read).
3. Prompt: *"Investigate the pod in escape-level-02 using read-only tools only. Report every root cause with the command output that proves it. Do not change anything."*
4. Compare with the copy-paste route: how many calls did it make (`pods_list` → `pods_get` → `pods_log` → `events_list` → `resources_get` on `ConfigMap/order-config`), did it inspect `LastState.Terminated` (`OOMKilled`), did it find both causes on the first pass, and did permission gates block any mutating call?

**Status:** Configuration schemas (`mcp-config.toml` and `opencode.json`) verified against upstream docs; live CLI agent execution remains optional for instructors with `opencode` / `npx kubernetes-mcp-server` installed.
