#Requires -Version 5.1
# Level 04 verification probe: PowerShell twin of verify.sh (keep both in sync).
# Exits 0 when the level is fixed, 1 otherwise. Native commands are checked
# through $LASTEXITCODE; 'Continue' keeps Windows PowerShell 5.1 from turning
# their redirected stderr into terminating errors.
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Continue'

# Pin kubectl to the escape-room cluster, never the user's current context
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Kubeconfig = [IO.Path]::Combine($RepoRoot, 'kind', '.kube', 'config')
if (-not (Test-Path -LiteralPath $Kubeconfig -PathType Leaf)) {
  Write-Host '❌ Kind kubeconfig not found. Run: .\scripts\make.ps1 setup'
  exit 1
}

$Namespace = 'escape-level-04'
$ServiceUrl = "http://gateway.${Namespace}.svc.cluster.local:80/checkout"
$ProbePod = "verify-probe-$PID-$(Get-Random -Maximum 100000)"

# Synthetic checkout probe sending 10 diverse transactions (credit_card,
# debit_card, apple_pay, paypal, wallet, bank_transfer and coupon). The script
# is the same as in verify.sh and runs in the probe container (sh), so its
# variables expand there. The pod is sent as a manifest on stdin rather than as
# `kubectl run` arguments: Windows PowerShell 5.1 strips the double quotes the
# script needs from native command arguments.
$ProbeManifest = @'
apiVersion: v1
kind: Pod
metadata:
  name: __PROBE_POD__
  namespace: __NAMESPACE__
  labels:
    run: __PROBE_POD__
spec:
  restartPolicy: Never
  containers:
    - name: __PROBE_POD__
      image: curlimages/curl:8.11.1
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 200m
          memory: 64Mi
      command:
        - sh
        - -c
        - |
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
        - "--"
        - "__SERVICE_URL__"
'@

$savedKubeconfig = $env:KUBECONFIG
$env:KUBECONFIG = $Kubeconfig
$probeCreated = $false
try {
  Write-Host '🔍 Verifying Level 04...'

  # Step 1: Check all three microservice rollouts are complete (new pods Ready, old pods gone)
  foreach ($deployment in @('gateway', 'cart', 'payment')) {
    kubectl rollout status "deployment/$deployment" -n $Namespace --timeout=5s *> $null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "❌ Deployment '$deployment' is not ready. Run: kubectl get pods -n $Namespace"
      exit 1
    }
  }

  # Step 2: Run the probe detached and poll .status.phase so the container exit
  # code is never lost. LF line endings keep the script valid for sh even when
  # this file was checked out with CRLF.
  $manifest = $ProbeManifest.Replace('__PROBE_POD__', $ProbePod).Replace('__NAMESPACE__', $Namespace).Replace('__SERVICE_URL__', $ServiceUrl) -replace "`r`n", "`n"
  $probeCreated = $true
  $manifest | kubectl create -f - *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host '⚠️  Could not create the probe pod. Retry in a moment.'
    exit 1
  }

  $phase = ''
  for ($i = 0; $i -lt 60; $i++) {
    $phase = "$(kubectl get pod $ProbePod -n $Namespace -o jsonpath='{.status.phase}' 2> $null)"
    if ($phase -eq 'Succeeded' -or $phase -eq 'Failed') { break }
    Start-Sleep -Seconds 1
  }

  $logs = @(kubectl logs $ProbePod -n $Namespace 2> $null)

  switch ($phase) {
    'Succeeded' { }
    'Failed' {
      $failLine = @($logs | Where-Object { $_ -like 'FAIL *' }) | Select-Object -First 1
      if ($failLine) {
        Write-Host "❌ Synthetic checkout probe failed on ${ServiceUrl}: $($failLine.Substring(5))"
      } else {
        Write-Host '❌ Endpoint probe failed: one or more synthetic checkout transactions did not return HTTP 200'
      }
      exit 1
    }
    default {
      Write-Host '⚠️  Probe pod did not finish (image pull or scheduling issue). Retry in a moment.'
      exit 1
    }
  }

  if (-not ($logs -join "`n").Contains('SUMMARY passed=10/10')) {
    Write-Host '❌ Synthetic checkout probe did not complete all 10 transactions.'
    exit 1
  }

  Write-Host '✅ Level 04 complete! You escaped!'
  exit 0
} finally {
  if ($probeCreated) {
    kubectl delete pod $ProbePod -n $Namespace --ignore-not-found=true --wait=false *> $null
  }
  $env:KUBECONFIG = $savedKubeconfig
}
