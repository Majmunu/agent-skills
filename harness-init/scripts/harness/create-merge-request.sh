#!/usr/bin/env bash
# create-merge-request.sh — Create merge request with plan link and standard description
# Usage: bash scripts/harness/create-merge-request.sh --title <title> [--plan <plan-path>] [--target <branch>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INTEGRATIONS_FILE="$REPO_ROOT/.harness/integrations.yml"

if [ ! -f "$INTEGRATIONS_FILE" ]; then
  echo "not-run: create-merge-request"
  echo "Reason: .harness/integrations.yml not found"
  echo "Evidence: $INTEGRATIONS_FILE does not exist"
  echo "Fix: Run harness-init to generate .harness/integrations.yml"
  echo "Docs: references/mcp-integrations.md"
  echo "Bypass: not allowed"
  exit 0
fi

if [ -z "${GITLAB_TOKEN:-}" ]; then
  echo "not-run: create-merge-request"
  echo "Reason: GITLAB_TOKEN environment variable is not set"
  echo "Evidence: \$GITLAB_TOKEN is empty"
  echo "Fix: Set GITLAB_TOKEN environment variable with a valid GitLab API token"
  echo "Docs: docs/integrations/gitlab.md"
  echo "Bypass: not allowed"
  exit 0
fi

GITLAB_BASE_URL="${GITLAB_BASE_URL:-}"
if [ -z "$GITLAB_BASE_URL" ]; then
  echo "not-run: create-merge-request"
  echo "Reason: GITLAB_BASE_URL or GitLab base_url is not configured."
  echo "Evidence: Neither GITLAB_BASE_URL env var nor code_host.base_url in integrations.yml is set"
  echo "Fix: Set GITLAB_BASE_URL or configure code_host.base_url in .harness/integrations.yml"
  echo "Docs: docs/integrations/gitlab.md"
  echo "Bypass: not allowed"
  exit 0
fi

# Parse arguments
TITLE=""
PLAN_PATH=""
TARGET_BRANCH="main"
while [[ $# -gt 0 ]]; do
  case $1 in
    --title) TITLE="$2"; shift 2 ;;
    --plan) PLAN_PATH="$2"; shift 2 ;;
    --target) TARGET_BRANCH="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$TITLE" ]; then
  echo "fail: create-merge-request"
  echo "Reason: --title is required"
  echo "Evidence: No --title argument provided"
  echo "Fix: Provide --title \"Your MR title\""
  echo "Docs: docs/integrations/gitlab.md"
  echo "Bypass: not allowed"
  exit 1
fi

SOURCE_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ -z "$SOURCE_BRANCH" ]; then
  echo "fail: create-merge-request"
  echo "Reason: Cannot determine source branch"
  echo "Evidence: git rev-parse --abbrev-ref HEAD failed"
  echo "Fix: Run from a git repository with a checked-out branch"
  echo "Docs: docs/integrations/gitlab.md"
  echo "Bypass: not allowed"
  exit 1
fi

# Build MR description with plan link
MR_DESCRIPTION="## Summary\n\n$TITLE\n"
if [ -n "$PLAN_PATH" ]; then
  MR_DESCRIPTION="$MR_DESCRIPTION\n## Execution Plan\n\n- Plan: \`$PLAN_PATH\`\n"
fi
MR_DESCRIPTION="$MR_DESCRIPTION\n## Checklist\n\n- [ ] Tests pass\n- [ ] Docs updated\n- [ ] Plan status updated\n"

echo "Creating merge request..."
echo "  Title: $TITLE"
echo "  Source: $SOURCE_BRANCH"
echo "  Target: $TARGET_BRANCH"
echo "  Plan: ${PLAN_PATH:-none}"
echo "  Code host: $GITLAB_BASE_URL"

# Placeholder — real impl would call GitLab API
echo "not-run: create-merge-request"
echo "Reason: GitLab API integration is not yet implemented (stub)"
echo "Evidence: create-merge-request.sh contains placeholder logic only"
echo "Fix: Implement GitLab MR creation API calls using curl and GITLAB_TOKEN"
echo "Docs: docs/integrations/gitlab.md"
echo "Bypass: not allowed"
exit 0
