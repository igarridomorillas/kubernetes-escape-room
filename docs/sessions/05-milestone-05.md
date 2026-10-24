# Session 05 — Milestone 5: AI-Assisted Troubleshooting Best Practices

> **Date:** 2026-10-23  
> **Status:** ✅ Completed & Merged  
> **PR:** [#8](https://github.com/unai-ttxu/kubernetes-escape-room/pull/8) (`feat/M5`)

---

## 🎯 Objectives

Teach a repeatable, evidence-based way to use AI during an incident, using the scenarios to show **bad vs good practice**. Web copilots are the baseline; MCP servers and CLI agents are optional, read-only by default and scoped to `kind/.kube/config`. Mostly docs. The one harness change is the `ai-assist` command (added after the first review round); no `verify.sh` or manifest changed.

---

## 📦 Deliverables Created

| File | Purpose |
|---|---|
| [`docs/ai-prompts-cheatsheet.md`](../ai-prompts-cheatsheet.md) | 5-stage workflow with a prompt per stage, nine bad/good tips tied to levels, six guardrails (incl. a fake prompt-injection example), tool tiers (chat, runbook retrieval, verified `mcp-config.toml` and `opencode.json`), evaluation rubric |
| [`docs/ai-exercises.md`](../ai-exercises.md) | Instructor guide: empirical Model Evaluation Matrix (`Gemini Flash-Lite` vs `Gemini Pro`), bad/good prompts and facilitator notes per level, the required challenge-the-hypothesis exercise (Level 03), optional MCP/CLI-agent run |
| [`docs/ai-research-notes.md`](../ai-research-notes.md) | Cited sources with access dates; established vs emerging (incl. K8sGPT M4 and Runbook RAG M5); verification status; source conflicts |
| [`scenarios/*/ai-assist.md`](../../scenarios/) | One attendee-facing AI tip per level (bad vs good, spoiler-audited, no fix) |
| [`scripts/escape-room.sh`](../../scripts/escape-room.sh) | New `ai-assist` command: prints the current level's `ai-assist.md`; does not touch `HINT_LEVEL`; listed in `start` and usage |
| [`scenarios/level-03-silent-wall/incident.md`](../../scenarios/level-03-silent-wall/incident.md), [`hints.md`](../../scenarios/level-03-silent-wall/hints.md) | Updated gateway error wording from `502` to `504` / `502` to match observed Cilium behaviour |
| [`README.md`](../../README.md), [`AGENTS.md`](../../AGENTS.md) | Directory trees, command list, status and harness behaviour updated (rules 8, 16) |
| [`docs/sessions/00-milestones.md`](00-milestones.md) | M5 deliverables and review checklist |
| [`docs/design/plan.md`](../design/plan.md) | CLI spec and Amendment 5 (`docs/ai-exercises.md` and `ai-assist` command) |

---

## 💡 Key Design Decisions

1. **Facilitator notes are not in `hints.md`.** `extract_hint` prints everything under a hint heading, so notes after Hint 3 would reach attendees. They live in `docs/ai-exercises.md`, while attendee-facing tips live in `scenarios/*/ai-assist.md` and are shown by `./scripts/escape-room.sh ai-assist` (Amendment 5, flagged for review).
2. **Attendee docs never contain fixes.** The cheatsheet and `scenarios/*/ai-assist.md` describe symptoms and evidence only; answers and observed model outputs are in the instructor file (`docs/ai-exercises.md`).
3. **Primary sources over summaries.** A search summary claimed `kubernetes-mcp-server` has `--read-only` CLI flags and string-list `denied_resources`. The repo's own `docs/configuration.md` specifies `read_only = true` and `[[denied_resources]]` GVK tables in TOML (`--config`), and notes that `$KUBECONFIG` is not a CLI option. Furthermore, `v1/ConfigMap` must **not** be added to `[[denied_resources]]` because Level 02 requires inspecting `ConfigMap/order-config`. The same primary-source check was applied to `opencode` (`permission.shell` vs legacy `permission.bash`), `k8sgpt` (`analyze --explain --anonymize`), and Runbook RAG citations (RCACopilot, OpsEval, AutoBnB-RAG, IT Support RAG).
4. **Rubric scores evidence closure and exploration completeness, not only the verdict**, following Cloud-OpsBench (`arXiv:2603.00468`) and systematic RCA failure analysis (`arXiv:2602.09937`).

---

## ✅ Verification & Smoke Test

Checks that **were** run (fresh kind cluster with Cilium, repo-local kubeconfig):

- Level 01 broken: `ImagePullBackOff`; Events show `nginx:1.27.99-alpine ... not found`.
- Level 02 broken: logs show only `KeyError: 'DATABASE_URL'` then the cache line; `describe` shows `OOMKilled` / exit 137; `logs --previous` returned *unable to retrieve container logs* once.
- Level 03 broken: pods `Running 1/1`; endpoints show backend on `8080`; DNS resolves; frontend error log shows `upstream timed out` and a `504`.
- Level 03 with only the NetworkPolicy fixed: the symptom changes from `504` to `502` (`Connection refused`), as the exercise claims.

- `ai-assist`: `shellcheck scripts/escape-room.sh` clean; on levels 01–03 it prints the level tip, leaves `HINT_LEVEL` at 0, and `hint` still shows only Hint 1; with no active level it exits 1 with the usual "No active level" message; listed in `help`.
- **Spoiler audit (`scenarios/*/ai-assist.md`):** Audited all three files (`level-01-ghost-image/ai-assist.md`, `level-02-crashing-config/ai-assist.md`, `level-03-silent-wall/ai-assist.md`). None mention image tags, `DATABASE_URL`, `32MiB`, memory limits, `targetPort`, `8080`/`9000`, or label names.
- **Empirical LLM dry-run (2026-10-24):** Evaluated all 7 prompts (Levels 01–03 Bad, Good, and Level 03 Challenge Step 1 & Step 3) in zero-context sessions across two distinct model tiers (`Gemini Flash-Lite` and `Gemini Pro`). Recorded the full **Model Evaluation Matrix**, fix/verification order drift, and observed hallucinations (e.g., `Flash-Lite` missing `OOMKilled` on the Level 02 Bad prompt, proposing `targetPort` before `NetworkPolicy` curl verification on Level 03, and conflating the Service ClusterIP `10.11.142.156` with the Pod Endpoint IP `10.10.0.167`) in `docs/ai-exercises.md`.
- **Primary sources & configuration schemas verified (2026-10-24):**
  - `containers/kubernetes-mcp-server`: Verified `mcp-config.toml` schema (`read_only = true`, `disable_destructive = true`, `kubeconfig = "kind/.kube/config"`, and `[[denied_resources]]` GVK table blocking `v1/Secret` while keeping `v1/ConfigMap` readable for Level 02).
  - `opencode`: Verified `opencode.json` `permission.shell` (and V2 `permissions` / V1 `bash`) rule ordering.
  - `k8sgpt` (M4) & Runbook RAG (M5): Added primary sources (`k8sgpt-ai/k8sgpt` analyzer/anonymize docs; RCACopilot `arXiv:2305.15778`, OpsEval `arXiv:2310.07637`, AutoBnB-RAG `arXiv:2508.13118`, IT Support RAG `arXiv:2409.13707`) to `docs/ai-research-notes.md`.

Checks that were **not** run on the build machine (rule 18):

- **Live binary execution of `opencode`, `kubectl-ai`, and `k8sgpt`:** These optional CLI binaries are not installed on the local host; their configuration files and flags were verified against upstream primary documentation and remain flagged accordingly.

### Level 03 symptom note (`504` vs `502`)

In the initial broken state, the `NetworkPolicy` drops packets and the frontend returns **`504`** (`upstream timed out`); **`502`** (`Connection refused`) appears once the policy is fixed while the `targetPort` mismatch remains. `scenarios/level-03-silent-wall/incident.md` and `hints.md` were updated to mention `504` / `502` so they match both stages.

### Environment note

The first `setup` found an old `escape-room` kind cluster whose only node had the `node-role.kubernetes.io/control-plane:NoSchedule` taint, so pods (including Hubble) could not schedule. With the owner's approval it was recreated with `cleanup` then `setup`; the fresh cluster worked. Cause of the taint on the old cluster is unknown.

---

## Review checklist

- [x] All cited links resolve and dates are accurate (`for u in $(grep -oE 'https://[a-zA-Z0-9][^) >]+' docs/ai-research-notes.md | sort -u); do curl -s -o /dev/null -L -w '%{http_code} ' "$u"; echo "$u"; done`)
- [x] Established practices are clearly separated from emerging ideas
- [x] The challenge-the-hypothesis exercise has facilitator notes and expected findings
- [x] Guardrails section covers all six rules
- [x] MCP / opencode steps were tested, or are explicitly flagged as untested (config schemas verified against upstream docs; live binary execution flagged not run locally)
- [x] Workflow is coherent with the existing level hints (Concept → Investigation → AI prompt)
- [x] `./scripts/escape-room.sh ai-assist` on each level: tips are useful and give nothing away (spoiler-audited)
- [x] Dry-run the "bad" and "good" prompts with at least one free copilot and adjust the expected-behavior lines (completed across `Gemini Flash-Lite` and `Gemini Pro`; see Model Evaluation Matrix in `docs/ai-exercises.md`)

---

## ⏭️ Next Step

Proceed to **Bonus Level 04** ("The Ghost in the Microservices") and **Milestone 6** (pre-workshop checklist and the one-page A4 cheatsheet condensed from `docs/ai-prompts-cheatsheet.md`).
