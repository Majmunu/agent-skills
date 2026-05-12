#!/usr/bin/env bash
# scripts/harness/worktree-create.sh
# Creates an isolated git worktree for a harness task.
#
# Usage: worktree-create.sh <task-id> <branch>
#
# Creates a worktree at .worktrees/harness-<task-id> for the given branch.
# If the branch does not exist, it will be created from the current HEAD.
#
# Requirements: 5.1, 5.2, 5.7

set -euo pipefail

# --- Output Helpers (inline until _lib.sh is available) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/_lib.sh" ]]; then
  # shellcheck source=_lib.sh
  source "${SCRIPT_DIR}/_lib.sh"
else
  harness_pass()   { echo "pass: $1"; }
  harness_fail()   { echo "FAIL: $1"; echo "Reason: ${2:-}"; echo "Evidence: ${3:-}"; echo "Fix: ${4:-}"; echo "Docs: ${5:-}"; echo "Bypass: ${6:-not allowed}"; }
  harness_warn()   { echo "warn: $1"; }
  harness_notrun() { echo "not-run: $1"; echo "Command: ${2:-}"; echo "Reason: ${3:-}"; echo "Risk: ${4:-}"; }
fi

# --- Argument Validation ---
TASK_ID="${1:-}"
BRANCH="${2:-}"

if [[ -z "$TASK_ID" || -z "$BRANCH" ]]; then
  harness_fail "worktree-create" \
    "Missing required arguments" \
    "task-id='${TASK_ID}' branch='${BRANCH}'" \
    "Usage: worktree-create.sh <task-id> <branch>" \
    "docs/harness/harness-engineering.md"
  exit 1
fi

# --- Path Construction ---
WORKTREE_PATH=".worktrees/harness-${TASK_ID}"

# --- Safety Check: Ensure path is under .worktrees/ ---
# Requirement 5.7: Refuse any operation that would delete main workspace content
case "$WORKTREE_PATH" in
  .worktrees/harness-*)
    # Valid path pattern — continues
    ;;
  *)
    harness_fail "worktree-create" \
      "Path safety violation: worktree path must be under .worktrees/harness-*" \
      "Requested path: ${WORKTREE_PATH}" \
      "Only paths matching .worktrees/harness-<task-id> are allowed" \
      "docs/harness/harness-engineering.md"
    exit 1
    ;;
esac

# Additional safety: resolve and verify the path does not escape .worktrees/
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RESOLVED_PATH="${REPO_ROOT}/${WORKTREE_PATH}"

# Ensure resolved path is still under repo_root/.worktrees/
if [[ "$RESOLVED_PATH" != "${REPO_ROOT}/.worktrees/"* ]]; then
  harness_fail "worktree-create" \
    "Path safety violation: resolved path escapes .worktrees/ directory" \
    "Resolved: ${RESOLVED_PATH}" \
    "Ensure task-id does not contain path traversal characters (e.g., ../)" \
    "docs/harness/harness-engineering.md"
  exit 1
fi

# --- Check if git is available ---
if ! command -v git >/dev/null 2>&1; then
  harness_notrun "worktree-create" \
    "git worktree add \"${WORKTREE_PATH}\" -b \"${BRANCH}\"" \
    "git command not found" \
    "Worktree cannot be created without git; task isolation unavailable"
  exit 1
fi

# --- Check if we are in a git repository ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  harness_fail "worktree-create" \
    "Not inside a git repository" \
    "$(pwd)" \
    "Run this script from within a git repository" \
    "docs/harness/harness-engineering.md"
  exit 1
fi

# --- Requirement 5.2: Warn if path already exists ---
if [[ -d "$WORKTREE_PATH" ]]; then
  harness_warn "Worktree path already exists: ${WORKTREE_PATH}"
  echo "  To clean up and recreate, run:"
  echo "    scripts/harness/worktree-clean.sh --force"
  echo "    scripts/harness/worktree-create.sh ${TASK_ID} ${BRANCH}"
  echo ""
  echo "  Or remove manually:"
  echo "    git worktree remove ${WORKTREE_PATH} --force"
  exit 0
fi

# --- Create .worktrees directory if needed ---
mkdir -p "$(dirname "$WORKTREE_PATH")"

# --- Create the worktree ---
# Try to create with a new branch first; if branch already exists, attach to it
if git show-ref --verify --quiet "refs/heads/${BRANCH}" 2>/dev/null; then
  # Branch exists — create worktree attached to existing branch
  if git worktree add "$WORKTREE_PATH" "$BRANCH" 2>/dev/null; then
    harness_pass "worktree-create: created at ${WORKTREE_PATH} (existing branch: ${BRANCH})"
    echo "  Task ID:  ${TASK_ID}"
    echo "  Branch:   ${BRANCH}"
    echo "  Path:     ${WORKTREE_PATH}"
    exit 0
  else
    harness_fail "worktree-create" \
      "git worktree add failed for existing branch" \
      "branch=${BRANCH} path=${WORKTREE_PATH}" \
      "Check if the branch is already checked out in another worktree" \
      "docs/harness/harness-engineering.md"
    exit 1
  fi
else
  # Branch does not exist — create new branch from current HEAD
  if git worktree add "$WORKTREE_PATH" -b "$BRANCH" 2>/dev/null; then
    harness_pass "worktree-create: created at ${WORKTREE_PATH} (new branch: ${BRANCH})"
    echo "  Task ID:  ${TASK_ID}"
    echo "  Branch:   ${BRANCH}"
    echo "  Path:     ${WORKTREE_PATH}"
    exit 0
  else
    harness_fail "worktree-create" \
      "git worktree add failed when creating new branch" \
      "branch=${BRANCH} path=${WORKTREE_PATH}" \
      "Verify git status is clean and branch name is valid" \
      "docs/harness/harness-engineering.md"
    exit 1
  fi
fi
