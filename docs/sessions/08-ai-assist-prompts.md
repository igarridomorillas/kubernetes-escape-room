# Session 08 — Agent-ready `ai-assist` Prompts & Optional `glow` Rendering

> **Date:** 2026-10-28  
> **Status:** 🔍 In review (human sign-off pending)  
> **Branch:** `feat/improve_ai_assist`

---

## 🎯 Objectives

1. Keep [`docs/ai-prompts-cheatsheet.md`](../ai-prompts-cheatsheet.md) as the base for prompting in this workshop, and make each `scenarios/*/ai-assist.md` a worked example of it.
2. Give every level one prompt that can be pasted as is, with no placeholders, and run by an AI agent that gathers the evidence itself.
3. Make hints, the incident alert and `ai-assist` readable in the terminal, where Markdown is not rendered.

---

## 📦 Deliverables Created / Updated

| File | Purpose |
|---|---|
| [`scenarios/*/ai-assist.md`](../../scenarios/) | Rewritten: manual evidence commands, a bad prompt, the paste-ready prompt (RULES, ISSUE, TASK), a follow-up prompt and a short "why" |
| [`scripts/escape-room.sh`](../../scripts/escape-room.sh) | New `render_markdown`: pipes `incident.md`, hints and `ai-assist.md` through `glow` when installed, else `cat` |
| [`README.md`](../../README.md), [`docs/pre-workshop-checklist.md`](../pre-workshop-checklist.md) | `glow` listed as an optional prerequisite; `ai-assist` description and Tier 1 fallback updated |
| [`docs/presentation/slides.md`](../presentation/slides.md), [`docs/design/plan.md`](../design/plan.md) | Help-ladder wording; Amendment 8 |
| [`AGENTS.md`](../../AGENTS.md) | Harness behaviour for `render_markdown`, the optional-glow exception to rule 1, and a new `ai-assist.md` authoring rule |

---

## 💡 Key Design Decisions & Learnings

1. **The cheatsheet is the base, `ai-assist` applies it.** Each file links the stages and cheatsheet sections it demonstrates, so the technique lives in one place.
2. **No placeholders.** A prompt full of `<PASTE ...>` slots is slow to use and easy to get wrong. The final form states the ISSUE in one or two sentences and lets the agent collect evidence with read-only commands. The exact `kubectl` commands stay as a manual fallback for chat assistants.
3. **ISSUE restates the symptom from `incident.md`, never a cause.** This keeps the spoiler discipline: no root cause, no fix, no correct values.
4. **Handing evidence to the agent moves the traps into RULES.** Without an explicit evidence list, an agent can read logs alone (level 02) or dump 5,000 lines (level 04). Short level-specific rules cover this: check logs, container state and config together; filter logs with grep; look at the whole routing chain; never invent image tags.
5. **A one-sentence TASK is enough if the rules carry the technique.** The numbered steps were dropped. The two rules that matter stay: "list every distinct root cause with confidence and what would disprove it" and "never apply a fix yourself, only propose it". This replaced "read-only first until I ask for a fix", which contradicted a TASK that proposes a fix.
6. **"Read-only" is an instruction, not a guarantee.** Prompts forbid mutating commands, `make` targets and reading Secrets, but the MCP/CLI-agent restrictions in the pre-workshop checklist remain the real guardrail.
7. **Bad prompts are terse on purpose** (`My payment-gateway pod is in ImagePullBackOff. Fix it.`). A realistic bad prompt is a symptom plus "fix it", not a long prompt with a subtle flaw.
8. **`glow` is optional and zero-margin.** Its default style indents by 2 columns, indents code blocks further and pads every line with trailing spaces, so selected text does not paste back as written. A minimal embedded style (`margin: 0`, `-w 0`) fixes that. The harness never installs glow (rule 1 exception, documented in `AGENTS.md`).
9. **Process lessons:** prompts avoid the section-sign symbol; a line-range edit that ends at the first `}` breaks a function containing a JSON heredoc, so edit such functions with exact string matches; commits carry no AI co-author trailer.

---

## ✅ Verification & Smoke Tests

Checks run:
- `shellcheck scripts/escape-room.sh` clean; script still `750`.
- No placeholders, section-sign symbols or absolute home paths in `scenarios/*/ai-assist.md`.
- glow style tested on `ai-assist.md` with the colour codes stripped: no leading or trailing spaces except where the prompt text is itself indented.

Not run (left unchecked below): the cluster flows, glow on screen in a real terminal, and the prompts against an agent with `kubectl` access.

---

## Review checklist

- [ ] `make ai-assist` and `make hint` with glow: styled output, no indentation
- [ ] Same commands without glow and with `NO_COLOR=1`: plain Markdown, no errors
- [ ] Each level's prompt, pasted into an agent with `kubectl` access, runs only read-only commands and reaches the right diagnosis
- [ ] `ai-assist` output is still spoiler-free on all four levels
- [ ] Cheatsheet, `docs/ai-exercises.md` and the `ai-assist` examples are consistent
