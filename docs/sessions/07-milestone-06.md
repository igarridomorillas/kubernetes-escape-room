# Session 07 — Milestone 6: Workshop Presentation, Docs & Pre-Event Readiness

> **Date:** 2026-10-25  
> **Status:** 🔍 In review (human sign-off pending)  
> **Branch:** `feat/M6`

---

## 🎯 Objectives

Complete Milestone 6 by:
1. Configuring the [Slidev](https://sli.dev) presentation environment (`docs/presentation/`), the `slidevjs/slidev` agent skill (`.agents/skills/slidev/`), and the Slidev MCP server (`.agents/plugins/slidev/mcp_config.json` and `.mcp.json`), and authoring the 24-slide workshop presentation deck (`docs/presentation/slides.md`).
2. Creating [`docs/pre-workshop-checklist.md`](../pre-workshop-checklist.md) covering attendee prerequisites, optional AI copilot tiers, instructor 48h/30m readiness checks, pacing, and fallback playbooks.
3. Condensing [`docs/ai-prompts-cheatsheet.md`](../ai-prompts-cheatsheet.md) into a printable one-page A4 reference while preserving all 5 numbered sections referenced by [`docs/ai-exercises.md`](../ai-exercises.md) and [`docs/ai-research-notes.md`](../ai-research-notes.md).
4. Adding a root [`Makefile`](../../Makefile) to automate contributor setup (`setup-dev`), presentation preview/export (`slides`, `slides-export`), static validations (`lint`, `check`, `validate`), and scenario execution/smoke testing (`start`, `test`).

---

## 📦 Deliverables Created / Updated

| File | Purpose |
| :--- | :--- |
| [`docs/presentation/slides.md`](../presentation/slides.md) | 24-slide Slidev deck: incident management context, troubleshooting then vs now, AI best practices (5-stage loop, guardrails, tooling tiers incl. `k8sgpt`, MCP, sharing skills), Levels 01–03 briefings & debriefs, the Level 03 Challenge-the-AI-Hypothesis exercise, and the rubric (Level 04 is a take-home) |
| [`docs/presentation/package.json`](../presentation/package.json) | Slidev (`@slidev/cli`, `@slidev/theme-default`, `vue`) and PDF export (`playwright-chromium`) dependencies |
| [`docs/presentation/style.css`](../presentation/style.css), [`docs/presentation/global-bottom.vue`](../presentation/global-bottom.vue) | Deck theme and slide numbers (`<n>/<total>`) |
| [`docs/presentation/README.md`](../presentation/README.md) | Contributor guide for running Slidev locally, using the `slidev` skill, and configuring the Slidev MCP server |
| [`skills-lock.json`](../../skills-lock.json) | Pins the official `slidevjs/slidev` agent skill; files in `.agents/skills/` are gitignored and restored by `make setup-dev` (or `npx skills experimental_install`) |
| [`.agents/plugins/slidev/plugin.json`](../../.agents/plugins/slidev/plugin.json), [`mcp_config.json`](../../.agents/plugins/slidev/mcp_config.json), [`.mcp.json`](../../.mcp.json) | Slidev MCP server configuration for Antigravity and standard CLI/IDE MCP clients |
| [`docs/pre-workshop-checklist.md`](../pre-workshop-checklist.md) | Instructor pre-event smoke tests, attendee prerequisites, optional read-only MCP/CLI agent configs, ~55 min pacing guide, and 5 fallback playbooks |
| [`docs/ai-prompts-cheatsheet.md`](../ai-prompts-cheatsheet.md) | Condensed 68-line one-page A4 SRE Copilot reference (Prompt Pattern, 5-stage loop, clean `kubectl` extraction, common K8s AI hallucinations, 6 guardrails, 4-row rubric) |
| [`Makefile`](../../Makefile) | Task runner for `setup-dev`, `slides`, `slides-export`, `lint`, `check`, `validate`, cluster lifecycle commands, and `test` (`LEVEL=level-XX` or `LEVEL=all`) |
| [`AGENTS.md`](../../AGENTS.md), [`README.md`](../../README.md), [`docs/design/plan.md`](../design/plan.md), [`docs/sessions/00-milestones.md`](00-milestones.md), [`.gitignore`](../../.gitignore) | Synchronized directory trees, build/test commands, Amendment 7, and M6 learnings |

---

## 💡 Key Design Decisions & Learnings

1. **Subdirectory isolation (`docs/presentation/`) + `--prefix docs/presentation` for `npx` MCP:**
   - Keeping `package.json` inside `docs/presentation/` keeps the repository root clean for attendees running `./scripts/escape-room.sh`.
   - On npm, the Slidev CLI is published under `@slidev/cli` (which installs the `slidev` binary into `docs/presentation/node_modules/.bin/slidev`); there is no standalone `slidev` package on the npm registry. Therefore, invoking `npx` from the repository root requires `--prefix docs/presentation`:
     ```json
     {
       "mcpServers": {
         "slidev": {
           "command": "npx",
           "args": ["--prefix", "docs/presentation", "slidev", "mcp", "docs/presentation/slides.md"]
         }
       }
     }
     ```
2. **Slidev PDF export prerequisites (`playwright-chromium`):**
   - `slidev export` requires both `"playwright-chromium"` in `docs/presentation/package.json` and the Chromium browser binary installed via `npx --prefix docs/presentation playwright install chromium`. `make setup-dev` installs both (and restores the pinned agent skills); `make slides-export` runs `setup-dev` if they are missing and runs `slidev build` before exporting.
3. **Consolidated, parameterized `Makefile`:**
   - Instead of duplicating per-level targets (`level-01`..`04`, `test-level-01`..`04`, `smoke-test`) or separate `check-perms`/`check-paths` targets, the `Makefile` uses `make start LEVEL=level-XX`, `make test LEVEL=level-XX` (or `LEVEL=all`), `make check` (permissions + relative-path audit), and `make validate` (`lint` + `check`).
4. **Preserving section numbering in the condensed 1-page cheatsheet:**
   - [`docs/ai-exercises.md`](../ai-exercises.md) and [`docs/ai-research-notes.md`](../ai-research-notes.md) cross-reference sections 1–5 and guardrails 1–6 of [`docs/ai-prompts-cheatsheet.md`](../ai-prompts-cheatsheet.md). Condensing the cheatsheet to 68 lines while retaining all 5 section numbers ensures zero broken cross-references.

---

## ✅ Verification & Smoke Tests

Checks run:
- `make validate` (`make lint` + `make check`):
  - `shellcheck ./scripts/escape-room.sh scenarios/*/verify.sh` passed with 0 warnings.
  - All executable scripts verified at `chmod 750` (`-rwxr-x---`).
  - Relative-path audit confirmed 0 hardcoded `/Users/<name>` or `/home/<name>` paths across all repository files.
- Slidev MCP server, build & PDF export verification:
  - Verified JSON-RPC `initialize`, `slidev-get-info`, and `slidev-list-slides` over stdio via `npx --prefix docs/presentation slidev mcp docs/presentation/slides.md` (all 24 slides of the reworked deck parsed with titles, layouts, and speaker notes).
  - `npm --prefix docs/presentation run build` succeeded cleanly in `1.07s`.
  - `make slides-export` verified on the local host (rendered `docs/presentation/slides-export.pdf` via `playwright-chromium`).

---

## Review checklist

- [ ] Cheatsheet fits on one printed A4 page
- [ ] Hallucination section is clearly marked and pedagogically grounded
- [ ] Pre-workshop checklist can be followed by a non-SRE
- [ ] All docs and Slidev slides reviewed for accuracy against the final implemented scenarios
