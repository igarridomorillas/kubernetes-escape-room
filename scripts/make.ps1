#Requires -Version 5.1
<#
.SYNOPSIS
  Task runner for Windows: the PowerShell counterpart of the Makefile.

.DESCRIPTION
  Same targets as the Makefile: replace `make <target>` with
  `.\scripts\make.ps1 <target>`. LEVEL works the same way
  (`.\scripts\make.ps1 start LEVEL=level-02`, or `-Level level-02`).
  Harness targets run scripts/escape-room.ps1. Runs on Windows PowerShell 5.1
  and PowerShell 7+.

.EXAMPLE
  .\scripts\make.ps1 start LEVEL=level-01
#>
param(
  [Parameter(Position = 0)][string]$Target = 'help',
  [Parameter(Position = 1)][string]$Level = 'level-01'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Harness = Join-Path $PSScriptRoot 'escape-room.ps1'
$AnalyzerSettings = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'
$SlidesDir = [IO.Path]::Combine($RepoRoot, 'docs', 'presentation')
$AllLevels = @('level-01', 'level-02', 'level-03', 'level-04')
$OnWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$Self = if ($OnWindows) { '.\scripts\make.ps1' } else { './scripts/make.ps1' }
$Cyan = [char]27 + '[36m'
$NC = [char]27 + '[0m'
$Utf8 = New-Object System.Text.UTF8Encoding $false

# Accept make-style `LEVEL=level-01` as well as a bare `level-01`
if ($Level -match '^LEVEL=(.*)$') { $Level = $Matches[1] }

# Targets and their help text, in the Makefile's order
$Targets = [ordered]@{
  'help'          = 'Show this help menu'
  'setup-dev'     = 'Install contributor/dev requirements (PSScriptAnalyzer, shellcheck, Slidev, Playwright & agent skills)'
  'slides'        = 'Start the live-reloading Slidev presentation server (http://localhost:3030)'
  'slides-export' = 'Build and export presentation slides to PDF'
  'lint'          = 'Run PSScriptAnalyzer on the PowerShell scripts, then shellcheck on the Bash scripts if installed'
  'lint-ps'       = 'Run PSScriptAnalyzer only (used by make lint on macOS/Linux)'
  'check'         = 'Check the Bash scripts are executable in git, .ps1 files have a UTF-8 BOM, and no hardcoded user home paths'
  'validate'      = 'Run all static validations (lint + check)'
  'setup'         = "Create Kind cluster 'escape-room' and install Cilium CNI"
  'cleanup'       = 'Tear down Kind cluster and clean local state'
  'prepare'       = 'Create cluster, pull every scenario image, build app images'
  'start'         = "Start a level (e.g., $Self start LEVEL=level-01)"
  'status'        = 'Show active scenario and pod statuses'
  'hint'          = 'Display the next progressive hint (1 -> 2 -> 3)'
  'ai-assist'     = 'Show the spoiler-free AI copilot tip for the active level'
  'verify'        = "Run the active level's in-cluster verification probe"
  'solve'         = 'Apply the reference solution for the active level (instructor only)'
  'reset'         = "Re-inject the active level's broken state"
  'test'          = "DESTRUCTIVE: smoke-test levels, resets .room-state ($Self test LEVEL=level-01 or LEVEL=all)"
}
$HarnessTargets = @('setup', 'cleanup', 'prepare', 'start', 'status', 'hint', 'ai-assist', 'verify', 'solve', 'reset')

# Runs a native command and stops with exit code 1 when it fails, as make does.
# The error preference is relaxed locally: Windows PowerShell 5.1 would turn
# redirected stderr into a terminating error.
function Invoke-Native {
  param(
    [Parameter(Mandatory = $true, Position = 0)][scriptblock]$ScriptBlock,
    [switch]$AllowFailure
  )
  $ErrorActionPreference = 'Continue'
  $global:LASTEXITCODE = 1
  try {
    & $ScriptBlock
  } catch [Management.Automation.CommandNotFoundException] {
    Write-Host "✗ $($_.Exception.Message)"
    $global:LASTEXITCODE = 127
  }
  if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) { exit 1 }
}

function Test-Command {
  param([Parameter(Mandatory = $true)][string]$Name)
  return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
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

function Get-RelativePath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return $Path.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
}

function Get-PowerShellScript {
  @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File) +
  @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'scenarios') -Filter 'verify.ps1' -File -Recurse)
}

function Get-BashScript {
  @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.sh' -File) +
  @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'scenarios') -Filter 'verify.sh' -File -Recurse)
}

# ─── Help ─────────────────────────────────────────────────────────────────────

function Show-Help {
  Write-Host ''
  Write-Host 'Kubernetes Escape Room — make.ps1 Targets'
  Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  foreach ($name in $Targets.Keys) {
    Write-Host ('  {0}{1,-18}{2} {3}' -f $Cyan, $name, $NC, $Targets[$name])
  }
  Write-Host ''
}

# ─── Contributor & Presentation Setup ─────────────────────────────────────────

