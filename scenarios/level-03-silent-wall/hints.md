# Level 03 Hints — The Silent Wall

## Hint 1: Conceptual Clue
Every pod reports `Running` and `1/1`, yet the frontend cannot get a response from
the backend. Pod health only tells you the containers are alive. It says nothing
about whether traffic can reach them.

Ask yourself:
- Which layer decides where a Service sends traffic, and on which port?
- Which layer decides which pods are *allowed* to send traffic to the backend?

## Hint 2: Kubernetes Investigation
Inspect the routing layer. Start with the endpoints the Service actually resolved to:

```bash
kubectl get endpoints -n escape-level-03
kubectl describe svc backend-service -n escape-level-03
```

Compare the port the Service forwards to with the port the backend container listens on.

Then look at the firewall rules and the labels they select:

```bash
kubectl get netpol -n escape-level-03 -o yaml
kubectl get pods -n escape-level-03 --show-labels
```

Check the `from` selector of the ingress rule against the labels on the frontend pod.

## Hint 3: AI Copilot Prompt Recipe
Use the **SRE Copilot Prompt Pattern** (Context + Symptom + kubectl output + Goal)
with your favorite AI copilot (Gemini, ChatGPT, or Claude):

Copy and paste the following prompt into your AI copilot:

```text
I am troubleshooting an incident in a Kubernetes cluster. Pods are all Running 1/1,
but the frontend returns 502 Bad Gateway when it calls the backend.

[Context]
Namespace: escape-level-03
Frontend: Deployment frontend, Service frontend-service (port 80)
Backend: Deployment backend (container listens on a port), Service backend-service
NetworkPolicy: backend-firewall (selects the backend pods)

[Symptom]
frontend-service returns 502 for GET /api/data. Pods are Running and Ready.

[kubectl output]
<PASTE OUTPUT OF: kubectl get endpoints -n escape-level-03>
<PASTE OUTPUT OF: kubectl get svc backend-service -n escape-level-03 -o yaml>
<PASTE OUTPUT OF: kubectl get netpol backend-firewall -n escape-level-03 -o yaml>
<PASTE OUTPUT OF: kubectl get pods -n escape-level-03 --show-labels>

[Goal]
1. Why is traffic from the frontend being dropped or refused? Quote the exact fields that disagree.
2. Provide the minimal kubectl command or YAML patch to fix the Service and the NetworkPolicy.
3. Explain how to confirm each fix separately before you apply the other.
```
