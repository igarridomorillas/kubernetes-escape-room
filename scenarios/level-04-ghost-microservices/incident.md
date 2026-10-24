# 📟 PAGER ALERT: #INC-8192

**Severity:** HIGH (P2)
**Service:** `gateway` (`gateway` → `cart` → `payment`)
**Namespace:** `escape-level-04`
**Triggered:** Just now
**Status:** TRIGGERED (Unacknowledged)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### Incident Summary
`HIGH: Intermittent 500 Internal Server Errors in checkout flow under specific payment types.`
The 3-tier checkout pipeline (`gateway` → `cart` → `payment`) is passing all readiness probes and processing standard card transactions, but a subset of customer checkouts on `POST /checkout` is failing with `HTTP 500`.

### Telemetry & Impact
- **Pod Health:** `gateway`, `cart`, and `payment` all `Running`, `1/1` ready (`/healthz` passing)
- **Error Pattern:** Intermittent `HTTP 500` responses on `POST /checkout` through `gateway`
- **Log Volume:** High (`~5,000` log lines on the downstream payment tier)
- **Customer Impact:** Customers using specific payment methods cannot complete checkout

### Triage Runbook
1. Inspect the running workloads in namespace `escape-level-04`:
   ```bash
   kubectl get pods -n escape-level-04
   ```
2. Trace the failing checkout requests across the `gateway` → `cart` → `payment` tiers and locate the underlying error in the logs.
3. Apply the corrective configuration change so all checkout payment methods succeed.
4. Verify resolution using `./scripts/escape-room.sh verify`.
