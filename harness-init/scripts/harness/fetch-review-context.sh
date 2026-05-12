#!/usr/bin/env bash
# fetch-review-context.sh — Fetch MR/PR review context from code host
# Usage: bash scripts/harness/fetch-review-context.sh [--mr <mr-id>] [--branch <branch>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INTEGRATIONS_FILE="$REPO_ROOT/.harness/integrations.yml"

if [ ! -f "$INTEGRATIONS_FILE" ]; then
  echo "not-run: fetch-review-context"
  echo "Reason: .harness/integrations.yml not found"
  echo "Evidence: $INTEGRATIONS_FILE does not exist"
  echo "Fix: Run harness-init to generate .harness/integrations.yml"
  echo "Docs: references/mcp-integrations.md"
  echo "Bypass: not allowed"
  exit 0
fi

if [ -z "${GITLAB_TOKEN:-}" ]; then
  echo "not-run: fetch-review-context"
  echo "Reason: GITLAB_TOKEN environment variable is not set"
  echo "Evidence: \$GITLAB_TOKEN is empty"
  echo "Fix: Set GITLAB_TOKEN environment variable with a valid GitLab API token"
  echo "Docs: docs/integrations/gitlab.md"
  echo "Bypass: not allowed"
  exit 0
fi

GITLAB_BASE_URL="${GITLAB_BASE_URL:-}"
if [ -z "$GITLAB_BASE_URL" ]; then
  echo "not-run: fetch-review-context"
  echo "Reason: GITLAB_BASE_URL is not configured"
  echo "Evidence: Neither GITLAB_BASE_URL env var nor code_host.base_url in integrations.yml is set"
  echo "Fix: Set GITLAB_BASE_URL or configure code_host.base_url in .harness/integrations.yml"
  echo "Docs: docs/integrations/gitlab.md"
  echo "Bypass: not allowed"
  exit 0
fi

# Parse arguments
MR_ID=""
BRANCH=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --mr) MR_ID="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$MR_ID" ] && [ -z "$BRANCH" ]; then
  # Try to detect from current branch
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -z "$BRANCH" ]; then
    echo "fail: fetch-review-context"
    echo "Reason: Cannot determine MR — no --mr or --branch provided and git branch detection failed"
    echo "Evidence: No arguments and git rev-parse failed"
    echo "Fix: Provide --mr <id> or --branch <name>, or run from a git repository"
    echo "Docs: docs/integrations/gitlab.md"
    echo "Bypass: not allowed"
    exit 1
  fi
fi

echo "Fetching review context..."
echo "  Code host: $GITLAB_BASE_URL"
echo "  MR: ${MR_ID:-auto-detect from branch $BRANCH}"

# Placeholder — real impl would call GitLab API
echo "not-run: fetch-review-context"
echo "Reason: GitLab API integration is not yet implemented (stub)"
echo "Evidence: fetch-review-context.sh contains placeholder logic only"
echo "Fix: Implement GitLab MR API calls using curl and GITLAB_TOKEN"
echo "Docs: docs/integrations/gitlab.md"
echo "Bypass: not allowed"
exit 0
