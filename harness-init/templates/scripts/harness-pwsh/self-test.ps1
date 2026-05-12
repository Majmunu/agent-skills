#!/usr/bin/env pwsh
# self-test.ps1 — Core self-test functionality (PowerShell degraded mode)
# Usage: pwsh scripts/harness-pwsh/self-test.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

$errors = 0
$warnings = 0
$notRun = 0

function Check-File {
    param([string]$Path)
    $fullPath = Join-Path $RepoRoot $Path
    if (Test-Path $fullPath) {
        if ((Get-Item $fullPath).Length -eq 0) {
            Write-Host "warn: EMPTY file: $Path"
            $script:warnings++
        } else {
            Write-Host "pass: $Path"
        }
    } else {
        Write-Host "FAIL: check-file"
        Write-Host "Reason: Required file missing"
        Write-Host "Evidence: $Path does not exist"
        Write-Host "Fix: Run harness-init to generate missing files"
        Write-Host "Docs: references/regression-fixtures.md"
        Write-Host "Bypass: not allowed"
        Write-Host ""
        $script:errors++
    }
}

function Check-Dir {
    param([string]$Path)
    $fullPath = Join-Path $RepoRoot $Path
    if (Test-Path $fullPath -PathType Container) {
        Write-Host "pass: $Path/"
    } else {
        Write-Host "FAIL: check-dir"
        Write-Host "Reason: Required directory missing"
        Write-Host "Evidence: $Path/ does not exist"
        Write-Host "Fix: Run harness-init to generate missing directories"
        Write-Host "Docs: references/regression-fixtures.md"
        Write-Host "Bypass: not allowed"
        Write-Host ""
        $script:errors++
    }
}

Write-Host "== Harness Self-Test (PowerShell Degraded Mode) =="
Write-Host ""

# Check navigation files
Write-Host "-- Navigation Files --"
$hasNav = (Test-Path (Join-Path $RepoRoot "AGENTS.md")) -or (Test-Path (Join-Path $RepoRoot "CLAUDE.md"))
if ($hasNav) { Write-Host "pass: navigation file exists" } else { $errors++; Write-Host "FAIL: no navigation file (AGENTS.md or CLAUDE.md)" }

# Check core docs
Write-Host ""
Write-Host "-- Core Documentation --"
@("docs/architecture-boundaries.md", "docs/ci-governance.md", "docs/agent-autonomy.md", "docs/observability.md", "docs/feedback-loops.md", "docs/entropy-gc.md") | ForEach-Object { Check-File $_ }

# Check exec-plans
Write-Host ""
Write-Host "-- Execution Plans --"
Check-Dir "docs/exec-plans/active"
Check-Dir "docs/exec-plans/completed"
Check-File "docs/exec-plans/tech-debt-tracker.md"

# Check harness config
Write-Host ""
Write-Host "-- Harness Configuration --"
@(".harness/runtime.yml", ".harness/scorecard.yml", ".harness/integrations.yml") | ForEach-Object { Check-File $_ }

# Note: Advanced checks (placeholder scan, alias integrity, wrapper integrity) not available in PowerShell degraded mode
Write-Host ""
Write-Host "not-run: placeholder-scan (requires bash/grep — not available in PowerShell degraded mode)"
Write-Host "not-run: alias-integrity (requires bash — not available in PowerShell degraded mode)"
Write-Host "not-run: wrapper-integrity (requires bash — not available in PowerShell degraded mode)"
$notRun += 3

# Summary
Write-Host ""
Write-Host "== Summary =="
if ($errors -gt 0) {
    Write-Host "fail: self-test ($errors error(s), $warnings warning(s), $notRun not-run)"
    exit 1
} elseif ($warnings -gt 0) {
    Write-Host "warn: self-test ($warnings warning(s), $notRun not-run)"
    exit 0
} else {
    Write-Host "pass: self-test (all checks passed, $notRun not-run in degraded mode)"
    exit 0
}
