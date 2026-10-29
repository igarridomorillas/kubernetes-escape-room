# Session 10 — `k8s-troubleshooting` AI Plugin

> **Date:** 2026-10-29  
> **Status:** 🔍 In review (human sign-off pending)  
> **Branch:** `feat/marketplace`

---

## 🎯 Objectives

1. Ship one plugin, `k8s-troubleshooting`, with a read-only troubleshooting skill and a guarded MCP config.
2. Install it locally with `make plugin-install` during the workshop (Claude Code only; other CLIs are a TODO).

## 📦 Deliverables

| File | Change |
|---|---|
| `.claude-plugin/marketplace.json` | Local-only marketplace `escape-room-marketplace`, the vehicle for installs |
| `Makefile` | `plugin-install` / `plugin-uninstall` for Claude Code |
| `plugins/k8s-troubleshooting/.claude-plugin/plugin.json` | Plugin manifest (0.1.0) |
| `plugins/k8s-troubleshooting/skills/k8s-troubleshooting/SKILL.md` | Evidence-first, read-only loop distilled from `docs/ai-prompts-cheatsheet.md` |
| `plugins/k8s-troubleshooting/.mcp.json` + `config/mcp-config.toml` | `kubernetes-mcp-server@0.0.69`, read-only, Secrets denied, no hardcoded kubeconfig |
| `docs/plugin-installation.md` | Claude Code install steps; TODO list with starting points for Copilot CLI and opencode |
| `README.md`, `AGENTS.md` | Trees, plugin section, plugin rules |

## 🧠 Learnings

1. **No kubeconfig in the plugin.** The MCP server inherits the session's `KUBECONFIG`, so the plugin carries no absolute path (rule 6) and works for any cluster. `${CLAUDE_PLUGIN_ROOT}` locates the shipped toml.
2. **Server options are TOML-only.** `kubernetes-mcp-server@0.0.69` rejects `--read-only` and `--cluster-provider` (`unknown flag`); `read_only = true` and `cluster_provider_strategy = "kubeconfig"` live in `config/mcp-config.toml`.
3. **A gitignore pattern hid the plugin config.** The existing `mcp-config.toml` ignore rule also matched `plugins/k8s-troubleshooting/config/mcp-config.toml`, so the first commits shipped a plugin without it (the MCP server would not start). Fixed by anchoring the rule as `/mcp-config.toml` (root only); verify with `git ls-files plugins`.
4. **Persistent install needs a marketplace.** `claude plugin install` only installs from a marketplace, and `--plugin-dir` is per session. A first iteration dropped the marketplace; it came back as a local-path marketplace so `make plugin-install` works.
5. **`configuration_view` leaks the kubeconfig.** It is disabled with `disabled_tools` in the toml; `make check` now also scans `plugins/` and `.claude-plugin/` for home paths.
6. **Start the agent outside the repo.** The installed plugin is read live from the checkout, but the session's working directory must be a scratch directory, otherwise the agent reads `AGENTS.md`, `hints.md` and `solution/`.
7. **Other CLIs diverge (TODO, out of scope here).** Copilot CLI reads `skills/` and legacy `.mcp.json`, but its docs describe `${PLUGIN_ROOT}` expansion only for the newer `mcp.json` format, so `${CLAUDE_PLUGIN_ROOT}` there is unverified. opencode needs the skill copied and an `mcp` entry with a `<repo-root>` placeholder.

## ✅ Verification

- `claude plugin validate plugins/k8s-troubleshooting` passes; `make validate` passes.
- `make plugin-install` ran: Claude Code lists the plugin as installed and enabled.
- Not run (left unchecked): the MCP server connecting to the cluster, the skill triggering in a session. Copilot CLI and opencode are untested TODOs.

## Review checklist

- [ ] After `make plugin-install` and a restart, `/mcp` shows `kubernetes` connected
- [ ] Skill triggers on a failing-pod prompt against a running level
- [ ] TODO tracked in `docs/plugin-installation.md`: Copilot CLI and opencode
