#!/usr/bin/env pwsh
# score-quality.ps1 — Quality scoring (PowerShell degraded mode)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

$scorecardPath = Join-Path $RepoRoot ".harness/scorecard.yml"
if (-not (Test-Path $scorecardPath)) {
    Write-Host "not-run: score-quality"
    Write-Host "Reason: .harness/scorecard.yml not found"
    Write-Host "Evidence: $scorecardPath does not exist"
    Write-Host "Fix: Run harness-init to generate .harness/scorecard.yml"
    Write-Host "Docs: references/scorecard-templates.md"
    Write-Host "Bypass: not allowed"
    exit 0
}

# Simplified scoring based on file existence checks
$score = 0
$maxScore = 100

# context_readability (20)
$cr = 0
if ((Test-Path (Join-Path $RepoRoot "AGENTS.md")) -or (Test-Path (Join-Path $RepoRoot "CLAUDE.md"))) { $cr += 10 }
if (Test-Path (Join-Path $RepoRoot "docs/harness/context-snapshot.md")) { $cr += 10 }
$score += $cr

# plan_discipline (15)
$pd = 0
if (Test-Path (Join-Path $RepoRoot "docs/exec-plans/active") -PathType Container) { $pd += 8 }
if (Test-Path (Join-Path $RepoRoot "docs/exec-plans/tech-debt-tracker.md")) { $pd += 7 }
$score += $pd

# architecture_enforcement (20)
$ae = 0
if (Test-Path (Join-Path $RepoRoot "docs/architecture-boundaries.md")) { $ae += 10 }
if (Test-Path (Join-Path $RepoRoot "scripts/harness/check-boundaries.sh")) { $ae += 10 }
$score += $ae

# test_confidence (15)
$tc = 0
if (Test-Path (Join-Path $RepoRoot "tests") -PathType Container) { $tc += 8 }
if (Test-Path (Join-Path $RepoRoot "fixtures") -PathType Container) { $tc += 7 }
$score += $tc

# observability_surface (15)
$os = 0
if (Test-Path (Join-Path $RepoRoot ".harness/runtime.yml")) { $os += 8 }
if (Test-Path (Join-Path $RepoRoot ".harness/observability.yml")) { $os += 7 }
$score += $os

# entropy_control (10)
$ec = 0
if (Test-Path (Join-Path $RepoRoot "docs/entropy-gc.md")) { $ec += 5 }
if (Test-Path (Join-Path $RepoRoot "scripts/harness/doc-gardening.sh")) { $ec += 5 }
$score += $ec

# autonomy_readiness (5)
$ar = 0
if (Test-Path (Join-Path $RepoRoot "docs/agent-autonomy.md")) { $ar += 3 }
if (Test-Path (Join-Path $RepoRoot ".harness/autonomy.yml")) { $ar += 2 }
$score += $ar

# Output
Write-Host "Quality Score: $score/$maxScore"
if ($score -ge 92) { Write-Host "Mode Recommendation: autonomy L4" }
elseif ($score -ge 85) { Write-Host "Mode Recommendation: autonomy L3" }
elseif ($score -ge 80) { Write-Host "Mode Recommendation: enforced" }
elseif ($score -ge 60) { Write-Host "Mode Recommendation: bootstrap" }
else { Write-Host "Mode Recommendation: below bootstrap minimum" }

Write-Host ""
Write-Host "Breakdown:"
Write-Host "- context_readability: $cr/20"
Write-Host "- plan_discipline: $pd/15"
Write-Host "- architecture_enforcement: $ae/20"
Write-Host "- test_confidence: $tc/15"
Write-Host "- observability_surface: $os/15"
Write-Host "- entropy_control: $ec/10"
Write-Host "- autonomy_readiness: $ar/5"
Write-Host ""
Write-Host "Note: PowerShell degraded mode — scoring based on file existence only"
Write-Host "not-run: detailed gate-based scoring (requires bash)"
