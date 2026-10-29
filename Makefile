.PHONY: help \
	setup-dev slides slides-export slides-nexthink slides-nexthink-export plugin-install plugin-uninstall \
	lint check validate \
	setup prepare cleanup start status hint ai-assist verify solve reset \
	test

SHELL := bash
HARNESS := ./scripts/escape-room.sh
SLIDES_DIR := docs/presentation
LEVEL ?= level-01
ALL_LEVELS := level-01 level-02 level-03 level-04
PLUGIN := k8s-troubleshooting
MARKETPLACE := escape-room-marketplace

##@ General
help: ## Show this help menu
	@echo ""
	@echo "Kubernetes Escape Room — Makefile Targets"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@awk 'BEGIN {FS = ":.*##"} \
		/^##@/ {sub(/^##@ */, ""); if ($$0 != sec) {sec = $$0; printf "\n\033[1m%s\033[0m\n", sec}} \
		/^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

# ─── Contributor & Presentation Setup ─────────────────────────────────────────

##@ Build & dev (contributors)

setup-dev: ## Install contributor/dev requirements (shellcheck, Slidev, Playwright & agent skills)
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		if command -v brew >/dev/null 2>&1; then \
			echo "→ Installing shellcheck via Homebrew..."; \
			brew install shellcheck; \
		else \
			echo "⚠ shellcheck not found. Install it via your package manager (e.g., apt/dnf/brew)."; \
		fi; \
	else \
		echo "✓ shellcheck is installed."; \
	fi
	@echo "→ Installing Slidev dependencies in $(SLIDES_DIR)..."
	npm --prefix $(SLIDES_DIR) install
	@echo "→ Installing Playwright Chromium for PDF export..."
	npx --prefix $(SLIDES_DIR) playwright install chromium
	@echo "→ Restoring pinned agent skills from skills-lock.json..."
	@npx --yes skills experimental_install || echo "⚠ Could not restore agent skills; run 'npx skills experimental_install' manually."

slides: ## Start the live-reloading Slidev presentation server (http://localhost:3030)
	@test -d $(SLIDES_DIR)/node_modules || $(MAKE) setup-dev
	npm --prefix $(SLIDES_DIR) run dev

slides-export: ## Build and export presentation slides to PDF
	@test -d $(SLIDES_DIR)/node_modules/playwright-chromium || $(MAKE) setup-dev
	@npx --prefix $(SLIDES_DIR) playwright install chromium >/dev/null
	npm --prefix $(SLIDES_DIR) run build
	npm --prefix $(SLIDES_DIR) run export

slides-nexthink: ## Start the Nexthink meetup variant of the slides (http://localhost:3030)
	@test -d $(SLIDES_DIR)/node_modules || $(MAKE) setup-dev
	npm --prefix $(SLIDES_DIR) run dev:nexthink

slides-nexthink-export: ## Build and export the Nexthink meetup slides to PDF
	@test -d $(SLIDES_DIR)/node_modules/playwright-chromium || $(MAKE) setup-dev
	@npx --prefix $(SLIDES_DIR) playwright install chromium >/dev/null
	npm --prefix $(SLIDES_DIR) run build:nexthink
	npm --prefix $(SLIDES_DIR) run export:nexthink

plugin-install: ## Install the k8s-troubleshooting plugin from this checkout into Claude Code
	@command -v claude >/dev/null 2>&1 || { echo "✗ claude CLI not found. See https://claude.com/claude-code"; exit 1; }
	@claude plugin uninstall $(PLUGIN)@$(MARKETPLACE) >/dev/null 2>&1 || true
	claude plugin install $(PLUGIN) --marketplace "$$(pwd)"
	@echo "✓ Installed. Restart Claude Code, export KUBECONFIG=\"$$(pwd)/kind/.kube/config\" and start it from a directory outside this repo."

plugin-uninstall: ## Remove the k8s-troubleshooting plugin and local marketplace from Claude Code
	@command -v claude >/dev/null 2>&1 || { echo "✗ claude CLI not found."; exit 1; }
	@claude plugin uninstall $(PLUGIN)@$(MARKETPLACE) || true
	@claude plugin marketplace remove $(MARKETPLACE) || true

