#Requires -Version 5.1
<#
.SYNOPSIS
  Kubernetes Escape Room CLI harness for PowerShell.

.DESCRIPTION
  PowerShell port of scripts/escape-room.sh for Windows. Runs on Windows
  PowerShell 5.1 and PowerShell 7+. Both harnesses share .room-state,
  kind/.kube/config and scenarios/, and must behave the same (see AGENTS.md).
  Attendees normally call it through scripts/make.ps1.

.EXAMPLE
  .\scripts\escape-room.ps1 start level-01
#>
param(
  [Parameter(Position = 0)][string]$Command = '',
  [Parameter(Position = 1)][string]$Level = ''
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# ─── Colour Palette ───────────────────────────────────────────────────────────
$Esc = [char]27
$Red = "${Esc}[0;31m"
$Green = "${Esc}[0;32m"
$Yellow = "${Esc}[1;33m"
$Cyan = "${Esc}[0;36m"
$Bold = "${Esc}[1m"
$NC = "${Esc}[0m"  # No Colour

# ─── Constants ────────────────────────────────────────────────────────────────
$RepoRoot = Split-Path -Parent $PSScriptRoot
$StateFile = Join-Path $RepoRoot '.room-state'
$KindConfig = [IO.Path]::Combine($RepoRoot, 'kind', 'cluster-config.yaml')
$CiliumManifest = [IO.Path]::Combine($RepoRoot, 'kind', 'cni', 'cilium.yaml')
$KindKubeconfig = [IO.Path]::Combine($RepoRoot, 'kind', '.kube', 'config')
$ScenariosDir = Join-Path $RepoRoot 'scenarios'
$ClusterName = 'escape-room'
$ValidLevels = @('level-01', 'level-02', 'level-03', 'level-04')
$OnWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
# What attendees type instead of `make` in every message, hint and next step
$MakeCmd = if ($OnWindows) { '.\scripts\make.ps1' } else { './scripts/make.ps1' }
$Rule = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
$Utf8 = New-Object System.Text.UTF8Encoding $false

# ─── Native command helpers ───────────────────────────────────────────────────
# Windows PowerShell 5.1 turns the redirected stderr of a native command into an
# error record, which 'Stop' makes fatal. These helpers relax the preference
# locally and report failure through the exit code, like the Bash harness. A
# missing program counts as exit code 127, as in Bash.

# Runs a native command. Exits 1 on failure (like `set -e`) unless -AllowFailure.
# -Quiet discards stdout (like `> /dev/null`); stderr stays visible.
function Invoke-Native {
  param(
    [Parameter(Mandatory = $true, Position = 0)][scriptblock]$ScriptBlock,
    [switch]$Quiet,
    [switch]$AllowFailure
  )
  $ErrorActionPreference = 'Continue'
  $global:LASTEXITCODE = 1
  try {
    if ($Quiet) { & $ScriptBlock | Out-Null } else { & $ScriptBlock | Out-Host }
  } catch [Management.Automation.CommandNotFoundException] {
    Write-Host "${Red}✗ $($_.Exception.Message)${NC}"
    $global:LASTEXITCODE = 127
  }
  if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) { exit 1 }
}

# Runs a native command with all output discarded; returns $true on exit code 0.
function Test-Native {
  param([Parameter(Mandatory = $true, Position = 0)][scriptblock]$ScriptBlock)
  $ErrorActionPreference = 'Continue'
  $global:LASTEXITCODE = 1
  try {
    & $ScriptBlock *> $null
  } catch [Management.Automation.CommandNotFoundException] {
    $global:LASTEXITCODE = 127
  }
  return ($LASTEXITCODE -eq 0)
}

# Runs a native command and returns its stdout lines (stderr is discarded, or
# merged in with -MergeStderr). Check $LASTEXITCODE afterwards.
function Get-NativeOutput {
  param(
    [Parameter(Mandatory = $true, Position = 0)][scriptblock]$ScriptBlock,
    [switch]$MergeStderr
  )
  $ErrorActionPreference = 'Continue'
  $global:LASTEXITCODE = 1
  try {
    if ($MergeStderr) {
      & $ScriptBlock 2>&1 | ForEach-Object { "$_" }
    } else {
      & $ScriptBlock 2> $null
    }
  } catch [Management.Automation.CommandNotFoundException] {
    $global:LASTEXITCODE = 127
  }
}

# Sets the console encoding; returns the previous one ($null without a console).
function Set-ConsoleEncoding {
  param([Parameter(Mandatory = $true)][Text.Encoding]$Encoding)
  try {
    $previous = [Console]::OutputEncoding
    [Console]::OutputEncoding = $Encoding
    return $previous
  } catch {
    Write-Verbose "Console encoding left unchanged: $($_.Exception.Message)"
    return $null
  }
}

# ─── State helpers ────────────────────────────────────────────────────────────

# Lines of .room-state (nothing when the file does not exist yet)
function Get-StateLine {
  if (Test-Path -LiteralPath $StateFile -PathType Leaf) {
    [IO.File]::ReadAllLines($StateFile)
  }
}

# Writes .room-state with LF line endings, so the Bash harness can read it too
function Save-StateLine {
  param([Parameter(Mandatory = $true)][string[]]$Lines)
  [IO.File]::WriteAllText($StateFile, (($Lines -join "`n") + "`n"))
}

