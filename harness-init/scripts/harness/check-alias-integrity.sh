#!/usr/bin/env bash
# check-alias-integrity.sh — Verify legacy docs are aliases only (no governance facts)
# Usage: bash scripts/harness/check-alias-integrity.sh
#
# Canonical docs are the source of truth. Legacy docs must only contain
# links/references to canonical paths, not independent governance content.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

errors=0

# Define canonical paths
CANONICAL_DOCS=(
  "docs/architecture-boundaries.md"
  "docs/ci-governance.md"
  "docs/agent-autonomy.md"
  "docs/observability.md"
  "docs/feedback-loops.md"
  "docs/entropy-gc.md"
)

# Governance keywords that should only appear in canonical docs
GOVERNANCE_KEYWORDS="(architecture.boundary|ci.governance|autonomy.level|gate.policy|promotion.criteria|feedback.loop|entropy.gc)"

echo "── Check: Legacy alias integrity ──"

# Find markdown files that are NOT in canonical paths but contain governance facts
LEGACY_FILES=$(find . -name "*.md" -not -path "./docs/*" -not -path "./node_modules/*" \
  -not -path "./.git/*" -not -path "./dist/*" -not -path "./build/*" \
  -not -path "./.kiro/*" -not -path "./fixtures/*" -not -path "./tests/*" \
  -not -path "./templates/*" -not -path "./references/*" -not -path "./subagents/*" \
  -not -name "AGENTS.md" -not -name "CLAUDE.md" -not -name "README.md" \
  -not -name "SKILL.md" -not -name "*.requirements.md" \
  2>/dev/null || true)

if [ -z "$LEGACY_FILES" ]; then
  echo "pass: no legacy docs found outside canonical paths"
  exit 0
fi

while IFS= read -r file; do
  [ -z "$file" ] && continue
  # Check if file contains governance-level content (more than just a link)
  CONTENT_LINES=$(wc -l < "$file" 2>/dev/null || echo "0")
  if [ "$CONTENT_LINES" -gt 10 ]; then
    # Check for governance keywords
    HITS=$(grep -niE "$GOVERNANCE_KEYWORDS" "$file" 2>/dev/null || true)
    if [ -n "$HITS" ]; then
      echo "FAIL: check-alias-integrity"
      echo "Reason: Legacy doc contains governance facts (should be alias only)"
      echo "Evidence: $file"
      echo "$HITS" | head -5
      echo "Fix: Move governance content to canonical path (docs/) and replace with link"
      echo "Docs: docs/harness/harness-engineering.md"
      echo "Bypass: not allowed"
      echo ""
      errors=$((errors + 1))
    fi
  fi
done <<< "$LEGACY_FILES"

# Summary
echo ""
if [ $errors -gt 0 ]; then
  echo "fail: check-alias-integrity ($errors violation(s))"
  exit 1
else
  echo "pass: check-alias-integrity (all legacy docs are aliases only)"
  exit 0
fi
