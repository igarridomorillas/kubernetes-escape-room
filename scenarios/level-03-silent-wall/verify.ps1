#Requires -Version 5.1
# Level 03 verification probe: PowerShell twin of verify.sh (keep both in sync).
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

$Namespace = 'escape-level-03'
$ServiceUrl = "http://frontend-service.${Namespace}.svc.cluster.local:80/api/data"
$ExpectedPayload = '"data":"backend-connected"'
$ProbePod = "verify-probe-$PID-$(Get-Random -Maximum 100000)"

$savedKubeconfig = $env:KUBECONFIG
$env:KUBECONFIG = $Kubeconfig
$probeCreated = $false
try {
  Write-Host '🔍 Verifying Level 03...'

  # Step 1: Check both rollouts are complete (new pods Ready, old pods gone)
  foreach ($deployment in @('frontend', 'backend')) {
    kubectl rollout status "deployment/$deployment" -n $Namespace --timeout=5s *> $null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "❌ Deployment '$deployment' is not ready. Run: kubectl get pods -n $Namespace"
      exit 1
    }
  }

  # Step 2: In-cluster end-to-end probe through the frontend.
  # `kubectl run -i --rm` can lose the container exit code when the pod exits
  # before kubectl attaches, so run the pod detached and read its phase instead.
  $probeCreated = $true
  kubectl run $ProbePod --image=curlimages/curl:8.11.1 --restart=Never -n $Namespace `
    -- curl -fsS --max-time 5 $ServiceUrl *> $null
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

  switch ($phase) {
    'Succeeded' { }
    'Failed' {
      Write-Host "❌ Endpoint probe failed: $ServiceUrl did not return HTTP 200"
      exit 1
    }
    default {
      Write-Host '⚠️  Probe pod did not finish (image pull or scheduling issue). Retry in a moment.'
      exit 1
    }
  }

  # Step 3: A 200 alone is not enough: the body must come from the backend.
  $body = @(kubectl logs $ProbePod -n $Namespace 2> $null) -join "`n"
  if (-not $body.Contains($ExpectedPayload)) {
    Write-Host "❌ $ServiceUrl returned HTTP 200 but not the expected backend payload"
    exit 1
  }

  Write-Host '✅ Level 03 complete! You escaped!'
  exit 0
} finally {
  if ($probeCreated) {
    kubectl delete pod $ProbePod -n $Namespace --ignore-not-found=true --wait=false *> $null
  }
  $env:KUBECONFIG = $savedKubeconfig
}
