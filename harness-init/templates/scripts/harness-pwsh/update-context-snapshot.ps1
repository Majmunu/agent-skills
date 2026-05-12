#!/usr/bin/env pwsh
# update-context-snapshot.ps1 — Context snapshot update (PowerShell degraded mode)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

$snapshotPath = Join-Path $RepoRoot "docs/harness/context-snapshot.md"
$snapshotDir = Split-Path -Parent $snapshotPath

if (-not (Test-Path $snapshotDir)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Scan active plans
$activePlans = @()
$activePlansDir = Join-Path $RepoRoot "docs/exec-plans/active"
if (Test-Path $activePlansDir) {
    $activePlans = Get-ChildItem -Path $activePlansDir -Filter "*.md" | Select-Object -ExpandProperty Name
}

# Scan completed plans (recent 5)
$completedPlans = @()
$completedDir = Join-Path $RepoRoot "docs/exec-plans/completed"
if (Test-Path $completedDir) {
    $completedPlans = Get-ChildItem -Path $completedDir -Filter "*.md" | Sort-Object LastWriteTime -Descending | Select-Object -First 5 -ExpandProperty Name
}

# Generate snapshot
$content = @"
# Harness Context Snapshot

## Current State
- CI Mode: TODO: 待补充
- Autonomy Level: TODO: 待补充
- Quality Score: TODO: 待补充
- Last Updated: $timestamp

## Active Plans
$( if ($activePlans.Count -eq 0) { "- None" } else { ($activePlans | ForEach-Object { "- $_" }) -join "`n" } )

## Recently Completed Plans
$( if ($completedPlans.Count -eq 0) { "- None" } else { ($completedPlans | ForEach-Object { "- $_" }) -join "`n" } )

## Open Tech Debts
- TODO: 待补充 (scan tech-debt-tracker.md)

## Failing Gates
- not-run: gate scanning requires bash

## Active ADR Exceptions
- TODO: 待补充

## Recent Incidents
- None recorded

## Current Runtime Surface
- not-run: runtime surface scanning requires bash

## Integration Status
- not-run: integration status check requires bash

## Next Recommended Actions
1. Run full harness validation with bash: ``bash scripts/harness/check-all.sh``
2. Update this snapshot with bash version for complete data
"@

Set-Content -Path $snapshotPath -Value $content -Encoding UTF8
Write-Host "pass: update-context-snapshot"
Write-Host "Updated: $snapshotPath"
Write-Host "Timestamp: $timestamp"
Write-Host "Note: PowerShell degraded mode — some sections marked as not-run"