function Initialize-State {
  if (-not (Test-Path -LiteralPath $StateFile -PathType Leaf)) {
    Save-StateLine -Lines @('CURRENT_LEVEL=', 'HINT_LEVEL=0', 'COMPLETED_LEVELS=')
  }
}

function Read-State {
  param([Parameter(Mandatory = $true)][string]$Key)
  # Plain key=value parsing, same file format as the Bash harness
  foreach ($line in @(Get-StateLine)) {
    if ($line.StartsWith("$Key=")) { return $line.Substring($Key.Length + 1) }
  }
  return ''
}

function Write-State {
  param([Parameter(Mandatory = $true)][string]$Key, [AllowEmptyString()][string]$Value)
  $lines = @(Get-StateLine)
  $found = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].StartsWith("$Key=")) {
      $lines[$i] = "$Key=$Value"
      $found = $true
    }
  }
  if (-not $found) { $lines += "$Key=$Value" }
  Save-StateLine -Lines $lines
}

# ─── Banner helpers ───────────────────────────────────────────────────────────

function Show-Header {
  Write-Host ''
  Write-Host "${Red}${Bold}"
  Write-Host @'
  ██╗  ██╗ █████╗ ███████╗    ███████╗███████╗ ██████╗ █████╗ ██████╗ ███████╗
  ██║ ██╔╝██╔══██╗██╔════╝    ██╔════╝██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝
  █████╔╝ ╚█████╔╝███████╗    █████╗  ███████╗██║     ███████║██████╔╝█████╗
  ██╔═██╗ ██╔══██╗╚════██║    ██╔══╝  ╚════██║██║     ██╔══██║██╔═══╝ ██╔══╝
  ██║  ██╗╚█████╔╝███████║    ███████╗███████║╚██████╗██║  ██║██║     ███████╗
  ╚═╝  ╚═╝ ╚════╝ ╚══════╝    ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚══════╝
                    ██████╗  ██████╗  ██████╗ ███╗   ███╗
                    ██╔══██╗██╔═══██╗██╔═══██╗████╗ ████║
                    ██████╔╝██║   ██║██║   ██║██╔████╔██║
                    ██╔══██╗██║   ██║██║   ██║██║╚██╔╝██║
                    ██║  ██║╚██████╔╝╚██████╔╝██║ ╚═╝ ██║
                    ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝
'@
  Write-Host $NC
  Write-Host "  ${Bold}Kubernetes Escape Room — CLI Harness${NC}"
  Write-Host '  Can you debug your way out with AI as your copilot?'
  Write-Host ''
}

function Show-Banner {
  param([Parameter(Mandatory = $true)][string]$Colour, [Parameter(Mandatory = $true)][string]$Text)
  Write-Host ''
  Write-Host "${Colour}${Bold}${Rule}${NC}"
  Write-Host "${Colour}${Bold}  ${Text}${NC}"
  Write-Host "${Colour}${Bold}${Rule}${NC}"
  Write-Host ''
}

function Show-SuccessBanner {
  Write-Host ''
  Write-Host "${Green}${Bold}"
  Write-Host @'
  ███████╗███████╗ ██████╗ █████╗ ██████╗ ███████╗██████╗ ██╗
  ██╔════╝██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗██║
  █████╗  ███████╗██║     ███████║██████╔╝█████╗  ██║  ██║██║
  ██╔══╝  ╚════██║██║     ██╔══██║██╔═══╝ ██╔══╝  ██║  ██║╚═╝
  ███████╗███████║╚██████╗██║  ██║██║     ███████╗██████╔╝██╗
  ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═════╝ ╚═╝
'@
  Write-Host $NC
  Write-Host "${Green}${Bold}  🎉  You escaped the room!  🎉${NC}"
  Write-Host ''
}

function Remove-CompletedLevel {
  param([Parameter(Mandatory = $true)][string]$LevelName)
  $kept = @((Read-State 'COMPLETED_LEVELS') -split ',' | Where-Object { $_ -and $_ -cne $LevelName })
  Write-State 'COMPLETED_LEVELS' ($kept -join ',')
}

# First scenario directory matching scenarios/<level>-* ('' if there is none)
function Get-ScenarioDir {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$LevelName)
  if (-not $LevelName) { return '' }
  $match = @(Get-ChildItem -LiteralPath $ScenariosDir -Directory -Filter "$LevelName-*" -ErrorAction SilentlyContinue |
      Sort-Object -Property Name)
  if ($match.Count -gt 0) { return $match[0].FullName }
  return ''
}

# Returns the next available level after $Current ('' if none has a scenario yet)
function Get-NextLevel {
  param([Parameter(Mandatory = $true)][string]$Current)
  $found = $false
  foreach ($candidate in $ValidLevels) {
    if ($found -and (Get-ScenarioDir $candidate)) { return $candidate }
    if ($candidate -eq $Current) { $found = $true }
  }
  return ''
}

function Show-NextStep {
  param([Parameter(Mandatory = $true)][string]$LevelName)
  $next = Get-NextLevel $LevelName
  Write-Host "${Bold}What's next?${NC}"
  if ($next) {
    Write-Host "  Continue:   ${Bold}$MakeCmd start LEVEL=${next}${NC}"
  } else {
    Write-Host "  ${Green}No further levels are available yet.${NC}"
  }
  Write-Host "  Retry:      ${Bold}$MakeCmd reset${NC}"
  Write-Host "  Tear down:  ${Bold}$MakeCmd cleanup${NC}"
  Write-Host ''
}

