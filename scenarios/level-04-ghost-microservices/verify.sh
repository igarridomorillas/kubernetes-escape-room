#!/usr/bin/env bash
set -euo pipefail

# Pin kubectl to the escape-room cluster, never the user's current context
KUBECONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/kind/.kube/config"
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "❌ Kind kubeconfig not found. Run: ./scripts/escape-room.sh setup"
  exit 1
fi
export KUBECONFIG

readonly NAMESPACE="escape-level-04"
readonly SERVICE_URL="http://gateway.${NAMESPACE}.svc.cluster.local:80/checkout"
readonly PROBE_POD="verify-probe-$$"
readonly PROBE_IMAGE="curlimages/curl:8.11.1"

echo "🔍 Verifying Level 04..."

# Step 1: Check all three microservice rollouts are complete (new pods Ready, old pods gone)
for deployment in gateway cart payment; do
  if ! kubectl rollout status "deployment/${deployment}" -n "${NAMESPACE}" --timeout=5s > /dev/null 2>&1; then
    echo "❌ Deployment '${deployment}' is not ready. Run: kubectl get pods -n ${NAMESPACE}"
    exit 1
  fi
done

# Step 2: In-cluster synthetic checkout probe sending 10 diverse transactions
# (including credit_card, debit_card, apple_pay, paypal, wallet, bank_transfer, and coupon).
# Runs detached and polls .status.phase so the container exit code is never lost.
# shellcheck disable=SC2329
cleanup() {
  kubectl delete pod "${PROBE_POD}" -n "${NAMESPACE}" --ignore-not-found=true --wait=false > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Variables in PROBE_SCRIPT expand inside the in-cluster probe container
# shellcheck disable=SC2016
readonly PROBE_SCRIPT='
set -eu
URL="$1"
PASS_COUNT=0
for spec in \
  "tx-01:credit_card:4999" \
  "tx-02:debit_card:1850" \
  "tx-03:coupon:2500" \
  "tx-04:apple_pay:3200" \
  "tx-05:paypal:8900" \
  "tx-06:coupon:1200" \
  "tx-07:wallet:950" \
  "tx-08:bank_transfer:15000" \
  "tx-09:credit_card:6400" \
  "tx-10:coupon:4000"
do
  TX_ID="${spec%%:*}"
  REST="${spec#*:}"
  METHOD="${REST%%:*}"
  AMOUNT="${REST#*:}"
  PAYLOAD="{\"tx_id\":\"${TX_ID}\",\"payment_method\":\"${METHOD}\",\"amount\":${AMOUNT}}"
  CODE="$(curl -sS --max-time 5 -o /tmp/resp.json -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "${PAYLOAD}" "${URL}" || echo "000")"
  BODY="$(cat /tmp/resp.json 2>/dev/null || true)"
  case "${BODY}" in
    *"\"status\":\"completed\""*"\"payment\":\"approved\""*)
      if [ "${CODE}" = "200" ]; then
        echo "PASS ${TX_ID} (${METHOD}) -> HTTP ${CODE}"
        PASS_COUNT=$((PASS_COUNT + 1))
      else
        echo "FAIL ${TX_ID} (${METHOD}) -> HTTP ${CODE}"
        exit 1
      fi
      ;;
    *)
      echo "FAIL ${TX_ID} (${METHOD}) -> HTTP ${CODE}"
      exit 1
      ;;
  esac
done
echo "SUMMARY passed=${PASS_COUNT}/10"
'

if ! kubectl run "${PROBE_POD}" \
  --image="${PROBE_IMAGE}" \
  --restart=Never \
  -n "${NAMESPACE}" \
  --command -- sh -c "${PROBE_SCRIPT}" -- "${SERVICE_URL}" > /dev/null 2>&1; then
  echo "⚠️  Could not create the probe pod. Retry in a moment."
  exit 1
fi

PHASE=""
for _ in $(seq 1 60); do
  PHASE=$(kubectl get pod "${PROBE_POD}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "${PHASE}" == "Succeeded" || "${PHASE}" == "Failed" ]] && break
  sleep 1
done

LOGS="$(kubectl logs "${PROBE_POD}" -n "${NAMESPACE}" 2>/dev/null || true)"

case "${PHASE}" in
  Succeeded) ;;
  Failed)
    FAIL_LINE="$(printf '%s\n' "${LOGS}" | grep '^FAIL ' | head -n 1 || true)"
    if [[ -n "${FAIL_LINE}" ]]; then
      echo "❌ Synthetic checkout probe failed on ${SERVICE_URL}: ${FAIL_LINE#FAIL }"
    else
      echo "❌ Endpoint probe failed: one or more synthetic checkout transactions did not return HTTP 200"
    fi
    exit 1
    ;;
  *)
    echo "⚠️  Probe pod did not finish (image pull or scheduling issue). Retry in a moment."
    exit 1
    ;;
esac

if [[ "${LOGS}" != *"SUMMARY passed=10/10"* ]]; then
  echo "❌ Synthetic checkout probe did not complete all 10 transactions."
  exit 1
fi

echo "✅ Level 04 complete! You escaped!"
exit 0
