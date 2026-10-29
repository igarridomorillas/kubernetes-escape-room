---
theme: default
title: "Kubernetes Escape Room: AI as Copilot, Not Autopilot"
info: |
  ## Kubernetes Escape Room
  Hands-on collaborative workshop for Platform, SRE, and Software Engineers.
colorSchema: dark
highlighter: shiki
lineNumbers: false
transition: fade
aspectRatio: 16/9
canvasWidth: 980
mdc: true
layout: cover
class: text-left
---

<div class="kicker"><carbon-flash /> Hands-on incident response workshop</div>

# Kubernetes Escape Room

AI as a copilot, not an autopilot.

<div class="pt-6 flex gap-3">
  <span class="chip"><carbon-user-multiple /> Platform · SRE · Software Engineers</span>
  <span class="chip violet"><carbon-flag /> 3 levels</span>
  <span class="chip green"><carbon-time /> ~55 min</span>
</div>

<!--
Welcome attendees! Confirm everyone has cloned the repo and run `make setup`.
Timing: talk (slides 2-12) ~10 min, hands-on (13-16) ~40 min, close (17), AI debrief (18) ~5 min, follow-up resources (19), questions (20).
-->

---
layout: default
---

# Today's route

<div class="body">

<div class="steps">
  <div class="step"><b>1 · Incidents</b><span>how we manage them</span></div>
  <div class="step"><b>2 · Then vs now</b><span>troubleshooting with AI</span></div>
  <div class="step"><b>3 · AI in practice</b><span>prompting, guardrails, CLI &amp; MCP</span></div>
  <div class="step on"><b>4 · Escape!</b><span>Levels 01 → 03</span></div>
</div>

<div class="grid-3">
  <div class="card"><h4><carbon-idea /> You will leave with</h4><span class="small">A repeatable way to use AI in an incident: evidence first, conclusions second.</span></div>
  <div class="card"><h4><carbon-tools /> You will see</h4><span class="small">Chat, MCP servers, CLI agents, and shared skills.</span></div>
  <div class="card"><h4><carbon-play-filled /> You will practice</h4><span class="small">Three broken scenarios. The AI will help, and sometimes mislead you.</span></div>
</div>

</div>

<!--
Roughly: 10 min of talk, 35-40 min hands-on across three levels, 5 min debrief.
-->

---
layout: default
---

<div class="kicker">Part 1 · Incident management</div>

# The incident lifecycle

<div class="body">

<div class="steps">
  <div class="step"><b>Detect</b><span>alert / report</span></div>
  <div class="step on"><b>Triage</b><span>severity and owner</span></div>
  <div class="step"><b>Mitigate</b><span>restore service</span></div>
  <div class="step"><b>Resolve</b><span>verified fix</span></div>
  <div class="step"><b>Learn</b><span>postmortem</span></div>
</div>

<div class="grid-3">
  <div class="card"><h4><carbon-user-multiple /> Roles</h4><span class="small">The <b>incident commander</b> decides, <b>operators</b> investigate, <b>comms</b> updates stakeholders. One person can hold several roles, but say who holds which.</span></div>
  <div class="card warn"><h4><carbon-time /> Mitigate first</h4><span class="small">Restore service before you fully understand it. Root cause can wait; customer impact cannot.</span></div>
  <div class="card good"><h4><carbon-search /> Where AI helps</h4><span class="small">Triage and diagnosis: turning noisy signals into a hypothesis you can check. Also where a wrong answer is most tempting.</span></div>
</div>

</div>

<!--
Keep it short. Triage is the focus of this talk. The point: diagnosis is evidence-gathering under time pressure, exactly where a fast-but-confident assistant is tempting and risky.
-->

---
layout: default
---

<div class="kicker">Part 2 · Then vs now</div>

# From manual to AI-assisted incident management

<div class="body">

