# 📟 PAGER ALERT: #INC-8134

**Severity:** CRITICAL (P1)
**Service:** `order-processor`
**Namespace:** `escape-level-02`
**Triggered:** Just now
**Status:** TRIGGERED (Unacknowledged)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### Incident Summary
`CRITICAL: order-processor service in escape-level-02 is constantly restarting (CrashLoopBackOff). Order queue backlog rising.`
New customer orders are being accepted but are not being processed.

### Telemetry & Impact
- **Pod Health:** 0/1 pods ready, restart count climbing
- **Order Queue Depth:** growing, 0 orders processed in the last 10 minutes
- **Customer Impact:** Orders stuck in "Processing" state

### Triage Runbook
1. Inspect the workload in namespace `escape-level-02`:
   ```bash
   kubectl get pods -n escape-level-02
   ```
2. Work out why the pod keeps restarting. There may be more than one cause.
3. Apply the corrective configuration change(s) so the service stays up.
4. Verify resolution using `./scripts/escape-room.sh verify`.