function Install-DevRequirement {
  if (Test-Command 'shellcheck') {
    Write-Host '✓ shellcheck is installed.'
  } elseif ($OnWindows -and (Test-Command 'winget')) {
    Write-Host '→ Installing shellcheck via winget...'
    Invoke-Native -AllowFailure { winget install --id koalaman.shellcheck --exact --accept-source-agreements --accept-package-agreements }
    if ($LASTEXITCODE -ne 0) { Write-Host '⚠ Could not install shellcheck; lint skips the Bash scripts without it.' }
  } elseif (Test-Command 'brew') {
    Write-Host '→ Installing shellcheck via Homebrew...'
    Invoke-Native { brew install shellcheck }
  } else {
    Write-Host '⚠ shellcheck not found. Install it via your package manager (e.g., winget/scoop/choco/apt/brew).'
  }

  if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    Write-Host '✓ PSScriptAnalyzer is installed.'
  } else {
    Write-Host '→ Installing PSScriptAnalyzer from the PowerShell Gallery (current user)...'
    try {
      Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
      Write-Host "⚠ Could not install PSScriptAnalyzer ($($_.Exception.Message)). Run 'Install-Module PSScriptAnalyzer -Scope CurrentUser' manually."
    }
  }

  Write-Host '→ Installing Slidev dependencies in docs/presentation...'
  Invoke-Native { npm --prefix $SlidesDir install }
  Write-Host '→ Installing Playwright Chromium for PDF export...'
  Invoke-Native { npx --prefix $SlidesDir playwright install chromium }
  Write-Host '→ Restoring pinned agent skills from skills-lock.json...'
  Invoke-Native -AllowFailure { npx --yes skills experimental_install }
  if ($LASTEXITCODE -ne 0) { Write-Host "⚠ Could not restore agent skills; run 'npx skills experimental_install' manually." }
}

function Invoke-SlideServer {
  if (-not (Test-Path -LiteralPath (Join-Path $SlidesDir 'node_modules') -PathType Container)) { Install-DevRequirement }
  Invoke-Native { npm --prefix $SlidesDir run dev }
}

function Invoke-SlideExport {
  if (-not (Test-Path -LiteralPath ([IO.Path]::Combine($SlidesDir, 'node_modules', 'playwright-chromium')) -PathType Container)) {
    Install-DevRequirement
  }
  Invoke-Native { npm --prefix $SlidesDir run build }
  Invoke-Native { npm --prefix $SlidesDir run export }
}

# ─── Validation & Linting ─────────────────────────────────────────────────────

function Invoke-PowerShellLint {
  if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "✗ PSScriptAnalyzer is not installed. Run: $Self setup-dev"
    exit 1
  }
  $findings = @(foreach ($file in Get-PowerShellScript) {
      Invoke-ScriptAnalyzer -Path $file.FullName -Settings $AnalyzerSettings
    })
  foreach ($finding in $findings) {
    Write-Host ('{0}:{1}: [{2}] {3}: {4}' -f (Get-RelativePath $finding.ScriptPath), $finding.Line, $finding.Severity, $finding.RuleName, $finding.Message)
  }
  if ($findings.Count -gt 0) {
    Write-Host "✗ PSScriptAnalyzer reported $($findings.Count) finding(s)."
    exit 1
  }
  Write-Host '✓ PSScriptAnalyzer found no issues.'
}

function Invoke-Lint {
  Invoke-PowerShellLint
  if (Test-Command 'shellcheck') {
    $bashScripts = @(Get-BashScript | ForEach-Object { $_.FullName })
    Invoke-Native { shellcheck $bashScripts }
    Write-Host '✓ shellcheck found no issues.'
  } else {
    Write-Host "⚠ shellcheck not found; skipped the Bash scripts (install it with: $Self setup-dev)."
  }
}

