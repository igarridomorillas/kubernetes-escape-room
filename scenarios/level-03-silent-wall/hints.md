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

## Hint 3: Time to Ask the Robot
Plot twist: today the AI is actually useful. 🤖

Every pod is healthy and yet nobody can talk to anybody. Run `make ai-assist`, paste the prompt
into your AI agent and let it chase the traffic across resources while you stretch your legs.

Check its homework, though: the AI proposes, the cluster decides.
