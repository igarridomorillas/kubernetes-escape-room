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
   - **Using a CLI agent?** Start it from a scratch directory **outside this repository** (see [Running a CLI agent](#running-a-cli-agent-outside-the-repo)).
4. **Check your fix:** `make verify`. On success the level is marked completed and the next step is shown.
5. **If you get stuck or want to retry:**
   - `make reset`: re-break the current level and try again.
   - `make solve`: apply the reference solution (instructor only).
6. **Move on:** `make start LEVEL=level-02` (then `level-03`, `level-04`). Starting a level removes the other levels' namespaces, so only one scenario is live at a time.
7. **Finish:** `make cleanup` tears down the cluster and removes the local state.

#### Running a CLI agent (outside the repo)

A CLI agent started in the repository root reads `AGENTS.md`, `hints.md`, `solution/` and `verify.sh`, which gives away the fix and defeats the exercise. Keep the repo for `make` and run the agent elsewhere, pointed at the cluster through an absolute `KUBECONFIG`:

```bash
# In the repository root: pin the cluster, then leave the repo
export KUBECONFIG="$(pwd)/kind/.kube/config"
mkdir -p ~/escape-room-agent && cd ~/escape-room-agent
opencode   # or your CLI agent of choice, with its read-only config saved in this directory
```

Keep one terminal in the repo for `make` and a second one in the scratch directory for the agent.

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
make slides-nexthink    # Nexthink meetup variant (Halloween theme, presenters, Nexthink and hiring slides)
make slides-nexthink-export  # export the Nexthink variant to PDF
make validate           # run shellcheck + permission (750) + relative-path checks
make test LEVEL=all     # run end-to-end smoke tests across all 4 levels (or LEVEL=level-01)
```

`start <level>` removes the namespaces of all other levels, so only one scenario is live at a time. Levels 02 and 04 ship small apps that `start` builds and loads into the cluster for you (no registry needed).

---

## AI plugin

`plugins/k8s-troubleshooting/` bundles a read-only troubleshooting skill and a guarded `kubernetes-mcp-server` config (read-only, Secrets denied; it uses your session's `KUBECONFIG`). Install it from this checkout into Claude Code with:

```bash
make plugin-install      # remove with: make plugin-uninstall
```

Then start Claude Code from a scratch directory outside the repo. Other CLI tools (Copilot CLI, opencode) are a TODO in [`docs/plugin-installation.md`](docs/plugin-installation.md). Requires `npx` for the MCP server.

---

## Repository structure

```
kubernetes-escape-room/
├── AGENTS.md                        # Agent & contributor conventions
├── README.md                        # Project overview & quickstart
├── Makefile                         # Task runner for slides, linting, validation & smoke tests
├── .mcp.json                        # Root Slidev MCP server config (CLI/IDE clients)
├── .claude-plugin/
│   └── marketplace.json             # Local marketplace so `make plugin-install` can install the plugin
├── plugins/
│   └── k8s-troubleshooting/         # Plugin: troubleshooting skill + read-only MCP config
│       ├── .claude-plugin/plugin.json
│       ├── .mcp.json
│       ├── config/mcp-config.toml
│       └── skills/k8s-troubleshooting/SKILL.md
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
    │   ├── slides.md                # Workshop presentation deck (M6): cover + shared content
    │   ├── style.css                # Deck theme (colors, cards, chips)
    │   ├── global-bottom.vue        # Slide numbers (<n>/<total>)
    │   ├── shared/
    │   │   └── workshop.md          # Slides and speaker notes shared by both decks
    │   └── nexthink/                # Nexthink meetup variant (own entry, theme and assets)
    │       ├── slides.md            # Presenters + Nexthink intro, shared slides, hiring slide
    │       ├── style.css            # Halloween theme (also used by the PDF export)
    │       ├── global-bottom.vue    # Progress bar + slide numbers
    │       └── public/              # Hiring QR code
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
    │   ├── 09-kubeconfig-paths-make-help.md  # Session 9: Absolute KUBECONFIG paths & grouped make help
    │   ├── 10-k8s-plugin.md                  # Session 10: k8s-troubleshooting plugin
    │   └── 11-nexthink-slides.md             # Session 11: Nexthink meetup slides
    ├── ai-prompts-cheatsheet.md     # One-page A4 SRE Copilot cheatsheet (M5/M6)
    ├── ai-exercises.md              # Instructor guide: bad vs good prompts per level, challenge exercise (M5)
    ├── ai-research-notes.md         # Cited sources on AI-assisted troubleshooting (M5)
    ├── plugin-installation.md       # Installing the k8s-troubleshooting plugin (Claude Code; other CLIs TODO)
    └── pre-workshop-checklist.md    # Instructor & attendee pre-event checklist (M6)
```

---

## Status

> ✅ **All milestones implemented (M1–M6 + Bonus Level 04).** See [`docs/pre-workshop-checklist.md`](docs/pre-workshop-checklist.md) for pre-event setup, [`docs/presentation/README.md`](docs/presentation/README.md) to run the Slidev deck, and [`docs/sessions/00-milestones.md`](docs/sessions/00-milestones.md) for milestone status and review gates.