<div class="grid-4">
  <div class="card"><span class="chip">Then</span><h4 class="pt-2">Pager & tribal knowledge</h4><span class="small">An alert pages the one person who knows the system. Runbooks sit in a wiki; the rest is in people's heads.</span></div>
  <div class="card"><span class="chip">Then</span><h4 class="pt-2">Dashboards & war rooms</h4><span class="small">Metrics, centralized logs, tracing. More signal, but you correlate it across tabs by hand.</span></div>
  <div class="card good"><span class="chip green">Now</span><h4 class="pt-2">AI copilots</h4><span class="small">Paste in the evidence and get a summary and ranked hypotheses back. Also drafts updates and postmortems.</span></div>
  <div class="card good"><span class="chip violet">Emerging</span><h4 class="pt-2">AI agents</h4><span class="small">Agents call your tools, run checks and pull signals together. Add self-healing and they can even fix known issues on their own. A human should approve every action.</span></div>
</div>

<div class="quote">Each step made evidence cheaper to collect. The hard part is now <b>making the right decision</b>.</div>

</div>

<!--
Do not dwell on history, and keep it tool-agnostic. Land the last line: the hard part is the decision. An LLM is very fast at producing interpretations, correct or not, and self-healing automates decisions, so it needs the strictest guardrails.
-->

---
layout: default
---

<div class="kicker">Part 2 · Then vs now</div>

# Triage and troubleshooting: then vs now

<div class="body">

| Triage step | 🕰️ Then | 🤖 Now |
| :--- | :--- | :--- |
| **Collect signals** | Open dashboards, grep logs, check recent changes by hand | Same sources, but the AI reads and summarizes the long output |
| **Interpret** | Search the error, read a thread, ask the person who knows | Ranked list of plausible causes, each tied to a quoted line |
| **Confirm the cause** | Change something and see if the symptom goes away | Ask the AI for one read-only check that would **prove its top hypothesis wrong**. Run it before you change anything |
| **Communicate** | Write the update from memory while still debugging | Draft impact, status and next step from verified facts |

<div class="grid-2">
  <div class="tip"><b>Where AI helps:</b> reading long output, listing causes you missed, explaining unfamiliar errors, drafting updates.</div>
  <div class="tip" style="border-color: var(--er-bad); background: rgba(248,113,113,0.07)"><b>Still your job:</b> choosing the evidence, noticing when the AI stopped at the first error, rejecting invented facts, owning the impact of every change.</div>
</div>

</div>

<!--
Both flows use the same evidence. What changed is speed, and the new failure mode: a fluent answer that is not grounded in your systems.
-->

---
layout: default
---

<div class="kicker">Part 3 · AI in practice</div>

# The 5-stage evidence-first loop

<div class="body">

<div class="sub">Run it on every incident. <b>Never jump straight to "give me the fix."</b></div>

| Stage | You do | You ask the AI to |
| :--- | :--- | :--- |
| **1. Summarize** | Collect raw logs, metrics, events and status output | Summarize what the output *shows*, quoting the exact lines |
| **2. Hypothesize** | Paste the **complete** evidence | List **every** plausible cause, ranked, each backed by a quoted line |
| **3. Next check** | Pick one hypothesis | Propose **one read-only** command that would confirm or *disprove* it |
| **4. Verify** | Run it yourself, paste back | Update the hypothesis from the result. Suggest **one** fix at a time, plus the check to re-run |
| **5.&nbsp;Communicate** | Confirm recovery with an independent check, then share **verified facts** only | Draft a 3-line update: impact, verified cause, fix applied |

</div>

<!--
Highlight stage 2 ("every plausible cause") and stage 3 ("what would DISPROVE it").
-->

---
layout: default
---

<div class="kicker">Part 3 · AI in practice</div>

# Prompt engineering: from vague to checkable

<div class="body">

<div class="sub"><code>Rules + Issue + Task</code>, and the agent gathers the evidence itself</div>

<div class="grid-2">
<div class="card bad">

#### <carbon-close-filled /> Vague

```text
My pod is failing. Fix it.
```

- No evidence, so the AI guesses between causes
- "Fix it" asks for an action, not understanding
- Nothing is quoted, so you cannot tell a finding from a confident guess

