# PSScriptAnalyzer settings for scripts/*.ps1 and scenarios/*/verify.ps1.
# Used by `.\scripts\make.ps1 lint` and `make lint` (when pwsh is installed).
@{
  ExcludeRules = @(
    # Interactive CLI scripts: coloured console output is their job.
    'PSAvoidUsingWriteHost',
    # Private script functions, not cmdlets: -WhatIf/-Confirm would add nothing.
    'PSUseShouldProcessForStateChangingFunctions',
    # Fires on native tools that ship a .ps1 shim (npm, npx on Windows).
    'PSAvoidUsingPositionalParameters'
  )
  Rules = @{
    # The scripts must keep running on Windows PowerShell 5.1.
    PSUseCompatibleSyntax = @{
      Enable = $true
      TargetVersions = @('5.1', '7.0')
    }
  }
}
