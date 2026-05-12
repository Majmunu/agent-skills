#!/usr/bin/env bash
# check-critical.sh — Run critical gates only (bootstrap minimum blocking surface)
# Usage: bash scripts/harness/check-critical.sh
#
# This script runs ONLY the gates that must never be bypassed:
# - placeholder angle-bracket check
# - expired ADR exception check
# - plan-required gate (PR events only)
# - alias integrity
# - wrapper integrity
# - secrets check
#
# It does NOT run check-all.sh (which includes non-critical checks).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

errors=0
warnings=0

run_gate() {
  local script="$1"
  local name="$2"
  if [ -f "$SCRIPT_DIR/$script" ]; then
    echo "── Running: $name ──"
    if bash "$SCRIPT_DIR/$script"; then
      echo ""
    else
      local exit_code=$?
      if [ $exit_code -ne 0 ]; then
        errors=$((errors + 1))
      fi
      echo ""
    fi
  else
    echo "not-run: $name"
    echo "Reason: $SCRIPT_DIR/$script not found"
    echo "Evidence: script file does not exist"
    echo "Fix: Run harness-init to generate missing gate scripts"
    echo "Docs: references/quality-gates.md"
    echo "Bypass: not allowed"
    echo ""
    errors=$((errors + 1))
  fi
}

cd "$REPO_ROOT"

echo "═══════════════════════════════════════"
echo "  Harness Critical Gates"
echo "═══════════════════════════════════════"
echo ""

# 1. Placeholder angle-bracket check
run_gate "check-placeholders.sh" "check-placeholders"

# 2. Alias integrity
run_gate "check-alias-integrity.sh" "check-alias-integrity"

# 3. Wrapper integrity
run_gate "check-wrapper-integrity.sh" "check-wrapper-integrity"

# 4. Secrets check (always blocking)
run_gate "check-secrets.sh" "check-secrets"

# 5. Permissions check (always blocking for security)
run_gate "check-permissions.sh" "check-permissions"

# 6. Plan-required gate (only on PR events)
if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ] || [ "${CI_PIPELINE_SOURCE:-}" = "merge_request_event" ]; then
  run_gate "check-plan-required.sh" "check-plan-required"
else
  echo "── Skipped: check-plan-required ──"
  echo "Reason: Not a PR/MR event (GITHUB_EVENT_NAME=${GITHUB_EVENT_NAME:-unset})"
  echo ""
fi

# Summary
echo "═══════════════════════════════════════"
if [ $errors -gt 0 ]; then
  echo "CRITICAL GATES: FAILED ($errors gate(s) failed)"
  exit 1
else
  echo "CRITICAL GATES: PASSED"
  exit 0
fi