</div>
<div class="card good">

#### <carbon-checkmark-filled /> Structured

```text
RULES
- Only propose fixes, never apply them.
- Quote the exact line for every claim.
- Do NOT invent values from memory.
ISSUE
<the symptom, nothing more>
TASK
Understand it, then propose a minimal fix,
or the next read-only check.
```

</div>
</div>

<div class="tip">Constraints ("do not invent", "quote the line", "read-only") turn a chatty answer into a checkable one.</div>

</div>

<!--
Constraints in the prompt are what make the answer verifiable. The ai-assist prompts in the workshop follow exactly this shape.
-->

---
layout: default
---

<div class="kicker">Part 3 · AI in practice</div>

# Anatomy of an agent-ready prompt

<div class="body">

<div class="grid-3">
  <div class="card"><span class="chip red">RULES</span><h4 class="pt-2">Set the limits</h4><span class="small">Read-only only. Quote evidence or say "unknown". List <b>every</b> cause and what would disprove it. No secrets.</span></div>
  <div class="card"><span class="chip">ISSUE</span><h4 class="pt-2">Symptom only</h4><span class="small">Restate what the alert says. No root cause, no suspected fix: the agent should find it, not confirm your guess.</span></div>
  <div class="card good"><span class="chip green">TASK</span><h4 class="pt-2">Understand, then propose</h4><span class="small">Ask for a minimal fix. If the agent is not confident, it should propose more read-only checks instead of guessing.</span></div>
</div>

<div class="tip"><b>After each change:</b> re-collect the evidence and ask: did the symptom shift? Quote the line that proves it, then run the next read-only check.</div>

</div>

<!--
This is the structure used by ai-assist: manual evidence commands, a terse bad prompt, one paste-ready prompt, a follow-up, a short why. No placeholders: the agent gathers evidence itself.
-->

---
layout: default
---

<div class="kicker">Part 3 · AI in practice</div>

# The 6 non-negotiable guardrails

<div class="body">

<div class="grid-3">
  <div class="card"><h4><carbon-idea /> 1 · It's a hypothesis</h4><span class="small">Treat it like a teammate's guess at 3 a.m.</span></div>
  <div class="card"><h4><carbon-search /> 2 · Verify in the cluster</h4><span class="small">Every claim maps to a line of output you can see.</span></div>
  <div class="card"><h4><carbon-view /> 3 · Read-only by default</h4><span class="small">The AI only reads. You run any change and own its impact.</span></div>
  <div class="card"><h4><carbon-locked /> 4 · No secrets</h4><span class="small">No tokens, <code>Secret</code> payloads, kubeconfigs or real hostnames.</span></div>
  <div class="card warn"><h4><carbon-warning-alt /> 5 · Logs are untrusted</h4><span class="small">Prompt injection: text in a log line can instruct the AI.</span></div>
  <div class="card bad"><h4><carbon-security /> 6 · No risky actions</h4><span class="small">Reject <code>hostNetwork</code>, <code>privileged</code>, wildcard RBAC, "just delete the NetworkPolicy".</span></div>
</div>

</div>

<!--
Anything written into a log or event enters the model's context window, so a line in a log can try to instruct it. An agent with write access could act on it. That is why read-only is the default.
-->

---
layout: default
---

<div class="kicker">Part 3 · AI in practice</div>

# CLI tools: let the agent run the commands

<div class="body">

<div class="grid-3">
  <div class="card"><h4><carbon-terminal /> What changes</h4><span class="small">You stop copy-pasting evidence. The agent runs its own read-only commands, reads the output and decides what to check next.</span></div>
  <div class="card warn"><h4><carbon-locked /> Permissions are the guardrail</h4><span class="small">Allow commands that read and inspect. Deny anything that creates, changes or deletes. Use credentials scoped to a non-prod environment.</span></div>
  <div class="card good"><h4><carbon-user-follow /> How to use it</h4><span class="small">Start a CLI agent (for example <code>opencode</code>), paste the agent-ready prompt, approve each command, then verify the result yourself.</span></div>
