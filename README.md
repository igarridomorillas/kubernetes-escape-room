# Kubernetes Escape Room

> **Can you debug your way out — with AI as your copilot?**

A hands-on workshop for Platform, SRE, and Software Engineers. Teams race to diagnose and fix intentionally broken Kubernetes scenarios, using AI copilots, CLI agents, and agentic harnesses as their debugging partners.

> [!WARNING]
> **Partially vibe-coded, on purpose.** Parts of this repository were vibe coded with AI tools as an experiment: we wanted to see how far an AI-assisted approach gets us when preparing this workshop. As SREs, we would never ship this way to production, but for a workshop we are keeping it relaxed. Treat the code as a fun experiment and review it before reusing it anywhere that matters. 😄

---

## Prerequisites

> [!NOTE]
> **Supported platforms:** macOS and Linux distributions. Windows is not supported.

| Tool | Version | Check | Install guide |
|---|---|---|---|
| `make` | any | `make --version` | [GNU Make](https://www.gnu.org/software/make/) |
| `docker` | daemon running | `docker info` | [Docker Desktop](https://docs.docker.com/desktop/) (macOS) / [Docker Engine](https://docs.docker.com/engine/install/) (Linux) |
| `kind` | `>= 0.20.0` | `kind --version` | [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| `kubectl` | `>= 1.28` | `kubectl version --client` | [Install tools](https://kubernetes.io/docs/tasks/tools/#kubectl) |
| `glow` *(optional)* | any | `glow --version` | [glow](https://github.com/charmbracelet/glow#installation) (`brew install glow`). Renders hints and AI tips; without it they show as plain Markdown |

---

## Prepare

Run this once before the workshop (instructors, assistants and attendees), ideally on the venue network or a comparable connection:

```bash
make prepare
```

It runs `make setup`, then pulls every image the scenarios use and builds the app images for Levels 02 and 04. Images are discovered dynamically from `scenarios/` (manifests, `verify.sh`, docs and Dockerfile `FROM` lines), so nothing needs to be listed by hand. This confirms registry access and covers the download bandwidth up front. Pulled images stay in the host Docker cache and are not loaded into the kind node.

---

## How it works

Each level presents a realistic incident alert. Pods are broken, traffic is down, the on-call is you. Use `kubectl`, the tiered hints, and AI copilots to escape before time runs out.

| Level | Name | Difficulty | Core concept | Status |
|---|---|---|---|---|
| 01 | The Ghost Image | ⭐ Warm-up | `ImagePullBackOff` / bad image tag | ✅ Available |
| 02 | The Crashing Config | ⭐⭐ Core | `CrashLoopBackOff` / OOMKill + ConfigMap mismatch | ✅ Available |
| 03 | The Silent Wall | ⭐⭐⭐ Boss | NetworkPolicy + Service port mismatch | ✅ Available |
| 04 | The Ghost in the Microservices | ⭐⭐⭐⭐ Bonus | Cascading 500s hidden in log noise | ✅ Available |

### How to use

Run the steps in this order. Every level needs a cluster first, so `make setup` (or `make prepare`) always comes before `make start`.

1. **Create the cluster (once):** `make setup`, or `make prepare` to also pre-pull images and build the app images.
2. **Start a level:** `make start LEVEL=level-01`. It injects the broken scenario and shows the incident alert.
3. **Investigate and fix it** with `kubectl` and your AI copilot. While you work, you can use:
   - `make status`: active level and pod statuses.
   - `make hint`: next progressive hint (concept, then investigation commands, then a nudge to run `make ai-assist`).
   - `make ai-assist`: a paste-ready prompt for an AI agent with `kubectl` access, plus a bad-prompt example and a follow-up prompt. It never spoils the fix and doesn't use up a hint.
4. **Check your fix:** `make verify`. On success the level is marked completed and the next step is shown.
5. **If you get stuck or want to retry:**
   - `make reset`: re-break the current level and try again.
   - `make solve`: apply the reference solution (instructor only).
6. **Move on:** `make start LEVEL=level-02` (then `level-03`, `level-04`). Starting a level removes the other levels' namespaces, so only one scenario is live at a time.
7. **Finish:** `make cleanup` tears down the cluster and removes the local state.

All levels run locally through `make` targets (the harness behind them is `scripts/escape-room.sh`):

```bash
make setup                     # spin up a Kind cluster with Cilium
make prepare                   # setup + pull all images + build app images (see Prepare)
make start LEVEL=level-01      # inject the broken scenario (level-01 … level-04)
make status                    # check active level & pod statuses
make hint                      # get a progressive hint
make ai-assist                 # tip for using an AI copilot on this level
make verify                    # check if you've escaped
make solve                     # reveal the solution, instructor only
make reset                     # re-break the current level and retry
make cleanup                   # tear down the Kind cluster
```

> [!NOTE]
> **Kubeconfig:** `make setup` writes a repo-local kubeconfig to `kind/.kube/config` (gitignored, removed by `make cleanup`). Every `make` target and `verify.sh` uses it automatically, so your current `kubectl` context is never touched. To run your own `kubectl` commands against the escape-room cluster, point your shell at it from the repository root:
>
> ```bash
> export KUBECONFIG="$(pwd)/kind/.kube/config"
> ```

Run `make help` for the full target list, grouped into level-running and contributor targets. For instructors and contributors, `Makefile` also provides presentation and validation workflows:

```bash
make setup-dev          # install contributor deps (shellcheck, Slidev, Playwright Chromium, agent skills)
make slides             # launch the live Slidev presentation (http://localhost:3030)
make slides-export      # build and export the presentation deck to PDF
make validate           # run shellcheck + permission (750) + relative-path checks
make test LEVEL=all     # run end-to-end smoke tests across all 4 levels (or LEVEL=level-01)
```

`start <level>` removes the namespaces of all other levels, so only one scenario is live at a time. Levels 02 and 04 ship small apps that `start` builds and loads into the cluster for you (no registry needed).

---

## Repository structure

```
kubernetes-escape-room/
├── AGENTS.md                        # Agent & contributor conventions
├── README.md                        # Project overview & quickstart
├── Makefile                         # Task runner for slides, linting, validation & smoke tests
├── .mcp.json                        # Root Slidev MCP server config (CLI/IDE clients)
├── skills-lock.json                 # Agent skills lockfile
├── .agents/
│   ├── skills/
│   │   └── slidev/                  # Slidev skill (gitignored; restore: npx skills experimental_install)
│   └── plugins/
│       └── slidev/                  # Antigravity workspace plugin (plugin.json + mcp_config.json)
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
    ├── presentation/
    │   ├── README.md                # Slidev + MCP contributor guide
    │   ├── package.json             # Slidev dependencies & scripts
    │   ├── slides.md                # Workshop presentation deck (M6)
    │   ├── style.css                # Deck theme (colors, cards, chips)
    │   └── global-bottom.vue        # Slide numbers (<n>/<total>)
    ├── sessions/
    │   ├── 00-milestones.md         # Milestone tracker & review gates
    │   ├── 01-milestone-01.md       # Session 1: Core harness & cluster setup
    │   ├── 02-milestone-02.md       # Session 2: Level 01 — The Ghost Image
    │   ├── 03-milestone-03.md       # Session 3: Level 02 — The Crashing Config
    │   ├── 04-milestone-04.md       # Session 4: Level 03 — The Silent Wall
    │   ├── 05-milestone-05.md       # Session 5: AI-assisted troubleshooting best practices
    │   ├── 06-level-04.md           # Session 6: Bonus Level 04 — The Ghost in the Microservices
    │   ├── 07-milestone-06.md       # Session 7: Workshop presentation, docs & pre-event readiness
    │   ├── 08-ai-assist-prompts.md  # Session 8: Agent-ready ai-assist prompts & optional glow rendering
    │   └── 09-kubeconfig-paths-make-help.md  # Session 9: Absolute KUBECONFIG paths & grouped make help
    ├── ai-prompts-cheatsheet.md     # One-page A4 SRE Copilot cheatsheet (M5/M6)
    ├── ai-exercises.md              # Instructor guide: bad vs good prompts per level, challenge exercise (M5)
    ├── ai-research-notes.md         # Cited sources on AI-assisted troubleshooting (M5)
    └── pre-workshop-checklist.md    # Instructor & attendee pre-event checklist (M6)
```

---

## Status

> ✅ **All milestones implemented (M1–M6 + Bonus Level 04).** See [`docs/pre-workshop-checklist.md`](docs/pre-workshop-checklist.md) for pre-event setup, [`docs/presentation/README.md`](docs/presentation/README.md) to run the Slidev deck, and [`docs/sessions/00-milestones.md`](docs/sessions/00-milestones.md) for milestone status and review gates.
