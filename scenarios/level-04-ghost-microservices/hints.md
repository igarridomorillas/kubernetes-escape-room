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

## Hint 3: Time to Ask the Robot
Plot twist: today the AI is actually useful. 🤖

Five thousand log lines is a lot of haystack for human eyes. Run `make ai-assist`, paste the prompt
into your AI agent and let it find the needle while you pretend you knew where it was all along.

Check its homework, though: the AI proposes, the cluster decides.