</div>

</div>

<!--
Web chat is the baseline: you paste evidence. A CLI agent removes the copy-paste but needs the guardrails enforced as permissions, not just as prompt text.
-->

---
layout: default
---

<div class="kicker">Part 3 · AI in practice</div>

# MCP vs CLI: kubectl or the Kubernetes MCP server?

<div class="body">

| | `kubectl` via a CLI agent | Kubernetes MCP server |
| :--- | :--- | :--- |
| **Interface** | Free-form shell commands | Typed tools (`pods_list`, `pods_log`, `events_list`) |
| **Guardrails** | Command allowlist in the agent | `read_only`, `disable_destructive`, denied resources, toolsets |
| **Output** | Raw text, filtered with `grep` / `jq` | Structured results shaped for the model |
| **Flexibility** | Anything your shell can do | Only the tools the server exposes |

<div class="tip"><b>Either way:</b> scope the kubeconfig first (least privilege, deny <code>Secret</code>). The CLI allowlist or MCP read-only mode is a second fence, not the first.</div>

</div>

<!--
Rule of thumb: CLI for flexibility and zero setup, MCP when you want a narrow, typed, auditable surface. Full MCP config (read_only, disable_destructive, denied v1/Secret, keep v1/ConfigMap readable) is in docs/pre-workshop-checklist.md.
-->

---
layout: default
---

<div class="kicker">Part 3 · AI in practice</div>

# Share your setup: skills, MCP servers, context

<div class="body">

<div class="grid-3">
  <div class="card"><h4><carbon-document /> <code>AGENTS.md</code></h4><span class="small">Rules, commands and conventions for agents working in the repo. Most coding agents read it.</span></div>
  <div class="card"><h4><carbon-plug /> <code>.mcp.json</code></h4><span class="small">Which MCP servers the project uses and how to start them, next to the code.</span></div>
  <div class="card"><h4><carbon-store /> AI marketplaces</h4><span class="small">Plugins that bundle skills and MCP server configuration. Install one set and the whole team gets the same tools.</span></div>
</div>

<div class="grid-2">
  <div class="card good">
    <h4><carbon-checkmark-filled /> Do</h4>
    <ul class="small">
      <li>Pin versions; review changes like code</li>
      <li>Default to read-only credentials</li>
      <li>Keep runbooks and known pitfalls as skills</li>
    </ul>
  </div>
  <div class="card bad">
    <h4><carbon-close-filled /> Don't</h4>
    <ul class="small">
      <li>Install unreviewed plugins, skills or MCP servers (supply chain)</li>
      <li>Commit tokens or credentials</li>
    </ul>
  </div>
</div>

</div>

<!--
Discussion prompt: what would be the first shared skill or MCP server in your team? A runbook skill, a read-only cluster MCP, an observability or docs MCP? Agree where it lives (a repo, an internal marketplace) and who reviews changes.
-->

---
layout: default
---

<div class="kicker">Part 4 · Escape the room</div>

# How the room works

<div class="body">

<div class="card"><h4><carbon-security /> Ground rules &amp; help ladder</h4>
<ul class="small">
  <li>One namespace per level (<code>escape-level-01</code> … <code>03</code>)</li>
  <li>For your own <code>kubectl</code>: <code>export KUBECONFIG="$(pwd)/kind/.kube/config"</code> to target only the room</li>
  <li><code>verify</code> probes the service from inside the cluster</li>
  <li><b>Help ladder:</b> <code>hint</code> (concept, then commands, then a nudge to <code>ai-assist</code>), then <code>ai-assist</code> (free, spoiler-free prompt)</li>
</ul></div>

```bash
make start LEVEL=level-01  # break a level
make status                # where am I?
make hint                  # next hint (1 → 3)
make ai-assist             # agent-ready prompt
make verify                # did I escape?
make reset                 # re-break and retry
```

</div>

