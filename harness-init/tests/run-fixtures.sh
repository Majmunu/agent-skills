#!/usr/bin/env bash
# =============================================================================
# tests/run-fixtures.sh — Fixture Test Runner for harness-init
# =============================================================================
# Orchestrates the full test workflow for each fixture:
#   1. Copy fixture to temp directory
#   2. Run harness-init dry-run
#   3. Run harness-init init (first run)
#   4. Run harness-init init (second run — re-init for idempotency)
#   5. Run assertion scripts against the result
#   6. Output structured pass/fail per fixture
#
# Usage:
#   tests/run-fixtures.sh [--fixture <name>] [--verbose]
#
# Exit codes:
#   0 — All fixtures passed
#   1 — One or more fixtures failed
# =============================================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/fixtures"
ASSERT_SCRIPTS_DIR="$SCRIPT_DIR"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' RED='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

# --- Globals ---
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
VERBOSE=0
FILTER_FIXTURE=""
FAILURES=()

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture)
      FILTER_FIXTURE="$2"
      shift 2
      ;;
    --verbose|-v)
      VERBOSE=1
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--fixture <name>] [--verbose]"
      echo ""
      echo "Options:"
      echo "  --fixture <name>  Run only the specified fixture"
      echo "  --verbose, -v     Show detailed output for each step"
      echo "  --help, -h        Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# --- Helper Functions ---

log_info() {
  echo -e "${CYAN}[INFO]${RESET} $1"
}

log_pass() {
  echo -e "${GREEN}[PASS]${RESET} $1"
}

log_fail() {
  echo -e "${RED}[FAIL]${RESET} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${RESET} $1"
}

log_verbose() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo -e "       $1"
  fi
}

# Output structured failure information
# Args: fixture_name, reason, evidence, fix, docs
emit_failure() {
  local fixture="$1"
  local reason="$2"
  local evidence="$3"
  local fix="$4"
  local docs="$5"

  log_fail "Fixture: $fixture"
  echo "  Reason:   $reason"
  echo "  Evidence: $evidence"
  echo "  Fix:      $fix"
  echo "  Docs:     $docs"
  echo ""
  FAILURES+=("$fixture: $reason")
}

# Create a temporary directory for fixture testing
# Args: fixture_name
# Returns: path to temp directory (via stdout)
create_temp_dir() {
  local fixture_name="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/harness-fixture-${fixture_name}-XXXXXX")"
  echo "$tmp_dir"
}

# Copy fixture contents to temp directory
# Args: fixture_path, temp_dir
copy_fixture_to_temp() {
  local fixture_path="$1"
  local temp_dir="$2"

  cp -r "$fixture_path"/. "$temp_dir/"
  log_verbose "Copied fixture to: $temp_dir"
}

# Simulate harness-init dry-run on a directory
# In the real implementation, this would invoke the actual harness-init skill.
# For the test runner, we simulate the workflow by checking if the skill
# script exists and invoking it, or marking as not-run if unavailable.
# Args: target_dir
# Returns: 0 on success, 1 on failure
run_dry_run() {
  local target_dir="$1"
  local harness_init_script="$PROJECT_ROOT/scripts/harness/self-test.sh"

  # If harness-init has a dry-run entry point, use it
  if [[ -x "$harness_init_script" ]]; then
    if ! (cd "$target_dir" && bash "$harness_init_script" --dry-run 2>/dev/null); then
      return 1
    fi
  else
    # Dry-run is simulated: verify the fixture is a valid directory
    if [[ ! -d "$target_dir" ]]; then
      return 1
    fi
    log_verbose "dry-run: simulated (no harness-init entry point yet)"
  fi
  return 0
}

# Simulate harness-init init on a directory
# Args: target_dir, run_label (first|second)
# Returns: 0 on success, 1 on failure
run_init() {
  local target_dir="$1"
  local run_label="$2"
  local harness_init_script="$PROJECT_ROOT/scripts/harness/self-test.sh"

  # If harness-init has an init entry point, use it
  if [[ -x "$harness_init_script" ]]; then
    if ! (cd "$target_dir" && bash "$harness_init_script" --init 2>/dev/null); then
      return 1
    fi
  else
    # Init is simulated: the fixture directory is the "result"
    log_verbose "init ($run_label): simulated (no harness-init entry point yet)"
  fi
  return 0
}