# ─── Prerequisite checks ──────────────────────────────────────────────────────

function Get-InstallHint {
  param([Parameter(Mandatory = $true)][string]$Tool)
  if ($OnWindows) {
    switch ($Tool) {
      'docker' { return "https://docs.docker.com/desktop/setup/install/windows-install/  (Windows: 'winget install Docker.DockerDesktop')" }
      'kind' { return "https://kind.sigs.k8s.io/docs/user/quick-start/#installation  (Windows: 'winget install Kubernetes.kind')" }
    }
  } else {
    switch ($Tool) {
      'docker' { return "https://docs.docker.com/get-docker/  (macOS: 'brew install --cask docker')" }
      'kind' { return "https://kind.sigs.k8s.io/docs/user/quick-start/#installation  (macOS: 'brew install kind')" }
    }
  }
  return ''
}

function Assert-Prerequisite {
  $missing = $false
  foreach ($tool in @('docker', 'kind', 'kubectl')) {
    if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
      Write-Host "${Red}✗ Missing required tool: ${tool}${NC}"
      $hint = Get-InstallHint $tool
      if ($hint) {
        Write-Host "  ${Yellow}💡 Install it: ${hint}${NC}"
      }
      $missing = $true
    }
  }
  if ($missing) {
    Write-Host "${Red}Install missing tools and retry.${NC}"
    exit 1
  }
}

function Test-ClusterExist {
  $clusters = @(Get-NativeOutput { kind get clusters })
  return ($clusters -ccontains $ClusterName)
}

function Assert-Cluster {
  if (-not (Test-ClusterExist)) {
    Write-Host "${Red}✗ Kind cluster '$ClusterName' does not exist.${NC}"
    Write-Host "  Run ${Bold}$MakeCmd setup${NC} first."
    exit 1
  }
  $hasContext = (Test-Path -LiteralPath $KindKubeconfig -PathType Leaf) -and
    [bool](Select-String -LiteralPath $KindKubeconfig -SimpleMatch -Pattern "kind-$ClusterName" -Quiet)
  if (-not $hasContext) {
    Write-Host "${Red}✗ Kubeconfig kind/.kube/config is missing.${NC}"
    Write-Host "  Run ${Bold}$MakeCmd setup${NC} to regenerate it."
    exit 1
  }
  $env:KUBECONFIG = $KindKubeconfig
}

function Assert-State {
  if (-not (Read-State 'CURRENT_LEVEL')) {
    Write-Host "${Red}✗ No active level.${NC}"
    Write-Host "  Run ${Bold}$MakeCmd start LEVEL=<level>${NC} first."
    exit 1
  }
}

function Assert-Level {
  param([Parameter(Mandatory = $true)][string]$LevelName)
  if ($ValidLevels -ccontains $LevelName) { return }
  Write-Host "${Red}✗ Unknown level: '$LevelName'.${NC}"
  Write-Host "  Valid levels: $($ValidLevels -join ' ')"
  exit 1
}

# ─── Command: setup ───────────────────────────────────────────────────────────

# Exits 1 when the cluster was created with kindnet (no NetworkPolicy support).
# Cilium cannot be layered on top of kindnet, so the user must recreate it.
function Assert-NotKindnet {
  if (Test-Native { kubectl get daemonset kindnet -n kube-system }) {
    Write-Host "${Red}✗ Cluster '$ClusterName' was created with kindnet, which does not enforce NetworkPolicy.${NC}"
    Write-Host "  Run ${Bold}$MakeCmd cleanup${NC} followed by ${Bold}$MakeCmd setup${NC}."
    exit 1
  }
}

# Restricts a path to the current user, like chmod 700 (directory) / 600 (file).
# On Windows the inherited ACL is replaced by one full-control entry for the user.
function Protect-Path {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Mode)
  if ($OnWindows) {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $grant = if (Test-Path -LiteralPath $Path -PathType Container) { "${user}:(OI)(CI)F" } else { "${user}:F" }
    Invoke-Native -Quiet -AllowFailure { icacls $Path /inheritance:r /grant:r $grant }
  } else {
    & chmod $Mode $Path
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Host "${Yellow}⚠ Could not restrict access to ${Path}.${NC}"
  }
}

# Writes a repo-local kubeconfig holding only the kind cluster, so every harness
# kubectl call is pinned to it whatever the user's current context is. kind also
# keeps updating the default kubeconfig as usual.
function Export-Kubeconfig {
  $kubeDir = Split-Path -Parent $KindKubeconfig
  New-Item -ItemType Directory -Force -Path $kubeDir | Out-Null
  Protect-Path -Path $kubeDir -Mode '700'
  Invoke-Native -Quiet -AllowFailure { kind export kubeconfig --name $ClusterName --kubeconfig $KindKubeconfig }
  if ($LASTEXITCODE -ne 0) {
    Write-Host "${Red}✗ Could not write kind/.kube/config.${NC}"
    exit 1
  }
  Protect-Path -Path $KindKubeconfig -Mode '600'
  $env:KUBECONFIG = $KindKubeconfig
}

