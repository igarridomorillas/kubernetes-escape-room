#!/usr/bin/env bash
set -euo pipefail

readonly NAMESPACE="escape-level-01"
readonly APP_LABEL="app=payment-gateway"
readonly SERVICE_URL="http://payment-gateway.${NAMESPACE}.svc.cluster.local:80/"
readonly PROBE_POD="verify-probe-$$"
readonly PROBE_IMAGE="curlimages/curl:8.11.1"

echo "🔍 Verifying Level 01..."

# Step 1: Check the rollout is complete (new pods Ready, old pods gone)
if ! kubectl rollout status deployment/payment-gateway -n "${NAMESPACE}" --timeout=5s > /dev/null 2>&1; then
  echo "❌ Pod is not ready. Run: kubectl get pods -n ${NAMESPACE} -l ${APP_LABEL}"
  exit 1
fi

# Step 2: In-cluster HTTP probe.
# `kubectl run -i --rm` can lose the container exit code when the pod exits
# before kubectl attaches, so run the pod detached and read its phase instead.
# shellcheck disable=SC2329
cleanup() {
  kubectl delete pod "${PROBE_POD}" -n "${NAMESPACE}" --ignore-not-found=true --wait=false > /dev/null 2>&1 || true
}
trap cleanup EXIT

if ! kubectl run "${PROBE_POD}" \
  --image="${PROBE_IMAGE}" \
  --restart=Never \
  -n "${NAMESPACE}" \
  -- curl -fsS --max-time 5 -o /dev/null "${SERVICE_URL}" > /dev/null 2>&1; then
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
    echo "❌ Endpoint probe failed: service at ${SERVICE_URL} did not return HTTP 200"
    exit 1
    ;;
  *)
    echo "⚠️  Probe pod did not finish (image pull or scheduling issue). Retry in a moment."
    exit 1
    ;;
esac

echo "✅ Level 01 complete! You escaped!"
exit 0
