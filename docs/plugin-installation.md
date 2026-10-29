# Using the `k8s-troubleshooting` plugin

The plugin (`plugins/k8s-troubleshooting/`) bundles a read-only troubleshooting skill and a guarded `kubernetes-mcp-server` config (read-only, Secrets denied). `.claude-plugin/marketplace.json` makes this checkout a local marketplace, so `make plugin-install` installs it from disk (nothing is fetched from GitHub). Only **Claude Code** is supported for now; see the TODO below.

## Claude Code

From the repository root (requires `npx` for the MCP server):

```bash
make plugin-install      # remove with: make plugin-uninstall
```

This runs `claude plugin install k8s-troubleshooting --marketplace "$(pwd)"` (user scope). Then pin an absolute `KUBECONFIG` and start Claude Code from a scratch directory **outside** the repository (it would otherwise read `hints.md` and `solution/`):

```bash
export KUBECONFIG="$(pwd)/kind/.kube/config"
mkdir -p ~/escape-room-agent && cd ~/escape-room-agent
claude
```

Check `/plugin` (plugin loaded) and `/mcp` (`kubernetes` connected). To load the plugin for one session without installing: `claude --plugin-dir "<repo-root>/plugins/k8s-troubleshooting"`. Validate the files with `claude plugin validate .` from the repository root.

## TODO: other CLI tools

Not implemented or tested yet. Starting points:

- [ ] **GitHub Copilot CLI.** It reads the same `.claude-plugin/marketplace.json`, `skills/` and legacy `.mcp.json`: `copilot plugin marketplace add "$(pwd)"` then `copilot plugin install k8s-troubleshooting@escape-room-marketplace`. Unverified: the docs describe `${PLUGIN_ROOT}` expansion only for the newer `mcp.json` format, so `${CLAUDE_PLUGIN_ROOT}` in `.mcp.json` may not expand. Docs: [Finding and installing plugins](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing), [CLI plugin reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference).
- [ ] **opencode.** No marketplace: copy `plugins/k8s-troubleshooting/skills/k8s-troubleshooting` to `~/.config/opencode/skills/` and add an `mcp` entry (`type: local`, `command` array running `kubernetes-mcp-server@0.0.69 --config <repo-root>/plugins/k8s-troubleshooting/config/mcp-config.toml`) to `opencode.json`. Docs: [Agent skills](https://opencode.ai/docs/skills/), [MCP servers](https://opencode.ai/docs/mcp-servers/).
- [ ] Extend `make plugin-install` (e.g. a `TOOL=` variable) once the steps above are verified.
