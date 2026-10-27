#!/usr/bin/env bash
set -euo pipefail

# Pin kubectl to the escape-room cluster, never the user's current context
KUBECONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/kind/.kube/config"
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "❌ Kind kubeconfig not found. Run: make setup"
  exit 1
fi
export KUBECONFIG

readonly NAMESPACE="escape-level-03"
readonly SERVICE_URL="http://frontend-service.${NAMESPACE}.svc.cluster.local:80/api/data"
readonly EXPECTED_PAYLOAD='"data":"backend-connected"'
readonly PROBE_POD="verify-probe-$$"
readonly PROBE_IMAGE="curlimages/curl:8.11.1"

echo "🔍 Verifying Level 03..."

# Step 1: Check both rollouts are complete (new pods Ready, old pods gone)
for deployment in frontend backend; do
  if ! kubectl rollout status "deployment/${deployment}" -n "${NAMESPACE}" --timeout=5s > /dev/null 2>&1; then
    echo "❌ Deployment '${deployment}' is not ready. Run: kubectl get pods -n ${NAMESPACE}"
    exit 1
  fi
done

# Step 2: In-cluster end-to-end probe through the frontend.
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

# Step 3: A 200 alone is not enough: the body must come from the backend.
BODY="$(kubectl logs "${PROBE_POD}" -n "${NAMESPACE}" 2>/dev/null || true)"
if [[ "${BODY}" != *"${EXPECTED_PAYLOAD}"* ]]; then
  echo "❌ ${SERVICE_URL} returned HTTP 200 but not the expected backend payload"
  exit 1
fi

echo "✅ Level 03 complete! You escaped!"
exit 0
