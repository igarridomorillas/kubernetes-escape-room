#!/usr/bin/env bash
set -euo pipefail

# Pin kubectl to the escape-room cluster, never the user's current context
KUBECONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/kind/.kube/config"
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "❌ Kind kubeconfig not found. Run: make setup"
  exit 1
fi
export KUBECONFIG

readonly NAMESPACE="escape-level-02"
readonly APP_LABEL="app=order-processor"
readonly SERVICE_URL="http://order-processor.${NAMESPACE}.svc.cluster.local:8080/healthz"
readonly EXPECTED_BODY='{"status":"healthy","database":"connected"}'
readonly PROBE_POD="verify-probe-$$"
readonly PROBE_IMAGE="curlimages/curl:8.11.1"
readonly STABLE_SECONDS=15

echo "🔍 Verifying Level 02..."

# Step 1: Check the rollout is complete (new pods Ready, old pods gone)
if ! kubectl rollout status deployment/order-processor -n "${NAMESPACE}" --timeout=5s > /dev/null 2>&1; then
  echo "❌ Pod is not ready. Run: kubectl get pods -n ${NAMESPACE} -l ${APP_LABEL}"
  exit 1
fi

# Step 2: The restart count must not move for STABLE_SECONDS.
# Sum over all pods of the app so a stale pod from an old ReplicaSet cannot hide a crash.
restart_count() {
  kubectl get pods -n "${NAMESPACE}" -l "${APP_LABEL}" \
    -o jsonpath='{range .items[*].status.containerStatuses[*]}{.restartCount}{"\n"}{end}' 2>/dev/null |
    awk '{ sum += $1 } END { print sum + 0 }'
}

BEFORE="$(restart_count)"
echo "⏳ Checking the pod stays up for ${STABLE_SECONDS}s..."
sleep "${STABLE_SECONDS}"
AFTER="$(restart_count)"

if [[ "${BEFORE}" != "${AFTER}" ]]; then
  echo "❌ The pod is still restarting (restart count ${BEFORE} -> ${AFTER}). Run: kubectl describe pod -n ${NAMESPACE} -l ${APP_LABEL}"
  exit 1
fi

if ! kubectl rollout status deployment/order-processor -n "${NAMESPACE}" --timeout=5s > /dev/null 2>&1; then
  echo "❌ Pod is not ready. Run: kubectl get pods -n ${NAMESPACE} -l ${APP_LABEL}"
  exit 1
fi

# Step 3: In-cluster HTTP probe that captures the response body.
# `kubectl run -i --rm` can lose the container exit code when the pod exits
# before kubectl attaches, so run the pod detached and read its phase and logs.
# shellcheck disable=SC2329
cleanup() {
  kubectl delete pod "${PROBE_POD}" -n "${NAMESPACE}" --ignore-not-found=true --wait=false > /dev/null 2>&1 || true
}
trap cleanup EXIT

if ! kubectl run "${PROBE_POD}" \
  --image="${PROBE_IMAGE}" \
  --restart=Never \
  -n "${NAMESPACE}" \
  -- curl -fsS --max-time 5 "${SERVICE_URL}" > /dev/null 2>&1; then
  echo "⚠️  Could not create the probe pod. Retry in a moment."
  exit 1
fi

PHASE=""
for _ in $(seq 1 60); do
  PHASE=$(kubectl get pod "${PROBE_POD}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "${PHASE}" == "Succeeded" || "${PHASE}" == "Failed" ]] && break
  sleep 1
done

case "${PHASE}" in
  Succeeded) ;;
  Failed)
    echo "❌ Endpoint probe failed: ${SERVICE_URL} did not return HTTP 200"
    exit 1
    ;;
  *)
    echo "⚠️  Probe pod did not finish (image pull or scheduling issue). Retry in a moment."
    exit 1
    ;;
esac

BODY="$(kubectl logs "${PROBE_POD}" -n "${NAMESPACE}" 2>/dev/null || true)"
if [[ "${BODY}" != "${EXPECTED_BODY}" ]]; then
  echo "❌ /healthz answered, but not with a healthy database status. Check the application configuration."
  exit 1
fi

echo "✅ Level 02 complete! You escaped!"
exit 0
