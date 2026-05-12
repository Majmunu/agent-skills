#!/usr/bin/env bash
# sync-issues.sh — Sync issue status from issue tracker to local plan files
# Usage: bash scripts/harness/sync-issues.sh [--project <key>] [--status <status>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INTEGRATIONS_FILE="$REPO_ROOT/.harness/integrations.yml"

# Check integrations config exists
if [ ! -f "$INTEGRATIONS_FILE" ]; then
  echo "not-run: sync-issues"
  echo "Reason: .harness/integrations.yml not found"
  echo "Evidence: $INTEGRATIONS_FILE does not exist"
  echo "Fix: Run harness-init to generate .harness/integrations.yml"
  echo "Docs: references/mcp-integrations.md"
  echo "Bypass: not allowed"
  exit 0
fi

# Check YouTrack token
if [ -z "${YOUTRACK_TOKEN:-}" ]; then
  echo "not-run: sync-issues"
  echo "Reason: YOUTRACK_TOKEN environment variable is not set"
  echo "Evidence: \$YOUTRACK_TOKEN is empty"
  echo "Fix: Set YOUTRACK_TOKEN environment variable with a valid YouTrack API token"
  echo "Docs: docs/integrations/youtrack.md"
  echo "Bypass: not allowed"
  exit 0
fi

# Parse arguments
PROJECT_KEY=""
STATUS_FILTER=""
SINCE_FILTER=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT_KEY="$2"; shift 2 ;;
    --status) STATUS_FILTER="$2"; shift 2 ;;
    --since) SINCE_FILTER="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# Read base_url from integrations.yml (simplified — real impl would use yq/python)
YOUTRACK_BASE_URL="${YOUTRACK_BASE_URL:-}"
if [ -z "$YOUTRACK_BASE_URL" ]; then
  echo "not-run: sync-issues"
  echo "Reason: YOUTRACK_BASE_URL is not configured"
  echo "Evidence: Neither YOUTRACK_BASE_URL env var nor issue_tracker.base_url in integrations.yml is set"
  echo "Fix: Set YOUTRACK_BASE_URL or configure issue_tracker.base_url in .harness/integrations.yml"
  echo "Docs: docs/integrations/youtrack.md"
  echo "Bypass: not allowed"
  exit 0
fi

echo "Syncing issues from YouTrack..."
echo "  Base URL: $YOUTRACK_BASE_URL"
echo "  Project: ${PROJECT_KEY:-all}"
echo "  Status filter: ${STATUS_FILTER:-all}"
echo "  Since: ${SINCE_FILTER:-all}"

# Sync logic placeholder — real implementation would call YouTrack API
# and update local docs/exec-plans/ files
PLANS_DIR="$REPO_ROOT/docs/exec-plans/active"
if [ ! -d "$PLANS_DIR" ]; then
  echo "warn: sync-issues"
  echo "Reason: docs/exec-plans/active/ directory not found"
  echo "Evidence: $PLANS_DIR does not exist"
  echo "Fix: Run harness-init to create docs scaffold"
  echo "Docs: references/exec-plan-templates.md"
  echo "Bypass: not allowed"
  exit 0
fi

echo "not-run: sync-issues"
echo "Reason: YouTrack API integration is not yet implemented (stub)"
echo "Evidence: sync-issues.sh contains placeholder logic only"
echo "Fix: Implement YouTrack REST API calls using curl and YOUTRACK_TOKEN"
echo "Docs: docs/integrations/youtrack.md"
echo "Bypass: not allowed"
exit 0
