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

## Hint 3: AI Copilot Prompt Recipe
Use the **SRE Copilot Prompt Pattern** (Context + Symptom + kubectl output + Goal)
with your favorite AI copilot (Gemini, ChatGPT, or Claude):

Copy and paste the following prompt into your AI copilot:

```text
I am troubleshooting an incident in a Kubernetes cluster where a critical service is down.

[Context]
Namespace: escape-level-01
Workload: Deployment payment-gateway
Expected: Pod is Running and ready to serve HTTP traffic.

[Symptom]
Pod status shows ErrImagePull / ImagePullBackOff.

[kubectl describe output]
<PASTE OUTPUT OF: kubectl describe pod -n escape-level-01 -l app=payment-gateway>

[Question]
1. What is the root cause of the ImagePullBackOff error?
2. What is a valid nginx alpine image tag to use?
3. Provide the exact kubectl command or YAML patch to fix this deployment immediately.
```