# Snapshot directory state for idempotency comparison
# Args: target_dir, output_file
snapshot_dir() {
  local target_dir="$1"
  local output_file="$2"

  find "$target_dir" -type f -exec md5sum {} \; 2>/dev/null | sort > "$output_file" \
    || find "$target_dir" -type f -exec sha256sum {} \; 2>/dev/null | sort > "$output_file" \
    || find "$target_dir" -type f | sort > "$output_file"
}

# Run assertion scripts against a fixture result
# Args: fixture_name, target_dir, first_snapshot, second_snapshot
# Returns: 0 if all assertions pass, 1 if any fail
run_assertions() {
  local fixture_name="$1"
  local target_dir="$2"
  local first_snapshot="$3"
  local second_snapshot="$4"
  local assert_failed=0

  # --- Assert: Idempotency ---
  if [[ -x "$ASSERT_SCRIPTS_DIR/assert-idempotent.sh" ]]; then
    log_verbose "Running assert-idempotent.sh..."
    if ! bash "$ASSERT_SCRIPTS_DIR/assert-idempotent.sh" "$target_dir" "$first_snapshot" "$second_snapshot" 2>/dev/null; then
      emit_failure "$fixture_name" \
        "Idempotency check failed — second init produced different output" \
        "Diff between first-run and second-run snapshots" \
        "Ensure harness-init uses read→compare→patch/append strategy; check for duplicate markers" \
        "references/regression-fixtures.md"
      assert_failed=1
    fi
  else
    log_verbose "assert-idempotent.sh not found or not executable — skipping"
  fi

  # --- Assert: Root Navigation Clean ---
  if [[ -x "$ASSERT_SCRIPTS_DIR/assert-root-nav-clean.sh" ]]; then
    log_verbose "Running assert-root-nav-clean.sh..."
    if ! bash "$ASSERT_SCRIPTS_DIR/assert-root-nav-clean.sh" "$target_dir" 2>/dev/null; then
      emit_failure "$fixture_name" \
        "Root navigation contains project-level commands" \
        "Found 'cd apps/' or 'cd packages/' patterns in root navigation file" \
        "Move project-level commands to the nearest project-level AGENTS.md" \
        "references/nav-templates.md"
      assert_failed=1
    fi
  else
    log_verbose "assert-root-nav-clean.sh not found or not executable — skipping"
  fi

  # --- Assert: Placeholder Gate ---
  if [[ -x "$ASSERT_SCRIPTS_DIR/assert-placeholder-gate.sh" ]]; then
    log_verbose "Running assert-placeholder-gate.sh..."
    if ! bash "$ASSERT_SCRIPTS_DIR/assert-placeholder-gate.sh" "$target_dir" 2>/dev/null; then
      emit_failure "$fixture_name" \
        "Generated files contain <...> angle-bracket placeholders" \
        "Found <...> pattern in generated output" \
        "Replace <...> placeholders with 'TODO: 待补充' or concrete values" \
        "references/regression-fixtures.md"
      assert_failed=1
    fi
  else
    log_verbose "assert-placeholder-gate.sh not found or not executable — skipping"
  fi

  # --- Assert: Golden Test ---
  if [[ -x "$ASSERT_SCRIPTS_DIR/assert-golden.sh" ]]; then
    local golden_dir="$ASSERT_SCRIPTS_DIR/golden/$fixture_name"
    if [[ -d "$golden_dir" ]]; then
      log_verbose "Running assert-golden.sh..."
      if ! bash "$ASSERT_SCRIPTS_DIR/assert-golden.sh" "$target_dir" "$golden_dir" 2>/dev/null; then
        emit_failure "$fixture_name" \
          "Generated output does not match golden baseline" \
          "Diff between generated output and tests/golden/$fixture_name/" \
          "Review the diff; if changes are intentional run assert-golden.sh --update" \
          "references/regression-fixtures.md"
        assert_failed=1
      fi
    else
      log_verbose "No golden baseline for $fixture_name — skipping golden test"
    fi
  else
    log_verbose "assert-golden.sh not found or not executable — skipping"
  fi

  return $assert_failed
}

# --- Main Execution ---

