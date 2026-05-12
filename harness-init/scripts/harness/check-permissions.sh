#!/usr/bin/env bash
# check-permissions.sh — Verify permission boundaries and approval policies
# Usage: bash scripts/harness/check-permissions.sh
#
# Checks:
# 1. Dangerous operations in .harness/integrations.yml have approval policies
# 2. Production deploy requires human approval
# 3. Data migration requires ExecPlan + approval
# 4. MCP dangerous operations are properly gated
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INTEGRATIONS_FILE="$REPO_ROOT/.harness/integrations.yml"

errors=0
warnings=0

emit_fail() {
  local gate="$1" reason="$2" evidence="$3" fix="$4" docs="$5"
  echo "FAIL: $gate"
  echo "Reason: $reason"
  echo "Evidence: $evidence"
  echo "Fix: $fix"
  echo "Docs: $docs"
  echo "Bypass: not allowed"
  echo ""
  errors=$((errors + 1))
}

emit_warn() {
  local gate="$1" reason="$2" evidence="$3" fix="$4" docs="$5"
  echo "warn: $gate"
  echo "Reason: $reason"
  echo "Evidence: $evidence"
  echo "Fix: $fix"
  echo "Docs: $docs"
  echo ""
  warnings=$((warnings + 1))
}

# --- Check integrations.yml exists ---
echo "── Check: Integrations configuration ──"
if [ ! -f "$INTEGRATIONS_FILE" ]; then
  echo "not-run: check-permissions"
  echo "Reason: .harness/integrations.yml not found"
  echo "Evidence: $INTEGRATIONS_FILE does not exist"
  echo "Fix: Run harness-init to generate .harness/integrations.yml"
  echo "Docs: references/permission-boundaries.md"
  echo "Bypass: not allowed"
  exit 0
fi
echo "pass: integrations.yml exists"

# --- Check: MCP dangerous operations have approval_required_for ---
echo ""
echo "── Check: MCP dangerous operations approval policy ──"
DANGEROUS_OPS=("delete" "force-push" "production-deploy" "permission-change" "database-migration" "secret-rotation")

if grep -q "mcp:" "$INTEGRATIONS_FILE" 2>/dev/null; then
  if grep -q "approval_required_for" "$INTEGRATIONS_FILE" 2>/dev/null; then
    # Check each dangerous operation is listed
    for op in "${DANGEROUS_OPS[@]}"; do
      if grep -q "$op" "$INTEGRATIONS_FILE" 2>/dev/null; then
        echo "pass: dangerous operation '$op' has approval policy"
      else
        emit_warn "check-permissions:mcp-approval" \
          "Dangerous operation '$op' not listed in approval_required_for" \
          "$INTEGRATIONS_FILE" \
          "Add '$op' to mcp.servers.*.approval_required_for list" \
          "references/permission-boundaries.md"
      fi
    done
  else
    emit_fail "check-permissions:mcp-no-approval" \
      "MCP section exists but no approval_required_for policy defined" \
      "$INTEGRATIONS_FILE" \
      "Add approval_required_for list with dangerous operations: ${DANGEROUS_OPS[*]}" \
      "references/permission-boundaries.md"
  fi
else
  echo "pass: MCP not configured (no dangerous operations to gate)"
fi

# --- Check: Production deploy requires approval ---
echo ""
echo "── Check: Production deploy approval ──"
if grep -q "production-deploy" "$INTEGRATIONS_FILE" 2>/dev/null; then
  echo "pass: production-deploy listed in approval policy"
else
  emit_warn "check-permissions:production-deploy" \
    "production-deploy not explicitly listed in approval policies" \
    "$INTEGRATIONS_FILE" \
    "Ensure production-deploy is in approval_required_for list" \
    "references/permission-boundaries.md"
fi

# --- Check: Database migration requires approval ---
echo ""
echo "── Check: Database migration approval ──"
if grep -q "database-migration" "$INTEGRATIONS_FILE" 2>/dev/null; then
  echo "pass: database-migration listed in approval policy"
else
  emit_warn "check-permissions:database-migration" \
    "database-migration not explicitly listed in approval policies" \
    "$INTEGRATIONS_FILE" \
    "Ensure database-migration is in approval_required_for list" \
    "references/permission-boundaries.md"
fi

# --- Summary ---
echo ""
echo "── Summary ──"
if [ $errors -gt 0 ]; then
  echo "fail: check-permissions ($errors issue(s) found, $warnings warning(s))"
  exit 1
elif [ $warnings -gt 0 ]; then
  echo "warn: check-permissions ($warnings warning(s))"
  exit 0
else
  echo "pass: check-permissions (all checks passed)"
  exit 0
fi
