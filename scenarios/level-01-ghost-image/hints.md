# Level 01 Hints — The Ghost Image

## Hint 1: Conceptual Clue
The container runtime is unable to start your application container.
Before Kubernetes can run a pod, the node's container runtime (containerd)
must download the container image from a remote image registry.

Ask yourself:
- Does the image tag specified in the Pod specification actually exist?
- Is there a typo or an invalid version number in the tag?

## Hint 2: Kubernetes Investigation
Inspect the detailed lifecycle events recorded by Kubernetes for the failing pod:

```bash
kubectl describe pod -n escape-level-01 -l app=payment-gateway
```

Look closely at the **Events** section at the bottom of the output:
- Look for `Failed to pull image` and `Error: ErrImagePull` / `ImagePullBackOff`.
- Notice the exact image string the kubelet attempted to pull.
- You can inspect the current image configuration using:
  ```bash
  kubectl get deployment payment-gateway -n escape-level-01 -o yaml | grep image:
  ```
- Compare that string with the tags actually published for the image on its registry.

## Hint 3: Time to Ask the Robot
Plot twist: today the AI is actually useful. 🤖

You've been staring at an image that refuses to be pulled. Run `make ai-assist`, paste the prompt
into your AI agent and let it do the `kubectl` legwork while you sip your coffee.

Check its homework, though: the AI proposes, the cluster decides.