# Installs the pinned Cilium CNI (kind/cni/cilium.yaml) with Hubble, then waits
# for every component and all nodes to be Ready. Re-applying is idempotent.
function Install-Cilium {
  Write-Host "${Cyan}→ Installing Cilium CNI (pinned 1.20.2)...${NC}"
  Invoke-Native -Quiet { kubectl apply --server-side --force-conflicts -f $CiliumManifest }
  foreach ($resource in @('daemonset/cilium', 'deployment/cilium-operator', 'deployment/hubble-relay', 'deployment/hubble-ui')) {
    Invoke-Native -Quiet { kubectl rollout status $resource -n kube-system --timeout=300s }
  }
  Write-Host "${Cyan}→ Waiting for all nodes to be Ready...${NC}"
  Invoke-Native -Quiet { kubectl wait --for=condition=Ready nodes --all --timeout=300s }
  Write-Host "${Green}✓ Cilium is ready and all nodes are Ready.${NC}"
}

function Invoke-Setup {
  Show-Banner $Cyan '🚀  Setting up Escape Room Cluster'

  Assert-Prerequisite

  Write-Host "${Cyan}→ Checking Docker...${NC}"
  if (-not (Test-Native { docker info })) {
    Write-Host "${Red}✗ Docker is not running. Please start Docker and retry.${NC}"
    Write-Host "  ${Yellow}💡 Start Docker Desktop. Not installed? $(Get-InstallHint 'docker')${NC}"
    exit 1
  }
  Write-Host "${Green}✓ Docker is running.${NC}"

  if (Test-ClusterExist) {
    Write-Host "${Yellow}⚠ Cluster '$ClusterName' already exists — skipping creation.${NC}"
  } else {
    Write-Host "${Cyan}→ Creating Kind cluster '$ClusterName'...${NC}"
    Invoke-Native { kind create cluster --name $ClusterName --config $KindConfig }
    Write-Host "${Green}✓ Cluster created.${NC}"
  }

  Write-Host "${Cyan}→ Writing repo kubeconfig (kind/.kube/config)...${NC}"
  Export-Kubeconfig
  Write-Host "${Green}✓ Kubeconfig written.${NC}"

  Write-Host "${Cyan}→ Verifying kubectl connectivity...${NC}"
  Invoke-Native -Quiet { kubectl cluster-info }
  Write-Host "${Green}✓ kubectl is connected to the cluster.${NC}"

  Assert-NotKindnet
  Install-Cilium

  Initialize-State

  Show-Banner $Green '✅  Setup complete — cluster is ready'
  Write-Host "  Run ${Bold}$MakeCmd start LEVEL=level-01${NC} to begin."
  Write-Host ''
}

# Builds scenarios/<level>-*/app/ (if present) and loads (publishes) it into the
# kind cluster, so no external registry is needed. Image: escape-room/<level>-app:1.0.0
function Publish-AppImage {
  param([Parameter(Mandatory = $true)][string]$LevelName, [Parameter(Mandatory = $true)][string]$Dir)
  $appDir = Join-Path $Dir 'app'
  if (-not (Test-Path -LiteralPath (Join-Path $appDir 'Dockerfile') -PathType Leaf)) { return }

  $image = "escape-room/${LevelName}-app:1.0.0"
  Write-Host "${Cyan}→ Building application image '$image'...${NC}"
  Invoke-Native -Quiet { docker build -q -t $image $appDir }
  Invoke-Native -Quiet { kind load docker-image $image --name $ClusterName }
  Write-Host "${Green}✓ Image loaded into the cluster.${NC}"
}

# ─── Command: prepare ─────────────────────────────────────────────────────────

# Returns every external image used by the scenarios: `image:` / `--image=`
# references in scenarios/ (manifests, verify scripts, docs) plus the FROM lines
# of scenario Dockerfiles. Cilium images are not listed: `setup` already pulls
# them. Locally built images (escape-room/*) are skipped.
function Get-ScenarioImage {
  $pattern = '(?:image[:=]|--image=)\s*"?([A-Za-z0-9][^\s"''$`]*)'
  $images = New-Object System.Collections.Generic.List[string]
  $files = Get-ChildItem -LiteralPath $ScenariosDir -Recurse -File -Force |
    Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }
  foreach ($file in $files) {
    foreach ($line in [IO.File]::ReadAllLines($file.FullName)) {
      foreach ($match in [regex]::Matches($line, $pattern)) { $images.Add($match.Groups[1].Value) }
      if ($file.Name -ceq 'Dockerfile' -and $line -cmatch '^FROM\s+(\S+)') { $images.Add($Matches[1]) }
    }
  }
  $images | Where-Object { $_ -notmatch '^escape-room/' -and $_ -notmatch '1.27.99-alpine' } |
    Sort-Object -Unique -CaseSensitive
}

# Pulls every discovered image on the host so the download is done before the
# workshop. An image whose tag does not exist is skipped silently (not even listed):
# level-01 intentionally references one and naming it would give the fix away. Any other
# pull failure (network, auth, rate limit) is reported by name.
function Invoke-ImagePull {
  $failed = New-Object System.Collections.Generic.List[string]
  foreach ($image in @(Get-ScenarioImage)) {
    $output = (@(Get-NativeOutput -MergeStderr { docker pull -q $image }) -join "`n")
    if ($LASTEXITCODE -eq 0) {
      Write-Host "${Green}✓ ${image}${NC}"
    } elseif ($output -notmatch 'not found|manifest unknown') {
      $failed.Add($image)
    }
  }

  if ($failed.Count -gt 0) {
    Write-Host "${Yellow}⚠ Could not pull (check your network and retry):${NC}"
    foreach ($image in $failed) { Write-Host "  - $image" }
  }
}

