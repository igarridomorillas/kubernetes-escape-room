# Pre-Workshop Checklist — Instructor & Attendee Guide

> This guide covers everything needed to prepare, verify, and run the **Kubernetes Escape Room** workshop (~55 min: 10 min talk, three levels, debrief), including step-by-step instructions that any facilitator (including non-SREs) can follow and fallback plans for common venue or laptop issues.

---

## 1. Attendee Prerequisites (Send 48 Hours Before Event)

Ask attendees to install the three required tools and run `make prepare` (Windows: `.\scripts\make.ps1 prepare`) **before arriving at the venue** so the cluster is created, the app images are built, and every scenario image is already downloaded on their laptops (this also confirms registry access and covers the download bandwidth).

### A. Required Tools (All Attendees)

| Tool | Minimum Version | Verification Command | Install Guide |
| :--- | :--- | :--- | :--- |
| **Docker Desktop** (or Docker Engine) | Running daemon (`>= 4 GB` RAM allocated) | `docker info` | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) (`brew install --cask docker`, Windows: `winget install Docker.DockerDesktop`) |
| **kind** (Kubernetes in Docker) | `>= 0.20.0` | `kind --version` | [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (`brew install kind`, Windows: `winget install Kubernetes.kind`) |
| **kubectl** | `>= 1.28` | `kubectl version --client` | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) (`brew install kubectl`; bundled with Docker Desktop on Windows) |
| **glow** *(optional)* | any | `glow --version` | [github.com/charmbracelet/glow](https://github.com/charmbracelet/glow) (`brew install glow`, Windows: `winget install charmbracelet.glow`). Renders hints and AI tips; without it they show as plain Markdown |

**Windows attendees** need no `make`, Bash or WSL: the PowerShell port runs on the built-in Windows PowerShell 5.1 (or PowerShell 7+). They replace `make` with `.\scripts\make.ps1` in every command (same targets, same `LEVEL=`), and should use Windows Terminal so colours and emoji render.

### B. Pre-Flight Cluster & Image Warm-Up (Run Before Event)

```bash
# 1. Clone the repository and enter the directory
git clone https://github.com/unai-ttxu/kubernetes-escape-room.git
cd kubernetes-escape-room

# 2. One command: create the Kind cluster (pinned Cilium 1.20.2 CNI), pull every
#    scenario, probe and base image, and build the Level 02 / 04 app images.
#    Images are discovered from scenarios/, so nothing needs to be listed by hand.
#    Scenario images are only pulled to the host cache, not loaded into the node.
#    (First run takes several minutes, depending on bandwidth)
make prepare

# 3. Optional: confirm the first level starts cleanly
make start LEVEL=level-01
```

On Windows, in PowerShell from the cloned repository:

```powershell
# Only if Windows blocks running scripts (affects this terminal only)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\scripts\make.ps1 prepare
.\scripts\make.ps1 start LEVEL=level-01
```

> **Note on `KUBECONFIG`:** `make setup` writes a repo-local kubeconfig at `kind/.kube/config` and also updates your active context to `kind-escape-room`. If you switch contexts in another terminal, run `export KUBECONFIG="$PWD/kind/.kube/config"` (PowerShell: `$env:KUBECONFIG = "$PWD\kind\.kube\config"`) so your manual `kubectl` commands always target the workshop cluster.

---

## 2. Optional AI Copilot Setup (Attendee Choice)

Every scenario is designed to work with **zero AI tooling setup** using any free web chat assistant. Attendees may choose whichever tier they prefer:

| Tier | Setup Required | How It Works |
| :--- | :--- | :--- |
| **Tier 1: Web Copilot (Default)** | **None** — open Gemini, ChatGPT, or Claude in a browser | Copy-paste raw `kubectl` output using the **SRE Copilot Prompt Pattern** in [`docs/ai-prompts-cheatsheet.md`](ai-prompts-cheatsheet.md) |
| **Tier 2: `k8sgpt`** | Optional (`k8sgpt` binary + an AI backend configured with `k8sgpt auth`) | Runs built-in analyzers locally (`k8sgpt analyze`); `--explain` sends the structured finding to the AI backend, `--anonymize` masks sensitive fields. Use it as a first look, then confirm with `describe` / `logs` |
| **Tier 3: Read-Only Kubernetes MCP Server** | Optional (`Node.js` / `npx` + MCP-capable client) | Calls read-only cluster tools (`pods_list`, `pods_get`, `pods_log`, `events_list`, `resources_get`) scoped to `kind/.kube/config` |
| **Tier 4: CLI Agent (`opencode`, `kubectl-ai`)** | Optional (CLI agent binary installed) | Runs `kubectl get`/`describe`/`logs` with a read-only permission policy (`opencode.json`) |

### Optional Tier 2 Setup: `k8sgpt`

Install `k8sgpt` from the [k8sgpt docs](https://k8sgpt.ai/docs/getting-started/overview), configure a backend with `k8sgpt auth` (a local model avoids sending cluster data off-machine), and point it at the workshop cluster:

```bash
export KUBECONFIG="$PWD/kind/.kube/config"
k8sgpt analyze --namespace escape-level-01 --explain --anonymize
k8sgpt analyze --filter=NetworkPolicy --namespace escape-level-03
```

> Not executed on the build machine (see [`ai-research-notes.md`](ai-research-notes.md), M4): verify the flags against the installed version before the event.

### Optional Tier 3 Setup: Read-Only Kubernetes MCP Server

If an attendee or instructor wants to use [`containers/kubernetes-mcp-server`](https://github.com/containers/kubernetes-mcp-server), create `mcp-config.toml` in the repository root (gitignored):

```toml
# mcp-config.toml — strict read-only profile scoped to the workshop cluster
read_only = true
disable_destructive = true
kubeconfig = "kind/.kube/config"
toolsets = ["core", "config"]

# Block Secret payloads; keep v1/ConfigMap readable for Levels 02 and 04
[[denied_resources]]
group = ""
version = "v1"
kind = "Secret"
```

Register the server in your MCP client configuration:

```json
{
  "mcpServers": {
    "k8s-escape-room": {
      "command": "npx",
      "args": ["-y", "kubernetes-mcp-server@0.0.69", "--config", "mcp-config.toml"],
      "env": { "KUBECONFIG": "kind/.kube/config" }
    }
  }
}
```

### Optional Tier 4 Setup: CLI Agent (`opencode`)

To restrict `opencode` to read-only cluster inspection (and prevent it from running `make solve`), save `opencode.json` in the repository root (gitignored) and launch with `KUBECONFIG=kind/.kube/config opencode`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "*": "ask",
    "edit": "ask",
    "shell": {
      "*": "ask",
      "kubectl get *": "allow",
      "kubectl describe *": "allow",
      "kubectl logs *": "allow",
      "kubectl delete *": "deny",
      "kubectl apply *": "deny",
      "kubectl patch *": "deny",
      "kubectl edit *": "deny",
      "kubectl replace *": "deny",
      "kubectl exec *": "deny",
      "make solve*": "deny",
      "./scripts/escape-room.sh solve*": "deny",
      "*make.ps1 solve*": "deny",
      "*escape-room.ps1 solve*": "deny"
    }
  }
}
```

---

## 3. Instructor Pre-Event Checklist

### A. 48 Hours Before the Workshop (Full Smoke Test)

Run this deterministic smoke test from the repository root to verify the harness, CNI, and all four scenarios (via `make` or directly with the scripts):

- [ ] **1. Install dev requirements & run static validations (`shellcheck`, script `750` permissions, relative paths):**
  ```bash
  make setup-dev
  make validate
  ```
- [ ] **2. Clean cluster setup:**
  ```bash
  make cleanup
  make setup
  ```
  *Expected:* Cluster `escape-room` is created, Cilium `1.20.2` and Hubble roll out, and `kubectl --kubeconfig kind/.kube/config get nodes` shows `Ready`.
- [ ] **3. Smoke-test all 4 levels (`level-01`, `level-02`, `level-03`, `level-04`):**
  ```bash
  make test LEVEL=all
  # Or test a single level: make test LEVEL=level-01
  ```
  *Expected:* Every level fails `verify` when broken, passes `verify` after `solve`, and fails `verify` again after `reset`.
- [ ] **3b. If any attendee uses Windows, repeat steps 1–3 on a Windows laptop with the PowerShell port** (ideally once in Windows PowerShell 5.1 and once in PowerShell 7):
  ```powershell
  .\scripts\make.ps1 setup-dev
  .\scripts\make.ps1 validate
  .\scripts\make.ps1 cleanup
  .\scripts\make.ps1 setup
  .\scripts\make.ps1 test LEVEL=all
  ```
- [ ] **4. Print or share handouts:**
  - Share [`docs/ai-prompts-cheatsheet.md`](ai-prompts-cheatsheet.md) (one-page A4 reference) with attendees.
  - Keep [`docs/ai-exercises.md`](ai-exercises.md) open on the instructor machine for bad/good prompt comparisons and facilitator notes (**do not share before levels are solved**).

### B. 30 Minutes Before the Workshop (Room Readiness)

- [ ] Start Docker Desktop on the instructor laptop and verify `export KUBECONFIG="$PWD/kind/.kube/config"`.
- [ ] Reset the instructor cluster to Level 01 so the live terminal demo is ready:
  ```bash
  make start LEVEL=level-01
  ```
- [ ] Launch the Slidev presentation server (opens at `http://localhost:3030`; presenter view at `http://localhost:3030/presenter`):
  ```bash
  make slides
  ```
- [ ] Increase terminal font size (`18pt+`) for projector visibility.

---

## 4. Workshop Pacing Guide (~55 Minutes)

| Time | Segment | Facilitator Action |
| :--- | :--- | :--- |
| `00:00–10:00` | **Talk: incidents, then vs now, AI best practices & tooling** | Present Slides 2–14: incident lifecycle, 5-stage evidence loop, guardrails, tooling tiers (`k8sgpt`, MCP, CLI agents), sharing skills/MCP; Slide 15 for the harness |
| `10:00–19:00` | **Level 01: The Ghost Image** | Attendees run `start level-01`. Compare vague prompt vs pasting `describe pod` Events (Slides 16–17) |
| `19:00–33:00` | **Level 02: The Crashing Config** | Attendees run `start level-02`. Highlight compound faults: `KeyError` in logs + `OOMKilled` in `describe` (Slides 18–19) |
| `33:00–50:00` | **Level 03: The Silent Wall** | Attendees run `start level-03`. Run the 5-min **Challenge the AI's Hypothesis** exercise (`504` vs `502`, ClusterIP vs Pod IP) (Slides 20–22) |
| `50:00–55:00` | **Debrief & Rubric** | Score AI assistance with the 4-criterion rubric, announce Level 04 as a take-home, and run `make cleanup` (Slides 23–24) |
| *Flex* | **Per-level targets** | Design targets are 8–10, 12–15 and 15–20 min (Levels 01–03). Fast rooms move on early; if you run long, skip the Level 03 exercise discussion rather than the debrief |
| *Take-home* | **Level 04: Ghost Microservices** | Not presented in the deck. Fast finishers or attendees run `start level-04` (`5,000`-line log haystack + `grep -A 5 -E "ERROR\|Exception"`) |

---

## 5. Troubleshooting & Fallback Playbooks

### Fallback 1: Venue Wi-Fi is Slow or Blocked During Image Pulls
- **Symptom:** `setup`, `prepare` or `verify` hangs pulling `quay.io/cilium/*`, `nginx:1.27-alpine`, or `curlimages/curl:8.11.1`.
- **Fix (Offline Image Bundle):** On a machine with cached images (such as the instructor laptop), export an image archive onto a USB drive or local LAN share:
  ```bash
  docker save -o escape-room-images.tar \
    nginx:1.27-alpine \
    python:3.12-alpine3.20 \
    curlimages/curl:8.11.1 \
    quay.io/cilium/cilium:v1.20.2 \
    quay.io/cilium/operator-generic:v1.20.2 \
    quay.io/cilium/hubble-relay:v1.20.2 \
    quay.io/cilium/hubble-ui:v0.13.6 \
    quay.io/cilium/hubble-ui-backend:v0.13.6
  ```
  Attendees load it directly into Docker and Kind without network access:
  ```bash
  docker load -i escape-room-images.tar
  kind load image-archive escape-room-images.tar --name escape-room
  ```

### Fallback 2: Attendee Laptop Cannot Run Docker or Kind
- **Symptom:** Docker Desktop will not start, insufficient RAM/disk, or restricted corporate laptop.
- **Fix (Pair Programming Mode):** Pair the attendee with a neighbor using **Driver / AI Navigator** roles:
  - **Driver** runs `make` targets and `kubectl` on their cluster.
  - **AI Navigator** crafts the prompts, challenges the AI's hypotheses, and checks every proposed command against the 6 guardrails before the Driver executes it.

### Fallback 3: Corporate VPN Overlaps with Kind Subnets (`10.10.0.0/16` or `10.11.0.0/16`)
- **Symptom:** `kubectl` commands time out or Cilium pods fail to route when a corporate VPN is active.
- **Fix:**
  1. Disconnect the corporate VPN during the local workshop (all levels run 100% locally inside Docker), **or**
  2. Edit `podSubnet` and `serviceSubnet` in `kind/cluster-config.yaml` to non-overlapping ranges and recreate the cluster (`make cleanup && make setup`).

### Fallback 4: Cluster Created Previously with `kindnet` or Stuck Control-Plane Taint
- **Symptom:** `setup` exits reporting `kindnet` is installed, or pods stay `Pending` with `node-role.kubernetes.io/control-plane:NoSchedule`.
- **Fix:** Recreate the cluster cleanly:
  ```bash
  make cleanup
  make setup
  ```

### Fallback 5: MCP Server or CLI Agent Fails to Connect
- **Symptom:** `npx kubernetes-mcp-server` or `opencode` errors out or lacks API credentials.
- **Fix:** Switch immediately to **Tier 1 (Web Copilot)**. Every level's `make ai-assist` prompt works in a chat assistant too: run the commands under "Collect the evidence" yourself and paste their output under the prompt.
