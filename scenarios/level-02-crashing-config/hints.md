# Level 02 Hints — The Crashing Config

## Hint 1: Conceptual Clue
The pod starts, then dies, over and over. A container can stop for two very
different reasons: the application decides to exit because of its own checks,
or the Linux kernel kills it for breaking a rule.

Ask yourself:
- Is the application failing its own startup checks, or being killed from outside?
- Could both be happening, one hiding behind the other?
- Fixing one problem may reveal the next. Keep checking after each change.

## Hint 2: Kubernetes Investigation
Look at what the application says before it dies, and at how Kubernetes
records the way it died:

```bash
kubectl logs -n escape-level-02 -l app=order-processor
kubectl describe pod -n escape-level-02 -l app=order-processor
```

If the container is between restarts and `logs` is empty, add `--previous`.

In the `describe` output, look at:
- `Last State: Terminated`, including the `Reason` and `Exit Code`.
- The `Limits` and `Requests` of the container.
- Which ConfigMap the container gets its environment from:
  ```bash
  kubectl get configmap order-config -n escape-level-02 -o yaml
  ```
- Compare the names the application complains about with what the ConfigMap provides.

## Hint 3: AI Copilot Prompt Recipe
Use the **SRE Copilot Prompt Pattern** (Context + Symptom + kubectl output + Goal)
with your favorite AI copilot (Gemini, ChatGPT, or Claude):

Copy and paste the following prompt into your AI copilot:

```text
I am troubleshooting an incident in a Kubernetes cluster where a critical service keeps restarting.

[Context]
Namespace: escape-level-02
Workload: Deployment order-processor (Python app), configuration from ConfigMap order-config
Expected: Pod stays Running and Ready, and /healthz on port 8080 returns HTTP 200.

[Symptom]
Pod status flips between CrashLoopBackOff, Error and OOMKilled.

[Container logs]
<PASTE OUTPUT OF: kubectl logs -n escape-level-02 -l app=order-processor --tail=30>

[kubectl describe output]
<PASTE OUTPUT OF: kubectl describe pod -n escape-level-02 -l app=order-processor>

[ConfigMap]
<PASTE OUTPUT OF: kubectl get configmap order-config -n escape-level-02 -o yaml>

[Question]
1. List every distinct root cause you can see in this output (there may be more than one).
2. For each one, explain the evidence that points to it.
3. Provide the exact kubectl commands or YAML patches to fix them, and tell me the order to apply them in.
```