function Invoke-Prepare {
  Show-Banner $Cyan '🧰  Preparing workshop environment'

  Invoke-Setup

  Write-Host "${Cyan}→ Pulling all scenario images...${NC}"
  Invoke-ImagePull

  foreach ($levelName in $ValidLevels) {
    $dir = Get-ScenarioDir $levelName
    if ($dir) { Publish-AppImage $levelName $dir }
  }

  Show-Banner $Green '✅  Prepare complete — images cached, cluster ready'
  Write-Host ''
}

# Blocks until each deployment rolls out (Ready pods), or exits 1 after 120s
function Wait-Deployment {
  param([Parameter(Mandatory = $true)][string]$Namespace, [Parameter(Mandatory = $true)][string[]]$Deployment)
  Write-Host "${Cyan}→ Waiting for $($Deployment -join ' ') to be ready...${NC}"
  foreach ($name in $Deployment) {
    if (-not (Test-Native { kubectl rollout status "deployment/$name" -n $Namespace --timeout=120s })) {
      Write-Host "${Red}✗ Deployment '$name' is not ready after 120s.${NC}"
      Write-Host "  Check: kubectl get pods -n $Namespace"
      exit 1
    }
    Write-Host "${Green}✓ $name is ready.${NC}"
  }
}

# Waits for the Deployments of levels whose broken state still rolls out Ready.
# Level 01 must stay broken (ImagePullBackOff), so it is intentionally skipped.
function Wait-LevelRollout {
  param([Parameter(Mandatory = $true)][string]$LevelName, [Parameter(Mandatory = $true)][string]$Namespace)
  switch ($LevelName) {
    'level-03' { Wait-Deployment -Namespace $Namespace -Deployment @('backend', 'frontend') }
    'level-04' { Wait-Deployment -Namespace $Namespace -Deployment @('payment', 'cart', 'gateway') }
  }
}

# Deletes the namespaces of every level except $Keep so old workloads cannot interfere
function Remove-OtherLevel {
  param([Parameter(Mandatory = $true)][string]$Keep)
  foreach ($other in $ValidLevels) {
    if ($other -eq $Keep) { continue }
    if (Test-Native { kubectl get namespace "escape-$other" }) {
      Write-Host "${Cyan}→ Removing previous level namespace 'escape-$other'...${NC}"
      Invoke-Native { kubectl delete namespace "escape-$other" --ignore-not-found=true --wait=true }
    }
  }
}

# ─── Command: start <level> ───────────────────────────────────────────────────

function Invoke-Start {
  param([AllowEmptyString()][string]$LevelName)
  if (-not $LevelName) {
    Write-Host "${Red}✗ Usage: $MakeCmd start LEVEL=<level>${NC}"
    Write-Host "  Valid levels: $($ValidLevels -join ' ')"
    exit 1
  }

  Assert-Level $LevelName
  Assert-Cluster

  $dir = Get-ScenarioDir $LevelName
  if (-not $dir) {
    Write-Host "${Red}✗ Scenario directory for '$LevelName' not found under ${ScenariosDir}${NC}"
    exit 1
  }

  $brokenDir = Join-Path $dir 'broken'
  if (-not (Test-Path -LiteralPath $brokenDir -PathType Container)) {
    Write-Host "${Red}✗ No 'broken/' directory found in ${dir}${NC}"
    exit 1
  }

  $namespace = "escape-$LevelName"

  Show-Banner $Yellow "🔥  Starting $LevelName"

  Publish-AppImage $LevelName $dir

  Remove-OtherLevel $LevelName

  Write-Host "${Cyan}→ Resetting namespace '$namespace'...${NC}"
  Invoke-Native { kubectl delete namespace $namespace --ignore-not-found=true --wait=true }
  Invoke-Native { kubectl create namespace $namespace }
  Write-Host "${Green}✓ Namespace ready.${NC}"

  Write-Host "${Cyan}→ Applying broken manifests...${NC}"
  Invoke-Native { kubectl apply -f $brokenDir -n $namespace }
  Write-Host "${Green}✓ Broken state injected.${NC}"

  Wait-LevelRollout $LevelName $namespace

  # Update state
  Initialize-State
  Write-State 'CURRENT_LEVEL' $LevelName
  Write-State 'HINT_LEVEL' '0'
  Remove-CompletedLevel $LevelName

  # Show incident alert
  $incidentFile = Join-Path $dir 'incident.md'
  if (Test-Path -LiteralPath $incidentFile -PathType Leaf) {
    Write-Host ''
    Write-Host "${Red}${Bold}${Rule}${NC}"
    Write-Host "${Red}${Bold}  🚨  INCIDENT ALERT — READ CAREFULLY${NC}"
    Write-Host "${Red}${Bold}${Rule}${NC}"
    Write-Host ''
    Write-Markdown ([IO.File]::ReadAllText($incidentFile))
    Write-Host ''
  }

  Write-Host "${Bold}Useful commands:${NC}"
  Write-Host "  ${Cyan}$MakeCmd status${NC}   — see pod states"
  Write-Host "  ${Cyan}$MakeCmd hint${NC}     — get your first hint"
  Write-Host "  ${Cyan}$MakeCmd ai-assist${NC} — paste-ready prompt for an AI agent on this level"
  Write-Host "  ${Cyan}$MakeCmd verify${NC}   — check if you've fixed it"
  Write-Host ''
}

