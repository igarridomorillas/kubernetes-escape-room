# Kubernetes Escape Room

> **Can you debug your way out — with AI as your copilot?**

A hands-on workshop for Platform, SRE, and Software Engineers. Teams race to diagnose and fix intentionally broken Kubernetes scenarios, using free AI tools (Gemini, ChatGPT, Claude) as their debugging partners.

---

## How it works

Each level presents a realistic incident alert. Pods are broken, traffic is down, the on-call is you. Use `kubectl`, the tiered hints, and AI copilots to escape before time runs out.

| Level | Name | Difficulty | Core concept |
|---|---|---|---|
| 01 | The Ghost Image | ⭐ Warm-up | `ImagePullBackOff` / bad image tag |
| 02 | The Crashing Config | ⭐⭐ Core | `CrashLoopBackOff` / OOMKill + ConfigMap mismatch |
| 03 | The Silent Wall | ⭐⭐⭐ Boss | NetworkPolicy + Service port mismatch |
| 04 | The Ghost in the Microservices | ⭐⭐⭐⭐ Bonus | Cascading 500s hidden in log noise |

All levels run locally via a single CLI tool:

```bash
./room setup          # spin up a Kind cluster
./room start level-01 # inject the broken scenario
./room hint           # get a progressive hint
./room verify         # check if you've escaped
./room solve          # reveal the solution (instructor only)
```

---

## Repository structure

```
kubernetes-escape-room/
├── AGENTS.md                        # Agent & contributor conventions
├── room                             # Main CLI harness (pure Bash, zero deps)
├── kind/
│   └── cluster-config.yaml          # Kind cluster definition
├── scenarios/
│   ├── level-01-ghost-image/
│   ├── level-02-crashing-config/
│   ├── level-03-silent-wall/
│   └── level-04-ghost-microservices/
└── docs/
    ├── design/
    │   └── plan.md                  # Architecture & implementation plan
    ├── sessions/
    │   └── 00-milestones.md         # Milestone tracker & review gates
    ├── ai-prompts-cheatsheet.md     # SRE Copilot Prompt Pattern (coming soon)
    └── pre-workshop-checklist.md    # Instructor & attendee checklist (coming soon)
```

---

## Prerequisites

```bash
docker --version   # Docker Desktop or Colima
kind --version     # >= 0.20.0
kubectl version    # >= 1.28
```

---

## Status

> 🚧 **Implementation in progress.** See [`docs/sessions/00-milestones.md`](docs/sessions/00-milestones.md) for the current milestone status and review gates.
