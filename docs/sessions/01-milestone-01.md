# Session 01 — Milestone 1: Core Harness & Cluster Setup

> **Date:** 2026-10-18  
> **Status:** ✅ Completed & Merged  
> **PR:** [#2](https://github.com/unai-ttxu/kubernetes-escape-room/pull/2) (`feat/M1`)  

---

## 🎯 Objectives

Implement the foundational test harness, cluster configuration, and repo state management for the Kubernetes Escape Room without introducing external runtime dependencies (no `jq`, no Python runtime requirement).

---

## 📦 Deliverables Created

| File | Purpose |
|---|---|
| [`kind/cluster-config.yaml`](../../kind/cluster-config.yaml) | Kind cluster definition mapping NodePort services to local host ports (`8080:30080` and `8443:30443`) |
| [`scripts/escape-room.sh`](../../scripts/escape-room.sh) | Executable Bash CLI harness managing the complete escape room lifecycle |
| [`.gitignore`](../../.gitignore) | Git exclusion rules for `.room-state`, kubeconfigs, and OS artifacts |
| [`docs/sessions/00-milestones.md`](00-milestones.md) | Milestone tracking with completed human review gates |

---

## ⚙️ CLI Commands Implemented

`./scripts/escape-room.sh <command>`

- `setup`: Verifies Docker and creates the `escape-room` Kind cluster.
- `start <level>`: Resets the level namespace, injects broken manifests, and prints the PagerDuty alert.
- `status`: Displays current scenario status, active pods, and relevant troubleshooting commands.
- `hint`: Sequentially displays hints 1 → 2 → 3 parsed from scenario markdown.
- `verify`: Executes the scenario's deterministic `verify.sh` probe in-cluster.
- `solve`: Applies the reference solution manifests (instructor / emergency use only).
- `reset`: Restores the initial broken scenario state without restarting the cluster.
- `cleanup`: Destroys the Kind cluster and resets local state.

---

## 💡 Key Design Decisions & Iterations

1. **Script Placement & Naming**:
   - Renamed from `./room` to [`scripts/escape-room.sh`](../../scripts/escape-room.sh) to maintain explicit script extensions and clear repository organization without root wrappers.
   - Set executable permissions to `750` (`-rwxr-x---`).

2. **Banner Design & Terminal Robustness**:
   - **Success banner typo fix**: Fixed the ASCII celebration banner to spell `ESCAPED!` (previously `CECAPED!`).
   - **Horizontal bar formatting**: Replaced fixed-width 3-sided boxes with `━━━━━` dividers in `print_banner` and incident alerts to prevent jagged right-border misalignment caused by variable multi-byte emoji lengths (`🚀`, `🔥`, `📊`, `🔓`, `♻️`).
   - **Multiline title banner**: Added bold red ANSI header formatted as two stacked lines (`K8S    ESCAPE` / `ROOM`) centered to fit comfortably within standard 80-column terminals.

3. **Zero External Runtime Dependencies**:
   - Built with pure POSIX Bash, `awk`, `sed`, `grep`, `kubectl`, `kind`, and `docker`.
   - Cluster state tracked via `.room-state` as plain INI key-value pairs.

---

## ✅ Verification & Review Gate

- [x] Shellcheck validation: `shellcheck scripts/escape-room.sh` passed with 0 errors/warnings.
- [x] Cluster creation: Kind cluster definition validated with correct extraPortMappings.
- [x] Missing scenario detection: Tested `start level-01` properly validates missing scenario directories before level implementation.
- [x] Human review gate completed and merged via PR #2.

---

## ⏭️ Next Step

Proceed to **Milestone 2**: Level 01 — "The Ghost Image" (`scenarios/level-01-ghost-image/`).