# ─── Command: status ─────────────────────────────────────────────────────────

function Invoke-Status {
  Assert-Cluster
  Assert-State

  $levelName = Read-State 'CURRENT_LEVEL'
  $hintLevel = Read-State 'HINT_LEVEL'
  $completed = Read-State 'COMPLETED_LEVELS'
  $namespace = "escape-$levelName"

  Show-Banner $Cyan "📊  Status — $levelName"

  Write-Host "${Bold}Active level:${NC}     ${Cyan}${levelName}${NC}"
  Write-Host "${Bold}Namespace:${NC}        $namespace"
  Write-Host "${Bold}Hints used:${NC}       $hintLevel/3"
  if ($completed) {
    Write-Host "${Bold}Completed:${NC}        ${Green}${completed}${NC}"
  }
  Write-Host ''

  Write-Host "${Bold}Pod status:${NC}"
  $pods = @(Get-NativeOutput { kubectl get pods -n $namespace })
  if ($LASTEXITCODE -eq 0) { $pods | ForEach-Object { Write-Host $_ } } else { Write-Host '  (no pods yet)' }
  Write-Host ''

  Write-Host "${Bold}Service status:${NC}"
  $services = @(Get-NativeOutput { kubectl get svc -n $namespace })
  if ($LASTEXITCODE -eq 0) { $services | ForEach-Object { Write-Host $_ } } else { Write-Host '  (no services yet)' }
  Write-Host ''

  Write-Host "${Bold}Troubleshooting commands:${NC}"
  Write-Host "  kubectl get pods -n $namespace"
  Write-Host "  kubectl describe pod -n $namespace -l app=<name>"
  Write-Host "  kubectl logs -n $namespace -l app=<name> --previous"
  Write-Host "  kubectl get events -n $namespace --sort-by='.lastTimestamp'"
  Write-Host ''
}

# ─── Markdown rendering (optional: glow) ──────────────────────────────────────

# Minimal glow style with no margin, indent or trailing padding, so text selected
# in the terminal pastes back exactly as written (same style as escape-room.sh).
$GlowStyle = @'
{
  "document": { "margin": 0 },
  "heading": { "bold": true, "color": "39", "block_suffix": "\n" },
  "strong": { "bold": true },
  "code": { "color": "81" },
  "block_quote": { "color": "244", "indent": 0 },
  "code_block": { "color": "114", "margin": 0 },
  "item": { "block_prefix": "• " },
  "enumeration": { "block_prefix": ". " }
}
'@

# hints.md, incident.md and ai-assist.md are shared with the Bash harness and
# say `make <target>`; show the PowerShell command instead.
function Convert-MakeCommand {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
  $targets = 'setup|prepare|start|status|hint|ai-assist|verify|solve|reset|cleanup'
  return [regex]::Replace($Text, "\bmake ($targets)\b", "$MakeCmd `$1")
}

# Prints Markdown through glow on a terminal; plain passthrough when glow is not
# installed (optional), output is redirected, NO_COLOR is set, or glow fails.
function Write-Markdown {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Markdown)
  $Markdown = Convert-MakeCommand $Markdown
  $glow = Get-Command glow -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($glow -and -not $env:NO_COLOR -and -not [Console]::IsOutputRedirected) {
    $ErrorActionPreference = 'Continue'
    $style = [IO.Path]::GetTempFileName()
    try {
      [IO.File]::WriteAllText($style, $GlowStyle)
      $global:LASTEXITCODE = 1
      $Markdown | & $glow.Source -s $style -w 0 -
      if ($LASTEXITCODE -eq 0) { return }
    } finally {
      Remove-Item -LiteralPath $style -Force -ErrorAction SilentlyContinue
    }
  }
  Write-Host ($Markdown -replace '\r?\n\z', '')
}

# ─── Command: hint ────────────────────────────────────────────────────────────

# Returns the Nth hint block of hints.md: the lines under the "## Hint N"
# heading, up to the next "## " heading.
function Get-Hint {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][int]$Number)
  $found = $false
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($line in [IO.File]::ReadAllLines($Path)) {
    if ($line.StartsWith('## ')) {
      if ($found) { break }
      if ($line.Contains("Hint $Number")) { $found = $true }
      continue
    }
    if ($found) { $lines.Add($line) }
  }
  # Newline-terminated lines, like awk
  if ($lines.Count -eq 0) { return '' }
  return (($lines -join "`n") + "`n")
}

function Invoke-Hint {
  Assert-State

  $levelName = Read-State 'CURRENT_LEVEL'
  $hintLevel = 0
  [void][int]::TryParse((Read-State 'HINT_LEVEL'), [ref]$hintLevel)

  $dir = Get-ScenarioDir $levelName
  if (-not $dir) {
    Write-Host "${Red}✗ Scenario directory not found for '$levelName'.${NC}"
    exit 1
  }

  $hintsFile = Join-Path $dir 'hints.md'
  if (-not (Test-Path -LiteralPath $hintsFile -PathType Leaf)) {
    Write-Host "${Red}✗ No hints file found for '$levelName'.${NC}"
    exit 1
  }

  if ($hintLevel -ge 3) {
    Write-Host "${Yellow}⚠  You've already used all 3 hints.${NC}"
    Write-Host "  Use ${Bold}$MakeCmd solve${NC} if you're truly stuck (instructor only)."
    Write-Host ''
    Write-Host "${Yellow}${Bold}💡  Hint 3 of 3 — $levelName (again)${NC}"
    Write-Host ''
    Write-Markdown (Get-Hint -Path $hintsFile -Number 3)
    Write-Host ''
    return
  }

  $nextHint = $hintLevel + 1
  Write-State 'HINT_LEVEL' "$nextHint"

  Write-Host ''
  Write-Host "${Yellow}${Bold}💡  Hint $nextHint of 3 — $levelName${NC}"
  Write-Host ''
  Write-Markdown (Get-Hint -Path $hintsFile -Number $nextHint)
  Write-Host ''
}

