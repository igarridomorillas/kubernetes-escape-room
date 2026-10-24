# AI Research Notes — LLM-Assisted Kubernetes Troubleshooting

> Sources behind [`ai-prompts-cheatsheet.md`](ai-prompts-cheatsheet.md) and [`ai-exercises.md`](ai-exercises.md).
> Every link below was fetched on **2026-10-23** / **2026-10-24** (access dates). Where a page shows no publication date it is marked "n/d".
> Claims are paraphrased from the fetched page, not from memory. Re-check version-sensitive items (MCP server config, opencode keys) before the event.

---

## Established practices

These are stable, documented by primary sources, and the workshop teaches them as the baseline.

| # | Practice | Source | Date | What it supports |
|---|---|---|---|---|
| E1 | Troubleshoot from evidence: `describe` first (state + events), then logs (`--previous` for restarted containers), then compare the stored manifest with what you applied | [Kubernetes: Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) | n/d | The evidence an AI needs for Level 01 and 02 is the same evidence a human collects. Hint 2 of each level follows this order. |
| E2 | Debug a Service in order: Service exists → NetworkPolicy ingress → DNS → ClusterIP → selector and `targetPort` → EndpointSlices → Pod IPs | [Kubernetes: Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) | n/d | Level 03: the checklist an AI must be given the *inputs* for (Service, endpoints, NetworkPolicy, pod labels). |
| E3 | NetworkPolicy is additive and allow-only; a pod is isolated for a direction only once a policy selects it; policies have no effect without a plugin that implements them | [Kubernetes: Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) | n/d | Level 03 and why `kind/cni/cilium.yaml` exists. Also why "delete the policy" is an unsafe AI suggestion. |
| E4 | Prompt injection is LLM01 in the OWASP list; *indirect* injection comes from external content (files, web pages). Mitigations: least privilege, human approval for high-risk actions, separate and label untrusted content, filter input/output | [OWASP GenAI: LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) | 2025 (copyright line; no publication date shown) | Guardrail: logs, events and ConfigMap values are untrusted input to the model. |
| E5 | MCP hosts must get explicit user consent before invoking any tool; tools represent arbitrary code execution; tool annotations are untrusted unless from a trusted server; the protocol itself cannot enforce this | [MCP specification 2025-11-25, Security and Trust & Safety](https://modelcontextprotocol.io/specification/2025-11-25/index) | spec version 2025-11-25 (other versions listed on the site; the quoted section is present in the version fetched) | Guardrail: review every tool call; read-only by default. |
| E6 | Final-answer accuracy overstates diagnosis quality: best agents reached 0.76 / 0.68 joint RCA accuracy but only 0.38 / 0.15 evidence closure (conclusions backed by evidence) | [Cloud-OpsBench, arXiv 2603.00468](https://arxiv.org/abs/2603.00468) | submitted 2026-02-28 (v1); v2 2026-08-22 | Why the rubric scores *evidence*, not only "got the right answer". Benchmark numbers are on microservice demo systems, not on this workshop. |
| E7 | Commonest agent failures across five models: hallucinated data interpretation and incomplete exploration; prompt engineering alone did not remove them | [Why Do AI Agents Systematically Fail at Cloud Root Cause Analysis?, arXiv 2602.09937](https://arxiv.org/abs/2602.09937) | submitted 2026-02-10; v2 2026-03-04 | Level 02 (incomplete exploration: finds one of two causes) and the "ask for all causes" tip. Also the reason humans verify. |

## Emerging practices

Useful, widely discussed, but tool- and version-dependent. Presented as optional.

| # | Practice | Source | Date | Notes |
|---|---|---|---|---|
| M1 | Kubernetes MCP server, read-only | [containers/kubernetes-mcp-server](https://github.com/containers/kubernetes-mcp-server) and its [configuration doc](https://github.com/containers/kubernetes-mcp-server/blob/main/docs/configuration.md) (Apache-2.0) | n/d (main branch) | Per `docs/configuration.md`, `read_only`, `disable_destructive`, `kubeconfig` and `[[denied_resources]]` are **TOML config keys; the CLI only takes `--config`, `--config-dir`, `--version`**. `[[denied_resources]]` is an array of GVK tables (`group`, `version`, `kind` — not a string array like `["v1/Secret"]`). Do **not** deny `v1/ConfigMap` for this workshop (Level 02 requires inspecting `ConfigMap/order-config`). The `core` and `config` toolsets expose `pods_list`, `pods_get`, `pods_log`, `events_list`, `resources_get` and `resources_list`, covering all resources in Levels 01–03. Read-only mode limits the *server's* actions, not the underlying kubeconfig credentials. |
| M2 | CLI agent permission modes (opencode) | [opencode: Permissions](https://opencode.ai/docs/permissions/) | n/d | Values `allow` / `ask` / `deny`; most permissions default to `allow`; last matching pattern wins (catch-all `*` first, `deny` rules last); `--auto` approves requests that would ask, while explicit `deny` still blocks. Current V2 docs support `shell` under `permission` (object map) or an ordered `permissions` array of `{ "action": "shell", "resource": "...", "effect": "..." }` rules; legacy V1 used `bash`. |
| M3 | CLI agent confirmation prompts (kubectl-ai) | [GoogleCloudPlatform/kubectl-ai](https://github.com/GoogleCloudPlatform/kubectl-ai) (Apache-2.0, "not an officially supported Google product") | n/d | Confirmation for resource-modifying commands is on by default (`skipPermissions` default `false`). No read-only mode is documented. Its HTTP MCP endpoint is unauthenticated by default, so do not expose it. |
| M4 | Analyzer + LLM explanation (k8sgpt) | [k8sgpt-ai/k8sgpt](https://github.com/k8sgpt-ai/k8sgpt) and [k8sgpt.ai docs](https://k8sgpt.ai/docs/getting-started/overview) | n/d (main branch) | Built-in Go analyzers (`Pod`, `Deployment`, `Service`, `Log`, plus optional `NetworkPolicy` enabled with `--filter=NetworkPolicy`) run locally via `k8sgpt analyze` without calling an LLM. Adding `--explain` sends the structured error payload to the configured AI backend for plain-language diagnosis. Adding `--anonymize` masks sensitive fields (resource names, namespaces, labels) with keyed tokens before transmission and de-anonymizes the response locally, though free-form strings inside raw `Event` messages or custom logs can still bypass field-level masking. |
| M5 | Retrieval over runbooks & incident handlers | [RCACopilot, arXiv 2305.15778](https://arxiv.org/abs/2305.15778); [OpsEval, arXiv 2310.07637](https://arxiv.org/abs/2310.07637); [AutoBnB-RAG, arXiv 2508.13118](https://arxiv.org/abs/2508.13118); [IT Support RAG, arXiv 2409.13707](https://arxiv.org/abs/2409.13707) | 2023-05-25 (v4 2023-11-13); 2023-10-11; 2025-08-18; 2024-09-20 | RCACopilot pairs alert-specific diagnostic handlers (runbook workflows collecting logs, metrics and traces) with LLM root-cause prediction and narrative synthesis. AutoBnB-RAG and IT Support RAG show that grounding LLMs in curated technical runbooks improves incident decision quality and resolution accuracy over ungrounded prompting. However, retrieved runbooks do not guarantee command safety and can propagate outdated procedures if runbooks are stale. |

## Verification status & remaining caveats

- **Empirical LLM prompt dry-run (verified across 2 models):** The Bad, Good, and Challenge prompts in [`docs/ai-exercises.md`](ai-exercises.md) were tested against two distinct model tiers (`Gemini Flash-Lite` and `Gemini Pro`) using the exact broken-cluster telemetry from Levels 01–03. Observed outputs, model drift, and failure modes (e.g., `Flash-Lite` missing `OOMKilled` on the Level 02 Bad prompt, proposing `targetPort` before `NetworkPolicy` verification on Level 03, and conflating the Service ClusterIP `10.11.142.156` with the Pod Endpoint IP `10.10.0.167`) are documented in the Model Evaluation Matrix in [`docs/ai-exercises.md`](ai-exercises.md).
- **MCP and CLI agent configurations:** Configuration schemas for `containers/kubernetes-mcp-server` (`mcp-config.toml`) and `opencode` (`opencode.json`) were verified against upstream primary documentation (`docs/configuration.md` and `opencode.ai/docs/permissions/`). Live binary execution of `opencode`, `kubectl-ai`, and `k8sgpt` was not run on the build machine (`opencode`, `kubectl-ai`, and `k8sgpt` binaries are not installed locally; see [`docs/sessions/05-milestone-05.md`](sessions/05-milestone-05.md)).

## Conflicts between sources

| Topic | Source A | Source B | Decision |
|---|---|---|---|
| How to enable read-only & resource blocks in `kubernetes-mcp-server` | Secondary search summaries (mirrors, older READMEs): `--read-only` CLI flag or `denied_resources = ["v1/Secret"]` string list | Current repo README and `docs/configuration.md`: TOML key `read_only = true` and `[[denied_resources]]` GVK array-of-tables (`group`, `version`, `kind`); CLI limited to bootstrap flags (`--config`, `--config-dir`, `--version`) | Cheatsheet provides the full verified TOML snippet (`read_only = true`, `disable_destructive = true`, `kubeconfig = "kind/.kube/config"`, `[[denied_resources]]` for `v1/Secret`) and warns not to block `v1/ConfigMap` (needed for Level 02). |
| opencode shell permission key | Legacy V1 docs/mirrors: `permission.bash` | Current V2 docs: `permission.shell` (or ordered `permissions` array with `"action": "shell"`) | Cheatsheet shows `permission.shell` with last-match-wins ordering and notes the V1 `bash` / V2 `permissions` array variants. |

## How to re-verify before the event

```bash
# every URL above should return 200 (OWASP may return 403 to curl due to Cloudflare; verify in browser)
for u in $(grep -oE 'https://[a-zA-Z0-9][^) >]+' docs/ai-research-notes.md | sort -u); do
  printf '%s %s\n' "$(curl -s -o /dev/null -L -w '%{http_code}' "$u")" "$u"
done
```
