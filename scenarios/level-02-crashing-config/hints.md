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

## Hint 3: Time to Ask the Robot
Plot twist: today the AI is actually useful. 🤖

Your pod crashes faster than you can read the logs. Run `make ai-assist`, paste the prompt into
your AI agent and let it hunt for causes (plural, it can be greedy) while you refill your coffee.

Check its homework, though: the AI proposes, the cluster decides.
