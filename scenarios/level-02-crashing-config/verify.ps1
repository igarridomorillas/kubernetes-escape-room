#Requires -Version 5.1
# Level 02 verification probe: PowerShell twin of verify.sh (keep both in sync).
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

$Namespace = 'escape-level-02'
$AppLabel = 'app=order-processor'
$ServiceUrl = "http://order-processor.${Namespace}.svc.cluster.local:8080/healthz"
$ExpectedBody = '{"status":"healthy","database":"connected"}'
$ProbePod = "verify-probe-$PID-$(Get-Random -Maximum 100000)"
$StableSeconds = 15

# Sum of restart counts over all pods of the app, so a stale pod from an old
# ReplicaSet cannot hide a crash. The jsonpath is space-separated instead of
# {"\n"}: Windows PowerShell 5.1 strips double quotes from native arguments.
function Get-RestartCount {
  $counts = "$(kubectl get pods -n $Namespace -l $AppLabel -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2> $null)"
  $sum = 0
  foreach ($count in ($counts -split '\s+')) {
    if ($count -match '^\d+$') { $sum += [int]$count }
  }
  return $sum
}

$savedKubeconfig = $env:KUBECONFIG
$env:KUBECONFIG = $Kubeconfig
$probeCreated = $false
try {
  Write-Host '🔍 Verifying Level 02...'

  # Step 1: Check the rollout is complete (new pods Ready, old pods gone)
  kubectl rollout status deployment/order-processor -n $Namespace --timeout=5s *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Pod is not ready. Run: kubectl get pods -n $Namespace -l $AppLabel"
    exit 1
  }

  # Step 2: The restart count must not move for $StableSeconds.
  $before = Get-RestartCount
  Write-Host "⏳ Checking the pod stays up for ${StableSeconds}s..."
  Start-Sleep -Seconds $StableSeconds
  $after = Get-RestartCount

  if ($before -ne $after) {
    Write-Host "❌ The pod is still restarting (restart count $before -> $after). Run: kubectl describe pod -n $Namespace -l $AppLabel"
    exit 1
  }

  kubectl rollout status deployment/order-processor -n $Namespace --timeout=5s *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Pod is not ready. Run: kubectl get pods -n $Namespace -l $AppLabel"
    exit 1
  }

  # Step 3: In-cluster HTTP probe that captures the response body.
  # `kubectl run -i --rm` can lose the container exit code when the pod exits
  # before kubectl attaches, so run the pod detached and read its phase and logs.
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

  $body = @(kubectl logs $ProbePod -n $Namespace 2> $null) -join "`n"
  if ($body -cne $ExpectedBody) {
    Write-Host '❌ /healthz answered, but not with a healthy database status. Check the application configuration.'
    exit 1
  }

  Write-Host '✅ Level 02 complete! You escaped!'
  exit 0
} finally {
  if ($probeCreated) {
    kubectl delete pod $ProbePod -n $Namespace --ignore-not-found=true --wait=false *> $null
  }
  $env:KUBECONFIG = $savedKubeconfig
}
