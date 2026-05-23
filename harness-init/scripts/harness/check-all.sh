#!/usr/bin/env bash
# check-all.sh — Aggregate all harness gate checks
# Usage: bash scripts/harness/check-all.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

total=0
passed=0
failed=0
warned=0
not_run=0

run_check() {
  local script="$1"
  local name="$2"
  total=$((total + 1))

  if [ ! -f "$SCRIPT_DIR/$script" ]; then
    echo "not-run: $name ($script not found)"
    not_run=$((not_run + 1))
    return
  fi

  echo "── $name ──"
  local exit_code=0
  bash "$SCRIPT_DIR/$script" || exit_code=$?

  case $exit_code in
    0) passed=$((passed + 1)) ;;
    1) failed=$((failed + 1)) ;;
    2) not_run=$((not_run + 1)) ;;
    *) warned=$((warned + 1)) ;;
  esac
  echo ""
}

echo "═══════════════════════════════════════"
echo "  Harness Check-All"
echo "═══════════════════════════════════════"
echo ""

# Critical gates
run_check "check-placeholders.sh" "check-placeholders"
run_check "check-alias-integrity.sh" "check-alias-integrity"
run_check "check-wrapper-integrity.sh" "check-wrapper-integrity"
run_check "check-secrets.sh" "check-secrets"
run_check "check-permissions.sh" "check-permissions"
run_check "check-plan-required.sh" "check-plan-required"

# Quality gates
run_check "score-quality.sh" "score-quality"

# Summary
echo "═══════════════════════════════════════"
echo "  Results: $total total | $passed pass | $failed fail | $warned warn | $not_run not-run"
echo "═══════════════════════════════════════"

if [ $failed -gt 0 ]; then
  echo "RESULT: FAIL"
  exit 1
elif [ "${HARNESS_STRICT_MODE:-false}" = "true" ] && [ $not_run -gt 0 ]; then
  echo "RESULT: FAIL"
  echo "Reason: strict mode does not allow not-run checks"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
