#!/usr/bin/env bash
# link-plan-to-issue.sh — Link ExecPlan to issue tracker issue
# Usage: bash scripts/harness/link-plan-to-issue.sh <plan-path> <issue-id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INTEGRATIONS_FILE="$REPO_ROOT/.harness/integrations.yml"

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/harness/link-plan-to-issue.sh --plan <plan-path> --issue <issue-id>"
  echo "Example: bash scripts/harness/link-plan-to-issue.sh --plan docs/exec-plans/active/feature-x.md --issue PROJ-123"
  exit 1
fi

PLAN_PATH=""
ISSUE_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --plan) PLAN_PATH="$2"; shift 2 ;;
    --issue) ISSUE_ID="$2"; shift 2 ;;
    *)
      # Support legacy positional args: <plan-path> <issue-id>
      if [ -z "$PLAN_PATH" ]; then
        PLAN_PATH="$1"; shift
      elif [ -z "$ISSUE_ID" ]; then
        ISSUE_ID="$1"; shift
      else
        echo "Unknown argument: $1"; exit 1
      fi
      ;;
  esac
done

if [ -z "$PLAN_PATH" ] || [ -z "$ISSUE_ID" ]; then
  echo "Usage: bash scripts/harness/link-plan-to-issue.sh --plan <plan-path> --issue <issue-id>"
  exit 1
fi

# Check integrations config
if [ ! -f "$INTEGRATIONS_FILE" ]; then
  echo "not-run: link-plan-to-issue"
  echo "Reason: .harness/integrations.yml not found"
  echo "Evidence: $INTEGRATIONS_FILE does not exist"
  echo "Fix: Run harness-init to generate .harness/integrations.yml"
  echo "Docs: references/mcp-integrations.md"
  echo "Bypass: not allowed"
  exit 0
fi

# Check token
if [ -z "${YOUTRACK_TOKEN:-}" ]; then
  echo "not-run: link-plan-to-issue"
  echo "Reason: YOUTRACK_TOKEN environment variable is not set"
  echo "Evidence: \$YOUTRACK_TOKEN is empty"
  echo "Fix: Set YOUTRACK_TOKEN environment variable"
  echo "Docs: docs/integrations/youtrack.md"
  echo "Bypass: not allowed"
  exit 0
fi

# Check plan file exists
if [ ! -f "$REPO_ROOT/$PLAN_PATH" ]; then
  echo "fail: link-plan-to-issue"
  echo "Reason: Plan file not found"
  echo "Evidence: $PLAN_PATH does not exist"
  echo "Fix: Create the plan file first, or check the path"
  echo "Docs: references/exec-plan-templates.md"
  echo "Bypass: not allowed"
  exit 1
fi

YOUTRACK_BASE_URL="${YOUTRACK_BASE_URL:-}"
if [ -z "$YOUTRACK_BASE_URL" ]; then
  echo "not-run: link-plan-to-issue"
  echo "Reason: YOUTRACK_BASE_URL is not configured"
  echo "Evidence: Neither YOUTRACK_BASE_URL env var nor issue_tracker.base_url in integrations.yml is set"
  echo "Fix: Set YOUTRACK_BASE_URL or configure issue_tracker.base_url in .harness/integrations.yml"
  echo "Docs: docs/integrations/youtrack.md"
  echo "Bypass: not allowed"
  exit 0
fi

echo "Linking plan to issue..."
echo "  Plan: $PLAN_PATH"
echo "  Issue: $ISSUE_ID"
echo "  Tracker: $YOUTRACK_BASE_URL"

# Placeholder — real impl would call YouTrack API for bidirectional link
echo "not-run: link-plan-to-issue"
echo "Reason: YouTrack API bidirectional linking is not yet implemented (stub)"
echo "Evidence: link-plan-to-issue.sh contains placeholder logic only"
echo "Fix: Implement YouTrack REST API calls to create issue links"
echo "Docs: docs/integrations/youtrack.md"
echo "Bypass: not allowed"
exit 0