# PowerShell counterpart of `make check`, plus checks that matter on Windows
function Invoke-Check {
  $failed = $false

  # 1. Bash scripts stay executable. NTFS has no mode bits, so on Windows check
  #    the mode git records (100755); on macOS/Linux apply 750 like `make check`.
  $bashScripts = @(Get-BashScript)
  if ($OnWindows) {
    if (Test-Command 'git') {
      $relative = @($bashScripts | ForEach-Object { Get-RelativePath $_.FullName })
      $entries = @(Invoke-Native -AllowFailure { git -C $RepoRoot ls-files -s -- $relative })
      foreach ($path in $relative) {
        $entry = @($entries | Where-Object { $_ -like "*`t$path" }) | Select-Object -First 1
        if (-not $entry) {
          Write-Host "⚠ $path is not tracked by git yet; add it with: git add --chmod=+x $path"
        } elseif (-not "$entry".StartsWith('100755 ')) {
          Write-Host "✗ $path is not executable in git. Run: git update-index --chmod=+x $path"
          $failed = $true
        }
      }
      if (-not $failed) { Write-Host '✓ All Bash scripts are executable in git (make check applies 750 on macOS/Linux).' }
    } else {
      Write-Host '⚠ git not found; skipped the executable-bit check.'
    }
  } else {
    foreach ($script in $bashScripts) { Invoke-Native { chmod 750 $script.FullName } }
    Write-Host '✓ All executable scripts have 750 permissions.'
  }

  # 2. Windows PowerShell 5.1 reads BOM-less scripts as ANSI and garbles their
  #    non-ASCII text (emoji, box drawing), so every .ps1 needs a UTF-8 BOM.
  $missingBom = $false
  foreach ($script in Get-PowerShellScript) {
    $bytes = [IO.File]::ReadAllBytes($script.FullName)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
      Write-Host "✗ $(Get-RelativePath $script.FullName) has no UTF-8 BOM (Windows PowerShell 5.1 would misread it)."
      $missingBom = $true
    }
  }
  if ($missingBom) { $failed = $true } else { Write-Host '✓ All PowerShell scripts start with a UTF-8 BOM.' }

  # 3. No hardcoded user home paths (macOS, Linux or Windows)
  $pattern = '(/Users/[a-zA-Z0-9_-]+|/home/[a-zA-Z0-9_-]+|[A-Za-z]:\\Users\\[a-zA-Z0-9_-]+)'
  $hits = 0
  foreach ($root in @('docs', 'scenarios', 'scripts', 'README.md', '.mcp.json', '.agents')) {
    $path = Join-Path $RepoRoot $root
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $files = @(Get-ChildItem -LiteralPath $path -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist|\.slidev)[\\/]' })
    foreach ($file in $files) {
      $text = [IO.File]::ReadAllText($file.FullName)
      if ($text.Contains([string][char]0)) { continue }  # binary file
      $lineNumber = 0
      foreach ($line in ($text -split '\r?\n')) {
        $lineNumber++
        if ($line -cmatch $pattern) {
          Write-Host "$(Get-RelativePath $file.FullName):${lineNumber}:$line"
          $hits++
        }
      }
    }
  }
  if ($hits -gt 0) {
    Write-Host '✗ Found hardcoded user home path(s) above.'
    $failed = $true
  } else {
    Write-Host '✓ No hardcoded user home paths found.'
  }

  if ($failed) { exit 1 }
}

# ─── End-to-End Level Smoke Testing ───────────────────────────────────────────

# Runs a harness command in this session and stops on failure, as make does
function Invoke-HarnessStep {
  param([Parameter(Mandatory = $true)][string[]]$Arguments, [switch]$Quiet)
  if ($Quiet) { & $Harness @Arguments *> $null } else { & $Harness @Arguments }
  if ($LASTEXITCODE -ne 0) { exit 1 }
}

# Runs a harness command with its output hidden; returns $true when it exits 0
function Test-HarnessStep {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)
  & $Harness @Arguments *> $null
  return ($LASTEXITCODE -eq 0)
}

function Invoke-SmokeTest {
  $levels = if ($Level -eq 'all') { $AllLevels } else { @($Level) }
  foreach ($lvl in $levels) {
    Write-Host "━━━ Smoke-testing $lvl ━━━"
    Invoke-HarnessStep -Arguments @('start', $lvl)
    if (Test-HarnessStep -Arguments @('verify')) {
      Write-Host "✗ ERROR: $lvl passed verify while in broken state!"
      exit 1
    }
    Write-Host "✓ $lvl broken state verified (verify exited 1 as expected)"
    Invoke-HarnessStep -Arguments @('ai-assist') -Quiet
    Invoke-HarnessStep -Arguments @('hint') -Quiet
    Invoke-HarnessStep -Arguments @('solve')
    Invoke-HarnessStep -Arguments @('verify')
    Invoke-HarnessStep -Arguments @('reset')
    if (Test-HarnessStep -Arguments @('verify')) {
      Write-Host "✗ ERROR: $lvl passed verify after reset!"
      exit 1
    }
    Write-Host "✓ $lvl reset state verified (verify exited 1 as expected)"
  }
  if ($Level -eq 'all') {
    Write-Host '🎉 All levels (01–04) passed end-to-end smoke testing!'
  }
}

# ─── Entrypoint ───────────────────────────────────────────────────────────────

$savedConsoleEncoding = Set-ConsoleEncoding $Utf8
Push-Location -LiteralPath $RepoRoot
try {
  if ($HarnessTargets -contains $Target) {
    if ($Target -eq 'start') { & $Harness start $Level } else { & $Harness $Target }
    exit $LASTEXITCODE
  }
  switch ($Target) {
    'help' { Show-Help }
    'setup-dev' { Install-DevRequirement }
    'slides' { Invoke-SlideServer }
    'slides-export' { Invoke-SlideExport }
    'lint' { Invoke-Lint }
    'lint-ps' { Invoke-PowerShellLint }
    'check' { Invoke-Check }
    'validate' { Invoke-Lint; Invoke-Check }
    'test' { Invoke-SmokeTest }
    default {
      Write-Host "✗ Unknown target: '$Target'"
      Show-Help
      exit 1
    }
  }
} finally {
  Pop-Location
  if ($null -ne $savedConsoleEncoding) { [Console]::OutputEncoding = $savedConsoleEncoding }
}
exit 0
