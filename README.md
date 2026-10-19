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
./scripts/escape-room.sh setup          # spin up a Kind cluster
./scripts/escape-room.sh start level-01 # inject the broken scenario
./scripts/escape-room.sh hint           # get a progressive hint
./scripts/escape-room.sh verify         # check if you've escaped
./scripts/escape-room.sh solve          # reveal the solution (instructor only)
./scripts/escape-room.sh reset          # re-break the current level and retry
./scripts/escape-room.sh cleanup        # tear down the Kind cluster
```

---

## Repository structure

```
kubernetes-escape-room/
├── AGENTS.md                        # Agent & contributor conventions
├── scripts/
│   └── escape-room.sh               # Main CLI harness (pure Bash, zero deps)
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
    │   ├── 00-milestones.md         # Milestone tracker & review gates
    │   ├── 01-milestone-01.md       # Session 1: Core harness & cluster setup
    │   └── 02-milestone-02.md       # Session 2: Level 01 — The Ghost Image
    ├── ai-prompts-cheatsheet.md     # SRE Copilot Prompt Pattern (coming soon)
    └── pre-workshop-checklist.md    # Instructor & attendee checklist (coming soon)
```

---

## Prerequisites

```bash
docker --version   # Docker Desktop
kind --version     # >= 0.20.0
kubectl version    # >= 1.28
```

`./scripts/escape-room.sh setup` checks these for you and prints an install link if `docker` or `kind` is missing. After a level is verified, the CLI shows the next step (e.g. `start level-02`); use `start <level>` to move between levels.

---

## Status

> 🚧 **Implementation in progress.** See [`docs/sessions/00-milestones.md`](docs/sessions/00-milestones.md) for the current milestone status and review gates.