# ─── Validation & Linting ─────────────────────────────────────────────────────

lint: ## Run shellcheck on escape-room.sh and all scenario verify.sh scripts
	shellcheck $(HARNESS) scenarios/*/verify.sh

check: ## Enforce script permissions (chmod 750; git only tracks 755) and no hardcoded user home paths
	@for f in $(HARNESS) scenarios/*/verify.sh; do \
		perm="$$(stat -f '%Lp' "$$f" 2>/dev/null || stat -c '%a' "$$f")"; \
		if [[ "$$perm" != "750" ]]; then \
			echo "→ $$f has permissions $$perm; setting 750 (git only tracks the executable bit)"; \
			chmod 750 "$$f"; \
		fi; \
	done
	@echo "✓ All executable scripts have 750 permissions."
	@if grep -rnE '(/Users/[a-zA-Z0-9_-]+|/home/[a-zA-Z0-9_-]+)' \
		--exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.slidev \
		docs/ scenarios/ scripts/ plugins/ .claude-plugin/ README.md .mcp.json .agents/; then \
		echo "✗ Found hardcoded user home path(s) above."; \
		exit 1; \
	fi
	@echo "✓ No hardcoded user home paths found."

validate: lint check ## Run all static validations (lint + check)

# ─── End-to-End Level Smoke Testing ───────────────────────────────────────────

test: ## DESTRUCTIVE: smoke-test levels, resets .room-state (make test LEVEL=level-01 or LEVEL=all)
	@levels="$(LEVEL)"; \
	if [[ "$$levels" == "all" ]]; then \
		levels="$(ALL_LEVELS)"; \
	fi; \
	for lvl in $$levels; do \
		echo "━━━ Smoke-testing $$lvl ━━━"; \
		$(HARNESS) start "$$lvl" || exit 1; \
		if $(HARNESS) verify >/dev/null 2>&1; then \
			echo "✗ ERROR: $$lvl passed verify while in broken state!"; \
			exit 1; \
		fi; \
		echo "✓ $$lvl broken state verified (verify exited 1 as expected)"; \
		$(HARNESS) ai-assist >/dev/null || exit 1; \
		$(HARNESS) hint >/dev/null || exit 1; \
		$(HARNESS) solve || exit 1; \
		$(HARNESS) verify || exit 1; \
		$(HARNESS) reset || exit 1; \
		if $(HARNESS) verify >/dev/null 2>&1; then \
			echo "✗ ERROR: $$lvl passed verify after reset!"; \
			exit 1; \
		fi; \
		echo "✓ $$lvl reset state verified (verify exited 1 as expected)"; \
	done
	@if [[ "$(LEVEL)" == "all" ]]; then \
		echo "🎉 All levels (01–04) passed end-to-end smoke testing!"; \
	fi

# ─── Cluster & Scenario Lifecycle ─────────────────────────────────────────────

##@ Run the levels (attendees)

setup: ## Create Kind cluster 'escape-room' and install Cilium CNI
	$(HARNESS) setup

cleanup: ## Tear down Kind cluster and clean local state
	$(HARNESS) cleanup

prepare: ## Create cluster, pull every scenario image, build app images
	$(HARNESS) prepare

start: ## Start a level (e.g., make start LEVEL=level-01)
	$(HARNESS) start $(LEVEL)

status: ## Show active scenario and pod statuses
	$(HARNESS) status

hint: ## Display the next progressive hint (1 -> 2 -> 3)
	$(HARNESS) hint

ai-assist: ## Show the spoiler-free AI copilot tip for the active level
	$(HARNESS) ai-assist

verify: ## Run the active level's in-cluster verification probe
	$(HARNESS) verify

reset: ## Re-inject the active level's broken state
	$(HARNESS) reset

##@ Instructor

solve: ## Apply the reference solution for the active level (instructor only)
	$(HARNESS) solve
