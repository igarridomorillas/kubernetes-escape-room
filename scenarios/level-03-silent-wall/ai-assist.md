## Level 03 AI Copilot Guide — Cross-Resource Diffing, Hypothesis Disproof & Guardrails

**Scenario focus (`escape-level-03` / `frontend-service` → `backend-service`):** Stages 3 & 4 of the workflow (**Decide Next Check → Challenge the Hypothesis**) — correlating multi-resource networking state while rejecting unsafe shortcuts.

### Why default prompts fail here
When pods are `Running 1/1` but requests through `frontend-service` fail (`504` / `502`), single-resource prompts fail in three ways:
1. **Blind guessing:** An AI shown only one manifest blames DNS, readiness probes, or application crashes.
2. **Kubernetes networking hallucinations:** Smaller models often confuse a Service `ClusterIP` (from the service CIDR) with a Pod `Endpoint` IP (from the pod CIDR) and claim they "mismatch."
3. **Unsafe workarounds:** If you ask *"how do I quickly unblock traffic?"*, models frequently suggest deleting security policies, adding `allow-all` rules, or setting `hostNetwork: true`—destroying isolation instead of fixing the misconfiguration.

### How to interrogate the AI on Level 03
1. **Round 1 — Challenge its initial hypothesis with a read-only check:**
   Start by pasting only the symptom (`kubectl get pods -n escape-level-03` + the frontend proxy error log) and ask:
   ```text
   All pods in escape-level-03 are Running 1/1, but GET /api/data on frontend-service fails.
   What is your top hypothesis (with confidence %), what distinguishes a packet drop (timeout)
   from a connection refusal, and what SINGLE read-only kubectl command would disprove your guess?
   ```
2. **Round 2 — Cross-reference the full routing and policy chain:**
   Gather the related objects in `escape-level-03` (`endpoints`, Services, Deployment container ports, pod `--show-labels`, and any network policies) and ask for a field-by-field diff:
   ```text
   Cross-reference selectors, ports, and pod labels across all resources below in escape-level-03.
   1. Quote every pair of fields across two resources that are supposed to match but disagree.
   2. Propose the MINIMAL fix for each disagreement that strictly preserves least-privilege
      isolation (do NOT delete policies, allow all pods, or use hostNetwork/privileged mode).
   3. Which fix should I apply first so that I can observe a clear symptom shift (e.g. timeout
      changing to connection refused, or endpoints updating) before applying the second?
   ```