# ─── Command: ai-assist ───────────────────────────────────────────────────────

# Prints the level's AI tip. Independent of the hint counter (HINT_LEVEL).
function Invoke-AiAssist {
  Assert-State

  $levelName = Read-State 'CURRENT_LEVEL'

  $dir = Get-ScenarioDir $levelName
  if (-not $dir) {
    Write-Host "${Red}✗ Scenario directory not found for '$levelName'.${NC}"
    exit 1
  }

  $tipFile = Join-Path $dir 'ai-assist.md'
  if (-not (Test-Path -LiteralPath $tipFile -PathType Leaf)) {
    Write-Host "${Red}✗ No AI tip file found for '$levelName'.${NC}"
    exit 1
  }

  Write-Host ''
  Write-Host "${Cyan}${Bold}🤖  AI assist — $levelName${NC}"
  Write-Host ''
  Write-Markdown ([IO.File]::ReadAllText($tipFile))
  Write-Host ''
}

# ─── Command: verify ─────────────────────────────────────────────────────────

function Invoke-Verify {
  Assert-Cluster
  Assert-State

  $levelName = Read-State 'CURRENT_LEVEL'

  $dir = Get-ScenarioDir $levelName
  if (-not $dir) {
    Write-Host "${Red}✗ Scenario directory not found for '$levelName'.${NC}"
    exit 1
  }

  $verifyScript = Join-Path $dir 'verify.ps1'
  if (-not (Test-Path -LiteralPath $verifyScript -PathType Leaf)) {
    Write-Host "${Red}✗ No verify.ps1 found for '$levelName'.${NC}"
    exit 1
  }

  Show-Banner $Cyan "🔍  Verifying $levelName"

  # verify.ps1 runs in this session and reports through its exit code (0 or 1)
  $global:LASTEXITCODE = 1
  try {
    & $verifyScript
  } catch {
    Write-Host "${Red}✗ verify.ps1 failed: $($_.Exception.Message)${NC}"
    $global:LASTEXITCODE = 1
  }

  if ($LASTEXITCODE -eq 0) {
    # Mark level as completed
    $completed = Read-State 'COMPLETED_LEVELS'
    if (-not ",$completed,".Contains(",$levelName,")) {
      if (-not $completed) {
        Write-State 'COMPLETED_LEVELS' $levelName
      } else {
        Write-State 'COMPLETED_LEVELS' "$completed,$levelName"
      }
    }
    Show-SuccessBanner
    Show-NextStep $levelName
  } else {
    Write-Host ''
    Write-Host "${Yellow}⚠  Not fixed yet. Run ${Bold}$MakeCmd hint${NC}${Yellow} for your next clue.${NC}"
    exit 1
  }
}

# ─── Command: solve ───────────────────────────────────────────────────────────

function Invoke-Solve {
  Assert-Cluster
  Assert-State

  $levelName = Read-State 'CURRENT_LEVEL'

  $dir = Get-ScenarioDir $levelName
  if (-not $dir) {
    Write-Host "${Red}✗ Scenario directory not found for '$levelName'.${NC}"
    exit 1
  }

  $solutionDir = Join-Path $dir 'solution'
  if (-not (Test-Path -LiteralPath $solutionDir -PathType Container)) {
    Write-Host "${Red}✗ No solution/ directory found for '$levelName'.${NC}"
    exit 1
  }

  $namespace = "escape-$levelName"

  Show-Banner $Yellow "🔓  Applying Reference Solution — $levelName"
  Write-Host "${Yellow}${Bold}⚠  Instructor/Emergency use only!${NC}"
  Write-Host ''

  Invoke-Native { kubectl apply -f $solutionDir -n $namespace }

  Write-Host ''
  Write-Host "${Green}✓ Solution applied. Waiting for pods to stabilise...${NC}"
  if (-not (Test-Native { kubectl rollout status deployment -n $namespace --timeout=120s })) {
    Write-Host "${Yellow}⚠  Deployments are not ready after 120s. Check: kubectl get pods -n ${namespace}${NC}"
  }
  Write-Host ''
  Write-Host "Run ${Bold}$MakeCmd verify${NC} to confirm the level is complete."
}

# ─── Command: reset ───────────────────────────────────────────────────────────

