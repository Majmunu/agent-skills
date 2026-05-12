#!/usr/bin/env bash
# check-placeholders.sh — Detect unresolved angle-bracket placeholders in harness-managed files
# Usage: bash scripts/harness/check-placeholders.sh
#
# Fails on: <...> angle-bracket placeholders
# Warns on: TODO, FIXME, TBD, 待补充
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

errors=0
warnings=0

# Define scan roots (only harness-managed files)
SCAN_ROOTS=()
[ -f "AGENTS.md" ] && SCAN_ROOTS+=("AGENTS.md")
[ -f "CLAUDE.md" ] && SCAN_ROOTS+=("CLAUDE.md")
[ -d "docs" ] && SCAN_ROOTS+=("docs")
for p in apps/*/docs packages/*/docs services/*/docs; do
  [ -d "$p" ] && SCAN_ROOTS+=("$p")
done

if [ "${#SCAN_ROOTS[@]}" -eq 0 ]; then
  echo "warn: check-placeholders"
  echo "Reason: No harness markdown targets found"
  echo "Evidence: No AGENTS.md, CLAUDE.md, or docs/ directory"
  echo "Fix: Run harness-init to generate documentation scaffold"
  echo "Docs: references/quality-gates.md"
  exit 0
fi

echo "── Check: Angle-bracket placeholders ──"

# Scan for <...> patterns (exclude harness markers and URLs)
ANGLE_HITS=$(find "${SCAN_ROOTS[@]}" -type f -name "*.md" -print0 2>/dev/null \
  | xargs -0 grep -nE '<[^>]+>' 2>/dev/null \
  | grep -v 'harness-init:' \
  | grep -v '://' \
  | grep -v '<!--' \
  | grep -v '<br' \
  | grep -v '<img' \
  | grep -v '<a ' \
  || true)

if [ -n "$ANGLE_HITS" ]; then
  echo "FAIL: check-placeholders:angle-bracket"
  echo "Reason: Unresolved angle-bracket placeholders found in harness-managed files"
  echo "Evidence:"
  echo "$ANGLE_HITS" | head -20
  echo "Fix: Replace <...> placeholders with actual values or 'TODO: 待补充'"
  echo "Docs: references/quality-gates.md"
  echo "Bypass: not allowed"
  echo ""
  errors=$((errors + 1))
else
  echo "pass: no angle-bracket placeholders"
fi

echo ""
echo "── Check: TODO/FIXME placeholders ──"

TODO_HITS=$(find "${SCAN_ROOTS[@]}" -type f -name "*.md" -print0 2>/dev/null \
  | xargs -0 grep -nE 'TODO|FIXME|TBD|待补充' 2>/dev/null \
  | grep -v 'harness-init:' \
  || true)

if [ -n "$TODO_HITS" ]; then
  TODO_COUNT=$(echo "$TODO_HITS" | wc -l | tr -d ' ')
  echo "warn: check-placeholders:todo ($TODO_COUNT occurrence(s))"
  echo "Reason: TODO/FIXME/TBD/待补充 placeholders found"
  echo "Evidence:"
  echo "$TODO_HITS" | head -10
  echo "Fix: Fill in actual values where possible"
  echo "Docs: references/quality-gates.md"
  echo ""
  warnings=$((warnings + 1))
else
  echo "pass: no TODO placeholders"
fi

# Summary
echo ""
echo "── Summary ──"
if [ $errors -gt 0 ]; then
  echo "fail: check-placeholders ($errors error(s), $warnings warning(s))"
  exit 1
elif [ $warnings -gt 0 ]; then
  echo "warn: check-placeholders ($warnings warning(s))"
  exit 0
else
  echo "pass: check-placeholders (all checks passed)"
  exit 0
fi
