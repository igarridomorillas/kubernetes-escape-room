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
⏱ ~0:30 · Total session ~55 min: intro (you, Nexthink, route) ~3 min, talk ~10 min, room briefing ~1 min, hands-on 35-45 min across the three levels, AI debrief ~5 min, follow-up and keep training ~2 min, questions, hiring.
Before starting: confirm everyone ran `make prepare` (cluster up, images pulled) and can run `make status`. Fallbacks for slow networks or missing tools: docs/pre-workshop-checklist.md.
Open with the promise: AI is a copilot, not an autopilot. The cluster is the judge.
-->

---
layout: default
---

<div class="kicker">Who are we?</div>

# The speakers

<div class="body">

<div class="grid-2">
  <div class="card bio">
    <h4><carbon-user-avatar /> Carlos Vicent</h4>
    <span class="chip">SRE at Nexthink</span>
    <p class="small">Works on reliability for the platform behind <b>20M+ endpoints</b>, running <b>200+ microservices</b>.</p>
    <p class="small">Focuses on <b>incident response automation</b> and <b>observability</b> in cloud-native environments. Enjoys Kubernetes and often attends DevOps, SRE and observability conferences.</p>
    <p class="small"><span style="display:inline-block;transform:scaleX(-1)">🏃</span> Off duty, he's a <b>runner</b>. He's one of the few people who treats a 10K as a normal way to decompress, and who has never been paged mid-run (yet).</p>
  </div>
  <div class="card bio">
    <h4><carbon-user-avatar /> Unai Arrien</h4>
    <span class="chip">SRE at Nexthink</span>
    <p class="small">Works on the operation and improvement of <b>resilient distributed systems</b>.</p>
    <p class="small">Experience in <b>automation</b>, <b>observability</b> and <b>incident response</b>. Enjoys helping teams investigate, debug and solve complex real-world problems.</p>
    <p class="small">🍵 Fuelled by <b>matcha</b>, served plain: no milk, no sugar, no fuss. Reads ingredient labels as carefully as changelogs.</p>
  </div>
</div>

</div>

<!--
⏱ ~1:00 · Quick introductions, no CVs.
Carlos: reliability for 20M+ endpoints across 200+ microservices, incident response automation and observability, big Kubernetes fan.
Unai: resilient distributed systems, automation, observability and incident response; enjoys helping teams debug real problems.
Say who does what: one of us talks, both of us walk the room during the hands-on part. Invite questions at any time.
-->

---
layout: default
---

<div class="kicker">Who are we?</div>

# Nexthink in a nutshell

<div class="body">

<div class="grid-4">
  <div class="card"><h4><carbon-calendar /> 2004</h4><span class="small">Swiss SaaS product company, born at <b>EPFL</b>. Today +1,300 employees worldwide, with an engineering hub in <b>Madrid</b>.</span></div>
  <div class="card"><h4><carbon-user-multiple /> +2k customers</h4><span class="small">Trusted by some of the world's largest organizations.</span></div>
  <div class="card"><h4><carbon-devices /> +20M endpoints</h4><span class="small">Monitored worldwide by our platform.</span></div>
  <div class="card"><h4><carbon-code /> +400 engineers</h4><span class="small">Microservices, React, TypeScript, Kafka, Kubernetes, AWS, Clickhouse, Datadog and AI.</span></div>
</div>

<div class="grid-2">
  <div class="card good"><h4><carbon-flag /> Our mission: To delight people at work</h4><span class="small">We are a software company focused on helping IT to shape smart and productive workplaces.</span></div>
  <div class="card"><h4><carbon-chip /> How it works</h4><span class="small">Collectors are lightweight agents installed on devices that collect telemetry. This allows to detect, prevent and resolve issues before impacting users.</span></div>
</div>

</div>

<!--
⏱ ~1:30 · Keep it short: founded in 2004 at EPFL (Swiss SaaS), 1,300+ employees, engineering hub in Madrid.
Mission: improve the Digital Employee Experience (DEX). Collectors on endpoints detect and help resolve issues before they hit users.
Scale: 1,500+ customers, millions of endpoints, ~400 engineers (Java, microservices, React, TypeScript, Kubernetes, AWS, AI).
Bridge: this is why we care about incidents. As engineers we have seen AI change how software is designed, built, tested and operated, and tonight we practise it on broken clusters.
-->

---
src: ../shared/workshop.md
---

---
layout: end
---

# We're hiring!

<div class="grid-2 text-left pt-6" style="align-items: center">
  <div class="col">
    <div class="kicker"><carbon-user-follow /> Nexthink · Madrid</div>
    <div class="card good"><h4><carbon-cloud-services /> Join the SRE team @ Nexthink</h4><span class="small">Kubernetes, AWS and AI-assisted operations at scale, on a platform monitoring millions of endpoints.</span></div>
    <span class="small">Scan the QR to see the open position.</span>
  </div>
  <div class="flex justify-center">
    <img src="/sre-hiring-qr.png" alt="QR code to the open SRE position" style="width: 250px; background: #fff; padding: 12px; border-radius: 12px" />
  </div>
</div>

<!--
Closing plug: Nexthink is hiring for the SRE team in Madrid. Point to the QR for the open position and invite people to talk to us after the session.
Mention the stack they just practised on: Kubernetes, AWS and AI-assisted operations, on a platform monitoring millions of endpoints.
-->
