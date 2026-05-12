#!/usr/bin/env bash
# worktree-clean.sh — Clean up harness worktree sandboxes
# Requirements: 5.3, 5.4, 5.5
#
# Usage:
#   worktree-clean.sh <task-id>       Clean specific worktree for task
#   worktree-clean.sh --all           Clean all harness-* worktrees
#   worktree-clean.sh --force <...>   Force cleanup even with uncommitted changes
#
# Safety:
#   - Only cleans .worktrees/harness-* paths
#   - Refuses cleanup if uncommitted changes exist (unless --force)
#   - Refuses execution if target path is outside .worktrees/

set -euo pipefail

# --- Configuration ---
WORKTREES_DIR=".worktrees"
HARNESS_PREFIX="harness-"

# --- Output Formatting ---
_pass()   { echo "pass: $1"; }
_fail()   { echo "FAIL: $1"; echo "Reason: $2"; echo "Evidence: $3"; echo "Fix: $4"; echo "Docs: $5"; }
_warn()   { echo "warn: $1"; }

# --- Argument Parsing ---
FORCE=false
ALL=false
TASK_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    --all)
      ALL=true
      shift
      ;;
    -*)
      _fail "Unknown option: $1" \
        "Unrecognized flag passed to worktree-clean.sh" \
        "Received: $1" \
        "Use --force to override uncommitted changes check, or --all to clean all harness worktrees" \
        "docs/harness/harness-engineering.md"
      exit 1
      ;;
    *)
      TASK_ID="$1"
      shift
      ;;
  esac
done

# --- Validation: Must specify --all or task-id ---
if [[ "$ALL" == "false" && -z "$TASK_ID" ]]; then
  _fail "No target specified" \
    "worktree-clean.sh requires either a <task-id> argument or --all flag" \
    "Arguments received: (none)" \
    "Usage: worktree-clean.sh <task-id> or worktree-clean.sh --all" \
    "docs/harness/harness-engineering.md"
  exit 1
fi

# --- Locate repo root ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  _fail "Not in a git repository" \
    "worktree-clean.sh must be run from within a git repository" \
    "git rev-parse --show-toplevel failed" \
    "Navigate to a git repository before running this script" \
    "docs/harness/harness-engineering.md"
  exit 1
}

WORKTREES_PATH="${REPO_ROOT}/${WORKTREES_DIR}"

# --- Path Safety: Assert target is under .worktrees/ ---
assert_in_worktrees() {
  local target_path="$1"
  local resolved_target resolved_worktrees

  # Resolve to absolute paths for comparison
  resolved_target="$(cd "$target_path" 2>/dev/null && pwd)" || resolved_target="$target_path"
  resolved_worktrees="$(cd "$WORKTREES_PATH" 2>/dev/null && pwd)" || resolved_worktrees="$WORKTREES_PATH"

  case "$resolved_target" in
    "${resolved_worktrees}"/*)
      return 0
      ;;
    *)
      _fail "Path outside .worktrees/" \
        "Target path is not under the .worktrees/ directory — refusing execution for safety" \
        "Target: $target_path (resolved: $resolved_target)" \
        "Only paths under ${WORKTREES_DIR}/ can be cleaned. Verify the task-id is correct." \
        "docs/harness/harness-engineering.md"
      exit 1
      ;;
  esac
}

# --- Assert path matches harness-* pattern ---
assert_harness_prefix() {
  local dir_name="$1"
  if [[ "$dir_name" != ${HARNESS_PREFIX}* ]]; then
    _fail "Not a harness worktree" \
      "Target directory does not match the harness-* naming pattern" \
      "Directory name: $dir_name (expected prefix: ${HARNESS_PREFIX})" \
      "Only worktrees created by worktree-create.sh (named harness-<task-id>) can be cleaned" \
      "docs/harness/harness-engineering.md"
    exit 1
  fi
}

# --- Check for uncommitted changes in a worktree ---
has_uncommitted_changes() {
  local worktree_path="$1"
  # Check if there are any uncommitted changes (staged or unstaged)
  if git -C "$worktree_path" status --porcelain 2>/dev/null | grep -q .; then
    return 0  # has changes
  fi
  return 1  # clean
}

# --- Remove a single worktree ---
remove_worktree() {
  local worktree_path="$1"
  local dir_name
  dir_name="$(basename "$worktree_path")"

  # Validate harness prefix
  assert_harness_prefix "$dir_name"

  # Validate path is under .worktrees/
  assert_in_worktrees "$worktree_path"

  # Check if path exists
  if [[ ! -d "$worktree_path" ]]; then
    _warn "Worktree path does not exist: $worktree_path"
    return 0
  fi

  # Check for uncommitted changes
  if has_uncommitted_changes "$worktree_path"; then
    if [[ "$FORCE" == "true" ]]; then
      _warn "Forcing cleanup despite uncommitted changes in: $worktree_path"
      git worktree remove --force "$worktree_path" 2>/dev/null || {
        # Fallback: if git worktree remove fails, try with absolute path
        git worktree remove --force "$(cd "$worktree_path" && pwd)" 2>/dev/null || {
          _fail "Failed to force-remove worktree" \
            "git worktree remove --force failed" \
            "Path: $worktree_path" \
            "Manually remove the directory and run 'git worktree prune'" \
            "docs/harness/harness-engineering.md"
          return 1
        }
      }
    else
      _fail "Uncommitted changes in worktree" \
        "Worktree has uncommitted changes — refusing cleanup to prevent data loss" \
        "Path: $worktree_path" \
        "Commit or stash changes first, or use --force to override" \
        "docs/harness/harness-engineering.md"
      return 1
    fi
  else
    git worktree remove "$worktree_path" 2>/dev/null || {
      git worktree remove --force "$worktree_path" 2>/dev/null || {
        _fail "Failed to remove worktree" \
          "git worktree remove failed" \
          "Path: $worktree_path" \
          "Manually remove the directory and run 'git worktree prune'" \
          "docs/harness/harness-engineering.md"
        return 1
      }
    }
  fi

  _pass "Removed worktree: $worktree_path"
  return 0
}

# --- Main Logic ---
ERRORS=0

if [[ "$ALL" == "true" ]]; then
  # Clean all harness-* worktrees
  if [[ ! -d "$WORKTREES_PATH" ]]; then
    _pass "No .worktrees/ directory found — nothing to clean"
    exit 0
  fi

  found=0
  for dir in "${WORKTREES_PATH}/${HARNESS_PREFIX}"*; do
    [[ -d "$dir" ]] || continue
    found=1
    remove_worktree "$dir" || ERRORS=$((ERRORS + 1))
  done

  if [[ $found -eq 0 ]]; then
    _pass "No harness-* worktrees found — nothing to clean"
    exit 0
  fi
else
  # Clean specific task worktree
  TARGET="${WORKTREES_PATH}/${HARNESS_PREFIX}${TASK_ID}"
  remove_worktree "$TARGET" || ERRORS=$((ERRORS + 1))
fi

# --- Final Status ---
if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi

exit 0
