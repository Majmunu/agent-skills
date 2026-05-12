#!/usr/bin/env bash
# check-wrapper-integrity.sh — Verify legacy root scripts are wrappers only
# Usage: bash scripts/harness/check-wrapper-integrity.sh
#
# Legacy scripts in the repo root must:
# - Call scripts/harness/* (canonical path)
# - Pass through all arguments
# - Preserve exit code
# - Contain NO business logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

errors=0
warnings=0

echo "── Check: Wrapper integrity ──"

# Find shell scripts in root scripts/ that are NOT in scripts/harness/
WRAPPER_CANDIDATES=$(find scripts -maxdepth 1 -name "*.sh" -o -name "*.ps1" 2>/dev/null || true)

if [ -z "$WRAPPER_CANDIDATES" ]; then
  echo "pass: no legacy wrapper scripts found"
  exit 0
fi

while IFS= read -r wrapper; do
  [ -z "$wrapper" ] && continue
  [ ! -f "$wrapper" ] && continue

  # Check if it references scripts/harness/
  if grep -q 'scripts/harness/' "$wrapper" 2>/dev/null; then
    # Verify it doesn't contain business logic (heuristic: more than 20 non-comment lines)
    CODE_LINES=$(grep -cvE '^\s*(#|$|//|rem )' "$wrapper" 2>/dev/null || echo "0")
    if [ "$CODE_LINES" -gt 20 ]; then
      echo "FAIL: check-wrapper-integrity"
      echo "Reason: Wrapper script contains too much logic ($CODE_LINES code lines)"
      echo "Evidence: $wrapper"
      echo "Fix: Move business logic to scripts/harness/ and keep wrapper as passthrough only"
      echo "Docs: references/quality-gates.md"
      echo "Bypass: not allowed"
      echo ""
      errors=$((errors + 1))
    else
      echo "pass: $wrapper (valid wrapper → scripts/harness/)"
    fi
  else
    echo "warn: check-wrapper-integrity"
    echo "Reason: Root script does not reference scripts/harness/"
    echo "Evidence: $wrapper"
    echo "Fix: Convert to wrapper that calls canonical script in scripts/harness/"
    echo "Docs: references/quality-gates.md"
    echo ""
    warnings=$((warnings + 1))
  fi
done <<< "$WRAPPER_CANDIDATES"

# Summary
echo ""
if [ $errors -gt 0 ]; then
  echo "fail: check-wrapper-integrity ($errors violation(s), $warnings warning(s))"
  exit 1
elif [ $warnings -gt 0 ]; then
  echo "warn: check-wrapper-integrity ($warnings warning(s))"
  exit 0
else
  echo "pass: check-wrapper-integrity (all wrappers valid)"
  exit 0
fi