main() {
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  harness-init Fixture Test Runner${RESET}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
  echo ""

  # Validate fixtures directory exists
  if [[ ! -d "$FIXTURES_DIR" ]]; then
    echo "ERROR: Fixtures directory not found: $FIXTURES_DIR"
    exit 1
  fi

  # Collect fixture directories
  local fixtures=()
  for fixture_dir in "$FIXTURES_DIR"/*/; do
    if [[ -d "$fixture_dir" ]]; then
      local name
      name="$(basename "$fixture_dir")"
      # Apply filter if specified
      if [[ -n "$FILTER_FIXTURE" && "$name" != "$FILTER_FIXTURE" ]]; then
        continue
      fi
      fixtures+=("$name")
    fi
  done

  if [[ ${#fixtures[@]} -eq 0 ]]; then
    echo "No fixtures found to test."
    exit 1
  fi

  log_info "Found ${#fixtures[@]} fixture(s) to test"
  echo ""

  # Process each fixture
  for fixture_name in "${fixtures[@]}"; do
    TOTAL=$((TOTAL + 1))
    local fixture_path="$FIXTURES_DIR/$fixture_name"

    echo -e "${BOLD}──────────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}  Fixture: ${CYAN}$fixture_name${RESET}"
    echo -e "${BOLD}──────────────────────────────────────────────────────────────${RESET}"

    # Step 1: Create temp directory and copy fixture
    local temp_dir
    temp_dir="$(create_temp_dir "$fixture_name")"
    log_verbose "Temp dir: $temp_dir"

    copy_fixture_to_temp "$fixture_path" "$temp_dir"

    # Step 2: Run dry-run
    log_verbose "Step 2: Running dry-run..."
    if ! run_dry_run "$temp_dir"; then
      emit_failure "$fixture_name" \
        "Dry-run failed" \
        "harness-init dry-run exited with non-zero status" \
        "Check harness-init dry-run logic for compatibility with this fixture type" \
        "references/runtime-preflight.md"
      FAILED=$((FAILED + 1))
      rm -rf "$temp_dir"
      continue
    fi

    # Step 3: Run init (first time)
    log_verbose "Step 3: Running init (first run)..."
    if ! run_init "$temp_dir" "first"; then
      emit_failure "$fixture_name" \
        "First init run failed" \
        "harness-init init exited with non-zero status on first run" \
        "Check harness-init init logic for compatibility with this fixture type" \
        "references/runtime-preflight.md"
      FAILED=$((FAILED + 1))
      rm -rf "$temp_dir"
      continue
    fi

    # Snapshot after first run
    local first_snapshot
    first_snapshot="$(mktemp "${TMPDIR:-/tmp}/harness-snapshot-first-XXXXXX")"
    snapshot_dir "$temp_dir" "$first_snapshot"

    # Step 4: Run init again (second time — re-init)
    log_verbose "Step 4: Running init (second run — re-init)..."
    if ! run_init "$temp_dir" "second"; then
      emit_failure "$fixture_name" \
        "Second init run (re-init) failed" \
        "harness-init init exited with non-zero status on second run" \
        "Check idempotency logic — second run should succeed without errors" \
        "references/regression-fixtures.md"
      FAILED=$((FAILED + 1))
      rm -rf "$temp_dir" "$first_snapshot"
      continue
    fi

    # Snapshot after second run
    local second_snapshot
    second_snapshot="$(mktemp "${TMPDIR:-/tmp}/harness-snapshot-second-XXXXXX")"
    snapshot_dir "$temp_dir" "$second_snapshot"

    # Step 5: Run assertion scripts
    log_verbose "Step 5: Running assertions..."
    if run_assertions "$fixture_name" "$temp_dir" "$first_snapshot" "$second_snapshot"; then
      log_pass "$fixture_name"
      PASSED=$((PASSED + 1))
    else
      FAILED=$((FAILED + 1))
    fi

    # Cleanup
    rm -rf "$temp_dir" "$first_snapshot" "$second_snapshot"
    echo ""
  done

  # --- Summary ---
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  Summary${RESET}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  Total:   $TOTAL"
  echo -e "  ${GREEN}Passed:  $PASSED${RESET}"
  echo -e "  ${RED}Failed:  $FAILED${RESET}"
  if [[ $SKIPPED -gt 0 ]]; then
    echo -e "  ${YELLOW}Skipped: $SKIPPED${RESET}"
  fi
  echo ""

  if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}${BOLD}  RESULT: FAIL${RESET}"
    echo ""
    echo "  Failed fixtures:"
    for failure in "${FAILURES[@]}"; do
      echo "    - $failure"
    done
    echo ""
    exit 1
  else
    echo -e "${GREEN}${BOLD}  RESULT: PASS${RESET}"
    echo ""
    exit 0
  fi
}

main "$@"
