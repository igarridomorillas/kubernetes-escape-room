## Level 04 AI Copilot Guide — Call-Chain Tracing & Log Haystack Filtering

**Scenario focus (`escape-level-04` / `gateway` → `cart` → `payment`):** Stages 1 & 2 of the workflow (**Summarize Evidence → Hypothesize from Filtered Signals**) — isolating a needle in a multi-service, high-volume log haystack before prompting.

### Why default prompts fail here
When pods are `Running 1/1` and failures are intermittent across a 3-tier microservice chain, naive prompting fails in three ways:
1. **The `--tail=30` blind spot:** On a noisy service emitting thousands of healthy `INFO` and health-check lines, pasting `kubectl logs --tail=30` shows only `200 OK` traffic. The AI concludes the service is healthy and sends you chasing phantom network timeouts.
2. **Context window flooding:** Dumping 5,000 raw log lines into a web chat either hits message limits or buries the critical stack trace in the middle of the prompt ("lost in the middle").
3. **Blaming the messenger:** Pasting only the edge proxy (`gateway`) error log causes the AI to focus on `gateway` instead of following the upstream `500` down the call chain.

### How to interrogate the AI on Level 04
1. **Step 1 — Trace the cascading `500` across tiers before prompting:**
   Filter each tier's logs for `ERROR` (`kubectl logs -n escape-level-04 deployment/<tier> | grep ERROR`) to distinguish the services reporting an *upstream* `500` from the service that actually throws the exception.
2. **Step 2 — Extract the stack trace with context lines:**
   Once you identify the origin tier, extract only the error and its surrounding stack frames (for example, `grep -B 1 -A 5 -E "ERROR|Exception"`), rather than pasting thousands of `INFO` lines.
3. **Step 3 — Pair the stack trace with the workload's configuration manifests:**
   ```text
   In namespace escape-level-04 (gateway -> cart -> payment), POST /checkout intermittently
   returns HTTP 500 even though all pods are Running 1/1.
   Below are:
   - The upstream error lines from the caller tiers
   - The filtered exception stack trace from the origin service
   - The origin service's Deployment YAML and ConfigMap YAML
   1. Quote the exact line in the stack trace that identifies the failing request type.
   2. Cross-reference the stack trace against the Deployment and ConfigMap YAML and quote the
      exact field that explains the failure.
   3. Give the minimal change that fixes it and ensures the running pod picks it up.
   ```
