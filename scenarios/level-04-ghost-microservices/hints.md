# Level 04 Hints — The Ghost in the Microservices

## Hint 1: Conceptual Clue
Every pod in `escape-level-04` is `Running 1/1` and passing `/healthz`, and most checkout
requests succeed. In a multi-tier architecture (`gateway` → `cart` → `payment`), an `HTTP 500`
at the gateway often means a downstream service threw an unhandled exception that cascaded
back up the call chain.

Also beware of the **log haystack**: when a busy service emits thousands of `INFO` lines
for successful transactions and health checks, `kubectl logs --tail=20` will only show recent
healthy traffic.

Ask yourself:
- Which of the three services actually originates the `500` error, and which ones are only reporting an upstream failure?
- How can you filter thousands of log lines to extract only the error and its stack trace?

## Hint 2: Kubernetes Investigation
First, trace the `ERROR` lines across the three tiers to see where the failure starts:

```bash
kubectl logs -n escape-level-04 deployment/gateway | grep ERROR
kubectl logs -n escape-level-04 deployment/cart | grep ERROR
```

Next, search the 5,000-line log stream of the `payment` service with context lines around the error so you capture the full stack trace:

```bash
kubectl logs -n escape-level-04 deployment/payment | grep -A 5 -E "ERROR|Exception"
```

Read the exception message carefully:
- Which payment method triggers the unhandled exception?
- What does the stack trace say is `null`, and where does that service get its runtime settings from?
- Inspect how the `payment` workload is configured:
  ```bash
  kubectl describe deployment payment -n escape-level-04
  kubectl get events -n escape-level-04
  ```

## Hint 3: AI Copilot Prompt Recipe
Use the **SRE Copilot Prompt Pattern** (Context + Symptom + kubectl output + Goal)
with your favorite AI copilot (Gemini, ChatGPT, or Claude).

Do **not** paste all 5,000 lines of logs—paste only the filtered stack trace together with the Deployment and ConfigMap manifests:

```text
I am troubleshooting intermittent HTTP 500 errors in a 3-tier Kubernetes checkout pipeline (gateway -> cart -> payment).

[Context]
Namespace: escape-level-04
Workloads: Deployment gateway, Deployment cart, Deployment payment, ConfigMap payment-config
Expected: POST /checkout on gateway returns HTTP 200 for all payment methods, including credit_card and coupon.

[Symptom]
All pods are Running 1/1 and standard card checkouts succeed, but coupon checkouts fail with HTTP 500.

[Filtered error log from payment]
<PASTE OUTPUT OF: kubectl logs -n escape-level-04 deployment/payment | grep -A 5 -E "ERROR|Exception">

[payment Deployment env section & payment-config ConfigMap]
<PASTE OUTPUT OF: kubectl get deployment payment -n escape-level-04 -o yaml>
<PASTE OUTPUT OF: kubectl get configmap payment-config -n escape-level-04 -o yaml>

[Goal]
1. Explain why the exception occurs only for coupon checkouts while health checks and card payments pass.
2. Quote the exact line in the stack trace and the exact manifest field that explain the root cause.
3. Provide the minimal kubectl command or YAML patch to fix it and roll out the updated payment pod.
```
