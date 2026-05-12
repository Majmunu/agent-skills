#!/usr/bin/env bash
# check-plan-required.sh — Verify cross-module PRs link to an ExecPlan
# Usage: bash scripts/harness/check-plan-required.sh
#
# Reads .harness/plan-required-rules.yml for configuration.
# Requires PR context: GITHUB_EVENT_NAME and PR_BODY_FILE (or .harness/pr-body.txt)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

# --- Skip if not a PR event ---
EVENT_NAME="${GITHUB_EVENT_NAME:-${CI_PIPELINE_SOURCE:-push}}"
if [ "$EVENT_NAME" != "pull_request" ] && [ "$EVENT_NAME" != "merge_request_event" ]; then
  echo "pass: check-plan-required (skipped — not a PR/MR event, event=$EVENT_NAME)"
  exit 0
fi

# --- Read PR body ---
PR_BODY_FILE="${PR_BODY_FILE:-.harness/pr-body.txt}"
if [ ! -f "$PR_BODY_FILE" ]; then
  echo "warn: check-plan-required"
  echo "Reason: PR body file not found"
  echo "Evidence: $PR_BODY_FILE does not exist"
  echo "Fix: Ensure CI writes PR body to .harness/pr-body.txt before running this gate"
  echo "Docs: references/exec-plan-templates.md"
  echo "Bypass: not allowed"
  exit 0
fi

PR_BODY=$(cat "$PR_BODY_FILE" 2>/dev/null || true)

# --- Check for plan link in PR body ---
# Accept plan paths like:
#   docs/exec-plans/active/<name>.md
#   apps/<name>/docs/exec-plans/active/<name>.md
#   services/<name>/docs/exec-plans/active/<name>.md
PLAN_PATTERN='docs/exec-plans/(active|completed)/[a-zA-Z0-9_\-]+\.md'

PLAN_LINK=$(echo "$PR_BODY" | grep -oE "$PLAN_PATTERN" | head -1 || true)

if [ -z "$PLAN_LINK" ]; then
  echo "FAIL: check-plan-required"
  echo "Reason: PR/MR does not link to an ExecPlan"
  echo "Evidence: No plan path matching '$PLAN_PATTERN' found in PR body ($PR_BODY_FILE)"
  echo "Fix: Add a link to an active or completed plan in the PR description, e.g.: docs/exec-plans/active/my-feature.md"
  echo "Docs: references/exec-plan-templates.md"
  echo "Bypass: docs/decisions/ADR-exceptions/ (must include owner, expires_on, scope)"
  exit 1
fi

# --- Verify plan file exists ---
if [ ! -f "$PLAN_LINK" ]; then
  echo "FAIL: check-plan-required"
  echo "Reason: Linked plan file does not exist"
  echo "Evidence: $PLAN_LINK not found on disk"
  echo "Fix: Create the plan file at $PLAN_LINK, or fix the path in the PR description"
  echo "Docs: references/exec-plan-templates.md"
  echo "Bypass: not allowed"
  exit 1
fi

# --- Verify plan has Status field ---
if ! head -60 "$PLAN_LINK" | grep -qi "^Status:" 2>/dev/null; then
  echo "warn: check-plan-required"
  echo "Reason: Plan file missing 'Status:' field in first 60 lines"
  echo "Evidence: $PLAN_LINK"
  echo "Fix: Add 'Status: active' or 'Status: completed' to the plan file header"
  echo "Docs: references/exec-plan-templates.md"
  echo "Bypass: not allowed"
  exit 0
fi

# --- Verify plan status is acceptable ---
PLAN_STATUS=$(head -60 "$PLAN_LINK" | grep -i "^Status:" | head -1 | sed 's/^Status:[[:space:]]*//' | tr '[:upper:]' '[:lower:]')
case "$PLAN_STATUS" in
  active|completed)
    echo "pass: check-plan-required (plan=$PLAN_LINK, status=$PLAN_STATUS)"
    exit 0
    ;;
  blocked|superseded)
    echo "FAIL: check-plan-required"
    echo "Reason: Linked plan has non-mergeable status: $PLAN_STATUS"
    echo "Evidence: $PLAN_LINK (Status: $PLAN_STATUS)"
    echo "Fix: Only 'active' or 'completed' plans authorize merge. Update plan status or link a different plan."
    echo "Docs: references/exec-plan-templates.md"
    echo "Bypass: not allowed"
    exit 1
    ;;
  *)
    echo "warn: check-plan-required"
    echo "Reason: Unrecognized plan status: $PLAN_STATUS"
    echo "Evidence: $PLAN_LINK"
    echo "Fix: Use one of: active, completed, blocked, superseded"
    echo "Docs: references/exec-plan-templates.md"
    echo "Bypass: not allowed"
    exit 0
    ;;
esac
