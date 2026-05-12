#!/usr/bin/env bash
# scripts/harness/worktree-run.sh
# Executes a command inside a worktree sandbox and captures output.
# Usage: worktree-run.sh <task-id> <command...>
#
# Captures stdout/stderr to .harness/runs/<task-id>/ and records exit code.
# Outputs pass/fail/not-run based on command exit code.
#
# Requirements: 5.6

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared library if available
if [[ -f "${SCRIPT_DIR}/_lib.sh" ]]; then
  # shellcheck source=_lib.sh
  source "${SCRIPT_DIR}/_lib.sh"
fi

# --- Output Helpers (inline fallbacks if _lib.sh not present) ---
_pass() {
  if command -v harness_pass &>/dev/null; then
    harness_pass "$1"
  else
    echo "pass: $1"
  fi
}

_fail() {
  if command -v harness_fail &>/dev/null; then
    harness_fail "$1" "$2" "$3" "$4" "$5" "${6:-not allowed}"
  else
    echo "FAIL: $1"
    echo "Reason: $2"
    echo "Evidence: $3"
    echo "Fix: $4"
    echo "Docs: $5"
    echo "Bypass: ${6:-not allowed}"
  fi
}

_notrun() {
  if command -v harness_notrun &>/dev/null; then
    harness_notrun "$1" "$2" "$3" "$4"
  else
    echo "not-run: $1"
    echo "Command: $2"
    echo "Reason: $3"
    echo "Risk: $4"
  fi
}

# --- Argument Validation ---
if [[ $# -lt 2 ]]; then
  _fail "worktree-run" \
    "Missing required arguments" \
    "Received $# argument(s), expected at least 2 (task-id + command)" \
    "Usage: worktree-run.sh <task-id> <command...>" \
    "docs/harness/harness-engineering.md"
  exit 1
fi

TASK_ID="$1"
shift
COMMAND=("$@")

# --- Locate Repository Root ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  _fail "worktree-run" \
    "Not inside a git repository" \
    "git rev-parse --show-toplevel failed" \
    "Run this script from within a git repository" \
    "docs/harness/harness-engineering.md"
  exit 1
}

# --- Validate Worktree Exists ---
WORKTREE_PATH="${REPO_ROOT}/.worktrees/harness-${TASK_ID}"

if [[ ! -d "${WORKTREE_PATH}" ]]; then
  _notrun "worktree-run: worktree not found for task '${TASK_ID}'" \
    "${COMMAND[*]}" \
    "Worktree directory does not exist at ${WORKTREE_PATH}" \
    "Command was not executed; task results are unknown"
  exit 1
fi

# --- Create Output Directory ---
RUNS_DIR="${REPO_ROOT}/.harness/runs/${TASK_ID}"
mkdir -p "${RUNS_DIR}"

# --- Execute Command in Worktree ---
EXIT_CODE=0
(
  cd "${WORKTREE_PATH}" && "${COMMAND[@]}"
) >"${RUNS_DIR}/stdout.log" 2>"${RUNS_DIR}/stderr.log" || EXIT_CODE=$?

# --- Record Exit Code ---
echo "${EXIT_CODE}" > "${RUNS_DIR}/exit-code"

# --- Output Result ---
if [[ ${EXIT_CODE} -eq 0 ]]; then
  _pass "worktree-run: task '${TASK_ID}' command completed successfully (exit 0)"
else
  _fail "worktree-run: task '${TASK_ID}'" \
    "Command exited with non-zero status ${EXIT_CODE}" \
    "Exit code: ${EXIT_CODE} | stderr: ${RUNS_DIR}/stderr.log" \
    "Review ${RUNS_DIR}/stderr.log for error details" \
    "docs/harness/harness-engineering.md"
fi

exit ${EXIT_CODE}