<!--
Emphasize ai-assist is free and gives no spoilers, and it does not use up a hint. Hint 3 points to it.
-->

---
layout: default
---

<div class="kicker">Level 01 · Warm-up</div>

# The Ghost Image

<div class="body">

<div class="grid-2">
<div class="col">
<div class="pager">
  <div class="pager-head"><carbon-notification /> <span class="id">PAGE #INC-8021</span> <span class="chip red">CRITICAL</span> <span class="chip"><carbon-time /> 8–10 min</span></div>
  <ul class="small">
    <li><b>Service:</b> <code>payment-gateway</code> in <code>escape-level-01</code></li>
    <li><b>Symptom:</b> <code>0/1</code> pods ready; checkout fails with <code>503</code></li>
    <li><b>Impact:</b> 100% of checkout requests failing; global payment processing halted</li>
    <li><b>Status:</b> <code>TRIGGERED</code> (unacknowledged), P1</li>
    <li><b>Goal:</b> <code>Running 1/1</code> and <code>verify</code> passes</li>
  </ul>
</div>
</div>

<div class="col">

```bash
make start LEVEL=level-01
```

<div class="tip"><b>Tip:</b> stuck? Run <code>make hint</code> for the next hint.</div>
</div>
</div>

</div>

<!--
Start the 8-10 minute timer.
-->

---
layout: default
---

<div class="kicker">Level 02 · Core</div>

# The Crashing Config

<div class="body">

<div class="grid-2">
<div class="col">
<div class="pager">
  <div class="pager-head"><carbon-notification /> <span class="id">PAGE #INC-8134</span> <span class="chip red">CRITICAL</span> <span class="chip"><carbon-time /> 12–15 min</span></div>
  <ul class="small">
    <li><b>Service:</b> <code>order-processor</code> in <code>escape-level-02</code></li>
    <li><b>Symptom:</b> restarting (<code>CrashLoopBackOff</code>, <code>OOMKilled</code>); queue growing</li>
    <li><b>Impact:</b> orders accepted but not processed; 0 processed in the last 10 min</li>
    <li><b>Status:</b> <code>TRIGGERED</code> (unacknowledged), P1</li>
    <li><b>Goal:</b> stable <code>Running 1/1</code>, <code>/healthz</code> healthy</li>
  </ul>
</div>
</div>

<div class="col">

```bash
make start LEVEL=level-02
```

<div class="tip"><b>Tip:</b> stuck? Run <code>make hint</code> for the next hint.</div>
</div>
</div>

</div>

<!--
Start the 12-15 minute timer. Remind attendees to collect ALL evidence sources.
-->

---
layout: default
---

<div class="kicker">Level 03 · Boss</div>

# The Silent Wall

<div class="body">

<div class="grid-2">
<div class="col">
<div class="pager">
  <div class="pager-head"><carbon-notification /> <span class="id">PAGE #INC-8103</span> <span class="chip red">CRITICAL</span> <span class="chip"><carbon-time /> 15–20 min</span></div>
  <ul class="small">
    <li><b>Service:</b> <code>frontend-service</code> in <code>escape-level-03</code></li>
    <li><b>Path:</b> <code>frontend-service</code> → <code>backend-service</code></li>
    <li><b>Symptom:</b> all pods <code>Running 1/1</code>, yet <code>/api/data</code> returns <code>504</code> / <code>502</code></li>
    <li><b>Impact:</b> 100% of <code>/api/data</code> requests failing; account and order pages blank</li>
    <li><b>Status:</b> <code>TRIGGERED</code> (unacknowledged), P1</li>
    <li><b>Goal:</b> <code>/api/data</code> returns <code>200</code></li>
  </ul>
</div>
</div>

<div class="col">

```bash
make start LEVEL=level-03
```

<div class="tip"><b>Tip:</b> stuck? Run <code>make hint</code> for the next hint.</div>
</div>
</div>

</div>

<!--
Start the 15-20 minute timer.
-->

---
layout: end
---

# You escaped the room!

