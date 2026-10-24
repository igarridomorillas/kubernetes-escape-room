# 📟 PAGER ALERT: #INC-8103

**Severity:** CRITICAL (P1)
**Service:** `frontend-service`
**Namespace:** `escape-level-03`
**Triggered:** Just now
**Status:** TRIGGERED (Unacknowledged)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### Incident Summary
The synthetic monitor for `GET /api/data` through the storefront reports
`504 Gateway Time-out` / `502 Bad Gateway` for all end-user requests. Every pod in the namespace shows
as healthy, yet customers cannot load their data.

### Telemetry & Impact
- **Pod Health:** all pods `Running`, `1/1` ready
- **Error Rate:** 100% of `/api/data` requests failing (`504` / `502`)
- **Customer Impact:** Account and order pages are blank for all users

### Triage Runbook
1. Confirm the workloads look healthy in namespace `escape-level-03`:
   ```bash
   kubectl get pods -n escape-level-03
   ```
2. Reproduce the failing request from inside the cluster, through the frontend:
   ```bash
   kubectl run curl-debug --rm -it --image=curlimages/curl:8.11.1 --restart=Never \
     -n escape-level-03 -- curl -sv http://frontend-service.escape-level-03.svc.cluster.local/api/data
   ```
3. Diagnose why the frontend cannot reach the backend, then apply the corrective change.
4. Verify resolution using `./scripts/escape-room.sh verify`.
