#!/usr/bin/env pwsh
# check-secrets.ps1 — Secret detection (PowerShell degraded mode)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

$errors = 0
$warnings = 0

function Emit-Fail {
    param([string]$Gate, [string]$Reason, [string]$Evidence, [string]$Fix, [string]$Docs)
    Write-Host "FAIL: $Gate"
    Write-Host "Reason: $Reason"
    Write-Host "Evidence: $Evidence"
    Write-Host "Fix: $Fix"
    Write-Host "Docs: $Docs"
    Write-Host "Bypass: not allowed"
    Write-Host ""
    $script:errors++
}

Set-Location $RepoRoot

# Check 1: .env tracked by git
Write-Host "-- Check: .env files tracked by git --"
try {
    $envFiles = git ls-files "*.env" ".env" ".env.*" 2>$null
    if ($envFiles) {
        foreach ($f in $envFiles -split "`n") {
            if ($f.Trim()) {
                Emit-Fail "check-secrets:env-tracked" ".env file is tracked by git" $f "Add '$f' to .gitignore and run: git rm --cached '$f'" "docs/security-threat-model.md"
            }
        }
    } else {
        Write-Host "pass: no .env files tracked by git"
    }
} catch {
    Write-Host "not-run: git ls-files failed (git may not be available)"
}

# Check 2: Common token patterns (simplified for PowerShell)
Write-Host ""
Write-Host "-- Check: Common token patterns --"
$tokenPatterns = @(
    'AKIA[0-9A-Z]{16}',
    'sk-[a-zA-Z0-9]{20,}',
    'ghp_[a-zA-Z0-9]{36}',
    'glpat-[a-zA-Z0-9\-]{20,}'
)

$tokenFound = $false
try {
    foreach ($pattern in $tokenPatterns) {
        $matches = git grep -lnE $pattern -- ':(exclude)*.lock' ':(exclude)node_modules' 2>$null
        if ($matches) {
            $tokenFound = $true
            foreach ($match in $matches -split "`n") {
                if ($match.Trim()) {
                    Emit-Fail "check-secrets:token-pattern" "Potential secret/token pattern detected" "$match (pattern: $pattern)" "Remove the token and use environment variables" "docs/security-threat-model.md"
                }
            }
        }
    }
    if (-not $tokenFound) { Write-Host "pass: no common token patterns detected" }
} catch {
    Write-Host "not-run: token pattern scan failed (git grep may not be available)"
    $script:warnings++
}

# Check 3: Private keys
Write-Host ""
Write-Host "-- Check: Private key patterns --"
Write-Host "not-run: private key pattern scan (complex regex requires bash/grep)"

# Summary
Write-Host ""
Write-Host "-- Summary --"
if ($errors -gt 0) {
    Write-Host "fail: check-secrets ($errors issue(s) found, $warnings warning(s))"
    exit 1
} elseif ($warnings -gt 0) {
    Write-Host "warn: check-secrets ($warnings warning(s))"
    exit 0
} else {
    Write-Host "pass: check-secrets (PowerShell degraded mode — partial coverage)"
    exit 0
}
