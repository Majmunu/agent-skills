#!/usr/bin/env bash
# doc-gardening.sh — Scan for stale/drifted documentation
# Usage: bash scripts/harness/doc-gardening.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

warnings=0

echo "── Doc Gardening: Stale Document Scan ──"

# Check for docs not modified in 90+ days
if command -v find >/dev/null 2>&1; then
  STALE_DOCS=$(find docs -name "*.md" -mtime +90 2>/dev/null || true)
  if [ -n "$STALE_DOCS" ]; then
    echo "warn: stale documents (not modified in 90+ days):"
    echo "$STALE_DOCS" | while read -r f; do
      echo "  - $f"
      warnings=$((warnings + 1))
    done
  else
    echo "pass: no stale documents found"
  fi
else
  echo "not-run: doc-gardening:stale-scan"
  echo "Reason: 'find' command not available"
  echo "Fix: Install coreutils or run in bash environment"
  echo "Docs: references/gc-templates.md"
fi

# Check for expired ADR exceptions
echo ""
echo "── Doc Gardening: Expired ADR Exceptions ──"
ADR_DIR="docs/decisions/ADR-exceptions"
if [ -d "$ADR_DIR" ]; then
  TODAY=$(date +%Y-%m-%d 2>/dev/null || echo "unknown")
  if [ "$TODAY" != "unknown" ]; then
    while IFS= read -r -d '' adr; do
      EXPIRES=$(grep -i "expires_on:" "$adr" 2>/dev/null | head -1 | sed 's/.*expires_on:[[:space:]]*//' || true)
      if [ -n "$EXPIRES" ] && [[ "$EXPIRES" < "$TODAY" ]]; then
        echo "warn: expired ADR exception: $adr (expired: $EXPIRES)"
        warnings=$((warnings + 1))
      fi
    done < <(find "$ADR_DIR" -name "*.md" -print0 2>/dev/null)
    [ $warnings -eq 0 ] && echo "pass: no expired ADR exceptions"
  else
    echo "not-run: date command unavailable"
  fi
else
  echo "pass: no ADR-exceptions directory (nothing to check)"
fi

# Summary
echo ""
if [ $warnings -gt 0 ]; then
  echo "warn: doc-gardening ($warnings issue(s) found)"
  exit 0
else
  echo "pass: doc-gardening (all documents healthy)"
  exit 0
fi