function Invoke-Reset {
  Assert-Cluster
  Assert-State

  $levelName = Read-State 'CURRENT_LEVEL'

  Show-Banner $Yellow "♻️   Resetting broken state — $levelName"

  $dir = Get-ScenarioDir $levelName
  if (-not $dir) {
    Write-Host "${Red}✗ Scenario directory not found for '$levelName'.${NC}"
    exit 1
  }

  $brokenDir = Join-Path $dir 'broken'
  if (-not (Test-Path -LiteralPath $brokenDir -PathType Container)) {
    Write-Host "${Red}✗ No broken/ directory found for '$levelName'.${NC}"
    exit 1
  }

  $namespace = "escape-$levelName"

  Write-Host "${Cyan}→ Deleting namespace '$namespace'...${NC}"
  Invoke-Native { kubectl delete namespace $namespace --ignore-not-found=true --wait=true }
  Invoke-Native { kubectl create namespace $namespace }

  Write-Host "${Cyan}→ Re-injecting broken manifests...${NC}"
  Invoke-Native { kubectl apply -f $brokenDir -n $namespace }

  Wait-LevelRollout $levelName $namespace

  Write-State 'HINT_LEVEL' '0'
  Remove-CompletedLevel $levelName

  Write-Host "${Green}✓ Broken state restored.${NC}"
  Write-Host ''
}

# ─── Command: cleanup ─────────────────────────────────────────────────────────

function Invoke-Cleanup {
  Show-Banner $Red '🧹  Tearing Down Escape Room Cluster'

  if (-not (Test-ClusterExist)) {
    Write-Host "${Yellow}⚠  Cluster '$ClusterName' does not exist — nothing to do.${NC}"
  } else {
    Write-Host "${Cyan}→ Deleting kind cluster '$ClusterName'...${NC}"
    Invoke-Native { kind delete cluster --name $ClusterName }
    Write-Host "${Green}✓ Cluster deleted.${NC}"
  }

  # Repo kubeconfig holds client credentials
  $kubeDir = Split-Path -Parent $KindKubeconfig
  if (Test-Path -LiteralPath $kubeDir -PathType Container) {
    Remove-Item -LiteralPath $kubeDir -Recurse -Force
    Write-Host "${Green}✓ Repo kubeconfig removed.${NC}"
  }

  # Clear state
  if (Test-Path -LiteralPath $StateFile -PathType Leaf) {
    Remove-Item -LiteralPath $StateFile -Force
    Write-Host "${Green}✓ State file cleared.${NC}"
  }

  Write-Host ''
  Write-Host "Run ${Bold}$MakeCmd setup${NC} to create a fresh cluster."
  Write-Host ''
}

# ─── Usage ────────────────────────────────────────────────────────────────────

function Show-Usage {
  Show-Header
  Write-Host "${Bold}Usage:${NC}  $MakeCmd <command> [LEVEL=<level>]"
  Write-Host ''
  Write-Host "${Bold}Commands:${NC}"
  Write-Host "  ${Cyan}setup${NC}              Check prerequisites and create the Kind cluster"
  Write-Host "  ${Cyan}prepare${NC}            Setup + pull all scenario images and build app images"
  Write-Host "  ${Cyan}start LEVEL=<level>${NC} Begin a level (e.g. level-01, level-02, level-03, level-04)"
  Write-Host "  ${Cyan}status${NC}             Show active scenario, pod statuses, troubleshooting tips"
  Write-Host "  ${Cyan}hint${NC}               Display the next progressive hint (1 → 2 → 3)"
  Write-Host "  ${Cyan}ai-assist${NC}          Show an AI copilot tip for the current level (does not use a hint)"
  Write-Host "  ${Cyan}verify${NC}             Run the scenario verification probe"
  Write-Host "  ${Cyan}solve${NC}              Apply the reference solution (instructor/emergency only)"
  Write-Host "  ${Cyan}reset${NC}              Re-inject the current level's broken state"
  Write-Host "  ${Cyan}cleanup${NC}            Tear down the Kind cluster"
  Write-Host ''
  Write-Host "${Bold}Valid levels:${NC}  $($ValidLevels -join ' ')"
  Write-Host ''
}

# ─── Entrypoint ───────────────────────────────────────────────────────────────

function Invoke-Main {
  param([AllowEmptyString()][string]$Name, [AllowEmptyString()][string]$LevelArg)
  # Accept make-style `LEVEL=level-01` as well as a bare `level-01`
  if ($LevelArg -match '^LEVEL=(.*)$') { $LevelArg = $Matches[1] }
  switch ($Name) {
    'setup' { Invoke-Setup }
    'prepare' { Invoke-Prepare }
    'start' { Invoke-Start $LevelArg }
    'status' { Invoke-Status }
    'hint' { Invoke-Hint }
    'ai-assist' { Invoke-AiAssist }
    'verify' { Invoke-Verify }
    'solve' { Invoke-Solve }
    'reset' { Invoke-Reset }
    'cleanup' { Invoke-Cleanup }
    '' { Show-Usage }
    'help' { Show-Usage }
    default {
      Write-Host "${Red}✗ Unknown command: '$Name'${NC}"
      Show-Usage
      exit 1
    }
  }
}

# Text piped to native commands (glow) is UTF-8; Windows PowerShell 5.1 defaults to ASCII
$OutputEncoding = $Utf8
$savedConsoleEncoding = Set-ConsoleEncoding $Utf8
# The harness runs inside the caller's session: restore KUBECONFIG afterwards so
# the user's own kubectl commands keep their context.
$savedKubeconfig = $env:KUBECONFIG
try {
  Invoke-Main -Name $Command -LevelArg $Level
} catch {
  Write-Host "${Red}✗ $($_.Exception.Message)${NC}"
  exit 1
} finally {
  $env:KUBECONFIG = $savedKubeconfig
  if ($null -ne $savedConsoleEncoding) { [Console]::OutputEncoding = $savedConsoleEncoding }
}
exit 0