<div class="grid-3 text-left pt-4">
  <div class="card"><h4><carbon-search /> Evidence first</h4><span class="small">Collect it, quote it, verify it.</span></div>
  <div class="card"><h4><carbon-idea /> Disprove, don't accept</h4><span class="small">Ask for the check that would prove the AI wrong.</span></div>
  <div class="card"><h4><carbon-user-multiple /> Humans in command</h4><span class="small">Least privilege, one change at a time.</span></div>
</div>

<div class="pt-6 small">
  <b>Take-home:</b> Level 04, <i>Ghost in the Microservices</i>: a 3-tier checkout failing inside a 5,000-line log haystack. Cheatsheet: <code>docs/ai-prompts-cheatsheet.md</code>
</div>

```bash
make start LEVEL=level-04                   # take-home
make cleanup                                # remove the cluster and local kubeconfig
```

<!--
Thank attendees. Mention Level 04 as a take-home, ask for feedback, and remind them to run cleanup when finished.
-->

---
layout: default
---

<div class="kicker">Debrief</div>

# How AI helped in the room

<div class="body">

<div class="grid-3">
  <div class="card"><span class="chip">Level 01</span><h4 class="pt-2">Reading the evidence</h4><span class="small">With the verbatim <i>Events</i> plus a "do not invent" rule, the AI named the real failure. Without them it gave a generic checklist or an invented tag.</span></div>
  <div class="card"><span class="chip">Level 02</span><h4 class="pt-2">Combining sources</h4><span class="small">Logs, <code>describe</code> and the config together exposed both causes. Logs alone stopped at the first error.</span></div>
  <div class="card"><span class="chip">Level 03</span><h4 class="pt-2">Cross-resource faults</h4><span class="small">The AI spotted the mismatches between resources. It needed a human to choose the verification order and reject unsafe shortcuts.</span></div>
</div>

<div class="grid-2">
  <div class="tip"><b>Where AI helped:</b> reading long output, listing causes, explaining unfamiliar errors.</div>
  <div class="tip" style="border-color: var(--er-bad); background: rgba(248,113,113,0.07)"><b>Where humans mattered:</b> choosing the evidence, checking claims, and owning every change.</div>
</div>

</div>

<!--
Replace these with what you actually saw in the room: who caught the mistakes, the human or the AI? The scoring rubric (correctness, time to evidence, completeness, safety) is in docs/ai-exercises.md if you want to run it.
-->

---
layout: default
---

<div class="kicker">Follow-up · Keep exploring</div>

# Follow-up resources

<div class="body">

<div class="grid-2">
  <div class="card"><h4><carbon-settings /> k8sgpt</h4><span class="small">Scans a cluster with built-in analyzers, then optionally asks an AI backend to explain what it found. A good first look, not a verdict.</span><div class="tiny pt-2"><code>github.com/k8sgpt-ai/k8sgpt</code></div></div>
  <div class="card"><h4><carbon-bot /> HolmesGPT</h4><span class="small">Open-source AI agent that investigates incidents by calling read-only tools and explaining the likely root cause.</span><div class="tiny pt-2"><code>github.com/HolmesGPT/holmesgpt</code></div></div>
</div>

<div class="tip">Same rules apply to both: least privilege, non-prod first, verify every claim.</div>

</div>

<!--
Not run on the build machine (see docs/ai-research-notes.md); check each project's docs before pointing attendees at them.
-->

---
layout: end
---

# Questions?

<div class="grid-3 text-left pt-6">
  <div class="card"><h4><carbon-idea /> Ask a human</h4><span class="small">We are in the same room. No prompt needed.</span></div>
  <div class="card"><h4><carbon-search /> Verify the answer</h4><span class="small">Even this one. Especially this one.</span></div>
  <div class="card good"><h4><carbon-face-satisfied /> Thank you</h4><span class="small">May your pods be Ready, and your pagers quiet.</span></div>
</div>

<!--
Open the floor. Remind people to run `make cleanup` and to leave feedback.
-->
