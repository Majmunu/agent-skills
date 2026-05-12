#!/usr/bin/env pwsh
# check-permissions.ps1 — Permission boundary check (PowerShell degraded mode)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

$integrationsFile = Join-Path $RepoRoot ".harness/integrations.yml"

$errors = 0
$warnings = 0

# Check integrations.yml exists
Write-Host "-- Check: Integrations configuration --"
if (-not (Test-Path $integrationsFile)) {
    Write-Host "not-run: check-permissions"
    Write-Host "Reason: .harness/integrations.yml not found"
    Write-Host "Evidence: $integrationsFile does not exist"
    Write-Host "Fix: Run harness-init to generate .harness/integrations.yml"
    Write-Host "Docs: references/permission-boundaries.md"
    Write-Host "Bypass: not allowed"
    exit 0
}
Write-Host "pass: integrations.yml exists"

# Check dangerous operations
Write-Host ""
Write-Host "-- Check: MCP dangerous operations --"
$content = Get-Content $integrationsFile -Raw
$dangerousOps = @("delete", "force-push", "production-deploy", "permission-change", "database-migration", "secret-rotation")

if ($content -match "approval_required_for") {
    foreach ($op in $dangerousOps) {
        if ($content -match $op) {
            Write-Host "pass: dangerous operation '$op' has approval policy"
        } else {
            Write-Host "warn: check-permissions:mcp-approval"
            Write-Host "Reason: Dangerous operation '$op' not listed in approval_required_for"
            Write-Host "Evidence: $integrationsFile"
            Write-Host "Fix: Add '$op' to mcp.servers.*.approval_required_for list"
            Write-Host "Docs: references/permission-boundaries.md"
            Write-Host ""
            $warnings++
        }
    }
} else {
    if ($content -match "mcp:") {
        Write-Host "FAIL: check-permissions:mcp-no-approval"
        Write-Host "Reason: MCP section exists but no approval_required_for policy defined"
        Write-Host "Evidence: $integrationsFile"
        Write-Host "Fix: Add approval_required_for list with dangerous operations"
        Write-Host "Docs: references/permission-boundaries.md"
        Write-Host "Bypass: not allowed"
        Write-Host ""
        $errors++
    } else {
        Write-Host "pass: MCP not configured (no dangerous operations to gate)"
    }
}

# Summary
Write-Host ""
Write-Host "-- Summary --"
if ($errors -gt 0) {
    Write-Host "fail: check-permissions ($errors issue(s), $warnings warning(s))"
    exit 1
} elseif ($warnings -gt 0) {
    Write-Host "warn: check-permissions ($warnings warning(s))"
    exit 0
} else {
    Write-Host "pass: check-permissions (all checks passed)"
    exit 0
}
