## Level 02 AI Copilot Guide — Compound Faults & Two-Turn Verification

**Scenario focus (`escape-level-02` / `order-processor`):** Stages 2 & 4 of the workflow (**Hypothesize All Causes → Verify One Change at a Time**) — overcoming LLM *incomplete exploration* when a workload has more than one bug.

### Why default prompts fail here
In compound incidents, the first error printed to stdout is rarely the whole story:
1. **Stopping at the first clue:** When given only `kubectl logs`, models almost always diagnose the first application error they see and stop—missing kernel or cgroup terminations that only appear in `kubectl describe pod`.
2. **Unjustified numbers:** When asked to adjust resource settings, models often pick arbitrary round numbers (`1Gi`) instead of sizing from the application's actual working set.

### How to interrogate the AI on Level 02
1. **Bundle all three signal sources in one prompt:**
   - Application output: `kubectl logs -n escape-level-02 -l app=order-processor` (and `--previous` if empty)
   - Kubelet container state: `Last State`, `Reason`, `Exit Code`, and `Limits`/`Requests` from `kubectl describe pod -n escape-level-02 -l app=order-processor`
   - Injected configuration: the config object referenced by the `order-processor` Deployment in `escape-level-02`
2. **Prompt for exhaustive root causes and sizing evidence:**
   ```text
   Deployment order-processor in namespace escape-level-02 is crash-looping.
   Below are the container logs, the container Status/Resources from `describe pod`,
   and the configuration object it loads.
   1. List EVERY independent root cause across both the application logs and the kernel/container
      termination state. Quote the exact line that proves each cause.
   2. If any resource setting needs adjustment, calculate the minimum safe value from the
      evidence in the logs rather than guessing a large number.
   ```
3. **Run a two-turn verification loop (do not apply two fixes at once):**
   Apply **only the first fix**, observe how the pod status or log output shifts, and paste the *new* output back into the chat:
   ```text
   I applied only the first change. Here is the new `logs` and `describe pod` output:
   <PASTE NEW OUTPUT>
   Confirm whether Cause #1 is resolved and explain what the remaining symptom proves.
   ```
