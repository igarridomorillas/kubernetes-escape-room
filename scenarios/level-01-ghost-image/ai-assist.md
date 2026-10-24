## Level 01 AI Copilot Guide — Verbatim Events & Negative Constraints

**Scenario focus (`escape-level-01` / `payment-gateway`):** Stage 1 of the workflow (**Summarize Evidence**) — decoding kubelet lifecycle events without letting the AI guess from a generic checklist or invent unverified values.

### Why default prompts fail here
If you only tell an AI *"my `payment-gateway` pod is in `ImagePullBackOff`"* (or ask *"what value should I put in the manifest?"*), two things go wrong:
1. **Checklist sprawl:** Without raw event output, the model must guess across registry authentication (`imagePullSecrets`), network/DNS timeouts, rate limits, and image reference errors.
2. **Confident hallucination:** LLMs do not have live access to container registries in chat. If asked for a replacement identifier, they guess from training memory and often suggest non-existent or unpinned tags (like `latest`).

### How to interrogate the AI on Level 01
1. **Extract verbatim kubelet events:** Run `kubectl describe pod -n escape-level-01 -l app=payment-gateway` and copy the `Events:` table at the bottom.
2. **Force evidence classification:**
   ```text
   Workload payment-gateway in namespace escape-level-01 is failing to start.
   Below is the verbatim Events section from `kubectl describe pod`.
   1. Quote the exact substring in the event message that identifies the failure reason.
   2. Based only on that quote, classify whether this is a registry authentication error,
      a network/DNS timeout, or a missing reference, and explain what evidence rules out the other two.
   ```
3. **Set an explicit negative constraint:**
   ```text
   Do NOT guess or invent a replacement value from memory. Instead, give me the exact
   read-only command or registry query I can run to verify which valid versions exist.
   ```
