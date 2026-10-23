# Kubernetes Escape Room

> **Can you debug your way out — with AI as your copilot?**

A hands-on workshop for Platform, SRE, and Software Engineers. Teams race to diagnose and fix intentionally broken Kubernetes scenarios, using free AI tools (Gemini, ChatGPT, Claude) as their debugging partners.

---

## How it works

Each level presents a realistic incident alert. Pods are broken, traffic is down, the on-call is you. Use `kubectl`, the tiered hints, and AI copilots to escape before time runs out.

| Level | Name | Difficulty | Core concept | Status |
|---|---|---|---|---|
| 01 | The Ghost Image | ⭐ Warm-up | `ImagePullBackOff` / bad image tag | ✅ Available |
| 02 | The Crashing Config | ⭐⭐ Core | `CrashLoopBackOff` / OOMKill + ConfigMap mismatch | ✅ Available |
| 03 | The Silent Wall | ⭐⭐⭐ Boss | NetworkPolicy + Service port mismatch | 🚧 Planned |
| 04 | The Ghost in the Microservices | ⭐⭐⭐⭐ Bonus | Cascading 500s hidden in log noise | 🚧 Planned |

All levels run locally via a single CLI tool:

```bash
./scripts/escape-room.sh setup          # spin up a Kind cluster
./scripts/escape-room.sh start level-01 # inject the broken scenario (or level-02)
./scripts/escape-room.sh hint           # get a progressive hint
./scripts/escape-room.sh verify         # check if you've escaped
./scripts/escape-room.sh solve          # reveal the solution (instructor only)
./scripts/escape-room.sh reset          # re-break the current level and retry
./scripts/escape-room.sh cleanup        # tear down the Kind cluster
```

`start <level>` removes the namespaces of all other levels, so only one scenario is live at a time. Level 02 ships a small app that `start` builds and loads into the cluster for you (no registry needed).

---

## Repository structure

```
kubernetes-escape-room/
├── AGENTS.md                        # Agent & contributor conventions
├── scripts/
│   └── escape-room.sh               # Main CLI harness (pure Bash, zero deps)
├── kind/
│   ├── cluster-config.yaml          # Kind cluster definition (disableDefaultCNI)
│   ├── cni/
│   │   └── cilium.yaml              # Pinned Cilium 1.20.2 manifest (enforces NetworkPolicy)
│   └── .kube/config                 # Repo-local kubeconfig (gitignored, written by `setup`)
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
    │   ├── 02-milestone-02.md       # Session 2: Level 01 — The Ghost Image
    │   ├── 03-milestone-03.md       # Session 3: Level 02 — The Crashing Config
    │   └── 04-milestone-04.md       # Session 4: Level 03 — The Silent Wall
    ├── ai-prompts-cheatsheet.md     # SRE Copilot Prompt Pattern & AI guardrails (M5/M6, coming soon)
    ├── ai-research-notes.md         # Cited sources on AI-assisted troubleshooting (M5, coming soon)
    └── pre-workshop-checklist.md    # Instructor & attendee checklist (M6, coming soon)
```

---

## Prerequisites

```bash
docker --version   # Docker Desktop
kind --version     # >= 0.20.0
kubectl version    # >= 1.28
```

`./scripts/escape-room.sh setup` checks these for you and prints an install link if `docker` or `kind` is missing. `setup` also installs Cilium (needed so Level 03's NetworkPolicy is enforced), so the first run pulls extra images and takes a few minutes longer. It writes a repo-local kubeconfig, `kind/.kube/config`, which the CLI uses for every `kubectl` call, so your current kubectl context is never touched. A cluster created before Cilium was added must be recreated: `cleanup`, then `setup`. After a level is verified, the CLI shows the next step (e.g. `start level-02`); use `start <level>` to move between levels.

---

## Status

> 🚧 **Implementation in progress.** Levels 01–03 are implemented; level 04 (bonus) is not yet. Next: M5 (AI-assisted troubleshooting best practices, incl. optional MCP and CLI agents) and M6 (workshop docs). See [`docs/sessions/00-milestones.md`](docs/sessions/00-milestones.md) for the current milestone status and review gates.
