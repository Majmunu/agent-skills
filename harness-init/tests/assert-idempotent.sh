#!/usr/bin/env bash
# tests/assert-idempotent.sh — Idempotency checker for harness-init
# Validates Requirements 2.1, 2.2, 2.3, 2.4
#
# Usage: tests/assert-idempotent.sh <working-dir>
#
# The working directory should contain two snapshot subdirectories:
#   first-run/   — state after first harness-init execution
#   second-run/  — state after second harness-init execution
#
# Checks:
#   1. No duplicate marker blocks (<!-- BEGIN GENERATED BLOCK patterns)
#   2. No duplicate package.json script entries
#   3. No duplicate markdown ## sections
#   4. Second-run file content matches first-run exactly

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER_PATTERN='<!-- BEGIN GENERATED BLOCK'

# --- Argument Validation ---
# Supports two calling conventions:
#   1. tests/assert-idempotent.sh <working-dir>
#      Expects first-run/ and second-run/ subdirectories inside working-dir
#   2. tests/assert-idempotent.sh <working-dir> <first-snapshot-file> <second-snapshot-file>
#      Used by run-fixtures.sh — compares snapshot hash files directly
if [[ $# -lt 1 ]]; then
  echo "FAIL: assert-idempotent"
  echo "Reason: Missing required argument — working directory path"
  echo "Evidence: Usage: tests/assert-idempotent.sh <working-dir> [<first-snapshot> <second-snapshot>]"
  echo "Fix: Provide the fixture working directory"
  echo "Docs: references/regression-fixtures.md"
  exit 1
fi

WORK_DIR="$1"
SNAPSHOT_MODE=0

if [[ ! -d "$WORK_DIR" ]]; then
  echo "FAIL: assert-idempotent"
  echo "Reason: Working directory does not exist: $WORK_DIR"
  echo "Evidence: Path not found on filesystem"
  echo "Fix: Ensure the fixture test runner creates the working directory before calling this script"
  echo "Docs: references/regression-fixtures.md"
  exit 1
fi

# Mode 2: snapshot file comparison (called by run-fixtures.sh)
if [[ $# -ge 3 ]]; then
  SNAPSHOT_MODE=1
  FIRST_SNAPSHOT_FILE="$2"
  SECOND_SNAPSHOT_FILE="$3"

  if [[ ! -f "$FIRST_SNAPSHOT_FILE" ]]; then
    echo "FAIL: assert-idempotent"
    echo "Reason: First snapshot file not found: $FIRST_SNAPSHOT_FILE"
    echo "Evidence: File does not exist"
    echo "Fix: Ensure run-fixtures.sh creates snapshot before calling this script"
    echo "Docs: references/regression-fixtures.md"
    exit 1
  fi
  if [[ ! -f "$SECOND_SNAPSHOT_FILE" ]]; then
    echo "FAIL: assert-idempotent"
    echo "Reason: Second snapshot file not found: $SECOND_SNAPSHOT_FILE"
    echo "Evidence: File does not exist"
    echo "Fix: Ensure run-fixtures.sh creates snapshot before calling this script"
    echo "Docs: references/regression-fixtures.md"
    exit 1
  fi

  # For snapshot mode, set FIRST_RUN and SECOND_RUN to WORK_DIR (same dir, compare via files)
  FIRST_RUN="$WORK_DIR"
  SECOND_RUN="$WORK_DIR"
else
  # Mode 1: directory-based comparison
  FIRST_RUN="$WORK_DIR/first-run"
  SECOND_RUN="$WORK_DIR/second-run"

  if [[ ! -d "$FIRST_RUN" ]]; then
    echo "FAIL: assert-idempotent"
    echo "Reason: first-run snapshot directory not found: $FIRST_RUN"
    echo "Evidence: Directory does not exist"
    echo "Fix: Run harness-init once and snapshot the output to first-run/ before calling this script"
    echo "Docs: references/regression-fixtures.md"
    exit 1
  fi

  if [[ ! -d "$SECOND_RUN" ]]; then
    echo "FAIL: assert-idempotent"
    echo "Reason: second-run snapshot directory not found: $SECOND_RUN"
    echo "Evidence: Directory does not exist"
    echo "Fix: Run harness-init a second time and snapshot the output to second-run/ before calling this script"
    echo "Docs: references/regression-fixtures.md"
    exit 1
  fi
fi

# --- State ---
FAILURES=()

# --- Helper: Record failure ---
record_failure() {
  local reason="$1"
  local evidence="$2"
  local fix="$3"
  FAILURES+=("Reason: $reason|Evidence: $evidence|Fix: $fix")
}

# --- Check 1: No duplicate marker blocks (Requirement 2.1) ---
check_duplicate_markers() {
  local dir="$1"
  local label="$2"
  local found_duplicates=0

  while IFS= read -r -d '' file; do
    # Count occurrences of marker pattern in this file
    local count
    count=$(grep -c "$MARKER_PATTERN" "$file" 2>/dev/null) || count=0
    count="${count//[^0-9]/}"
    [[ -z "$count" ]] && count=0

    if [[ "$count" -gt 1 ]]; then
      # Check if they are genuinely different blocks (different IDs) or true duplicates
      # Extract marker lines and check for duplicates
      local markers
      markers=$(grep "$MARKER_PATTERN" "$file" 2>/dev/null | sort)
      local unique_markers
      unique_markers=$(echo "$markers" | sort -u)

      local total_lines
      total_lines=$(echo "$markers" | wc -l | tr -d ' ')
      local unique_lines
      unique_lines=$(echo "$unique_markers" | wc -l | tr -d ' ')

      if [[ "$total_lines" -gt "$unique_lines" ]]; then
        local rel_path="${file#"$dir"/}"
        record_failure \
          "Duplicate marker block found in $label" \
          "File: $rel_path — $total_lines marker lines but only $unique_lines unique" \
          "Ensure harness-init uses read→compare→patch strategy to avoid re-inserting existing blocks"
        found_duplicates=1
      fi
    fi
  done < <(find "$dir" -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.html" \) -print0 2>/dev/null)

  return $found_duplicates
}

# --- Check 2: No duplicate package.json script entries (Requirement 2.2) ---
check_duplicate_pkg_scripts() {
  local dir="$1"
  local label="$2"
  local found_duplicates=0

  while IFS= read -r -d '' file; do
    # Extract script keys from the "scripts" block
    # Use a simple approach: find lines matching "key": within scripts section
    local in_scripts=0
    local brace_depth=0
    local script_keys=()

    while IFS= read -r line; do
      # Detect entering "scripts" block
      if [[ "$line" =~ \"scripts\"[[:space:]]*:[[:space:]]*\{ ]]; then
        in_scripts=1
        brace_depth=1
        continue
      fi

      if [[ $in_scripts -eq 1 ]]; then
        # Track brace depth
        local open_braces="${line//[^\{]/}"
        local close_braces="${line//[^\}]/}"
        brace_depth=$(( brace_depth + ${#open_braces} - ${#close_braces} ))

        if [[ $brace_depth -le 0 ]]; then
          in_scripts=0
          continue
        fi

        # Extract key name from "key": pattern
        if [[ "$line" =~ ^[[:space:]]*\"([^\"]+)\"[[:space:]]*: ]]; then
          script_keys+=("${BASH_REMATCH[1]}")
        fi
      fi
    done < "$file"

    # Check for duplicate keys
    if [[ ${#script_keys[@]} -gt 0 ]]; then
      local sorted_keys
      sorted_keys=$(printf '%s\n' "${script_keys[@]}" | sort)
      local unique_keys
      unique_keys=$(printf '%s\n' "${script_keys[@]}" | sort -u)

      local total_count
      total_count=$(printf '%s\n' "${script_keys[@]}" | wc -l | tr -d ' ')
      local unique_count
      unique_count=$(echo "$unique_keys" | wc -l | tr -d ' ')

      if [[ "$total_count" -gt "$unique_count" ]]; then
        local rel_path="${file#"$dir"/}"
        local dupes
        dupes=$(printf '%s\n' "${script_keys[@]}" | sort | uniq -d | tr '\n' ', ')
        record_failure \
          "Duplicate package.json scripts entries in $label" \
          "File: $rel_path — Duplicate keys: ${dupes%,}" \
          "Ensure harness-init merges only missing scripts entries without duplicating existing ones"
        found_duplicates=1
      fi
    fi
  done < <(find "$dir" -type f -name "package.json" -print0 2>/dev/null)

  return $found_duplicates
}

# --- Check 3: No duplicate docs sections (Requirement 2.3) ---
check_duplicate_doc_sections() {
  local dir="$1"
  local label="$2"
  local found_duplicates=0

  while IFS= read -r -d '' file; do
    # Extract ## headers
    local headers
    headers=$(grep -n '^## ' "$file" 2>/dev/null || true)

    if [[ -z "$headers" ]]; then
      continue
    fi

    local header_texts
    header_texts=$(echo "$headers" | sed 's/^[0-9]*://' | sort)
    local unique_headers
    unique_headers=$(echo "$header_texts" | sort -u)

    local total_count
    total_count=$(echo "$header_texts" | wc -l | tr -d ' ')
    local unique_count
    unique_count=$(echo "$unique_headers" | wc -l | tr -d ' ')

    if [[ "$total_count" -gt "$unique_count" ]]; then
      local rel_path="${file#"$dir"/}"
      local dupes
      dupes=$(echo "$header_texts" | sort | uniq -d | head -5 | tr '\n' '; ')
      record_failure \
        "Duplicate markdown sections in $label" \
        "File: $rel_path — Duplicate headers: ${dupes%;}" \
        "Ensure harness-init checks for existing sections before appending new ones"
      found_duplicates=1
    fi
  done < <(find "$dir" -type f -name "*.md" -print0 2>/dev/null)

  return $found_duplicates
}

# --- Check 4: Second-run matches first-run exactly (Requirement 2.4) ---
check_content_match() {
  local first="$1"
  local second="$2"
  local found_diff=0

  if [[ "$SNAPSHOT_MODE" -eq 1 ]]; then
    # Compare snapshot hash files directly
    local diff_output
    diff_output=$(diff "$FIRST_SNAPSHOT_FILE" "$SECOND_SNAPSHOT_FILE" 2>/dev/null || true)
    if [[ -n "$diff_output" ]]; then
      local evidence
      evidence=$(echo "$diff_output" | head -5 | tr '\n' '; ')
      record_failure \
        "Second-run output differs from first-run (snapshot comparison)" \
        "Differences found: ${evidence%;}" \
        "Ensure harness-init produces identical output on repeated execution (read→compare→patch strategy)"
      found_diff=1
    fi
  else
    # Compare directory contents using diff
    local diff_output
    diff_output=$(diff -r --brief "$first" "$second" 2>/dev/null || true)
    if [[ -n "$diff_output" ]]; then
      local evidence
      evidence=$(echo "$diff_output" | head -5 | tr '\n' '; ')
      record_failure \
        "Second-run output differs from first-run" \
        "Differences found: ${evidence%;}" \
        "Ensure harness-init produces identical output on repeated execution (read→compare→patch strategy)"
      found_diff=1
    fi
  fi

  return $found_diff
}

# --- Execute Checks ---

# Check duplicate markers in second-run snapshot
check_duplicate_markers "$SECOND_RUN" "second-run" || true

# Check duplicate package.json scripts in second-run snapshot
check_duplicate_pkg_scripts "$SECOND_RUN" "second-run" || true

# Check duplicate doc sections in second-run snapshot
check_duplicate_doc_sections "$SECOND_RUN" "second-run" || true

# Check that first-run and second-run are identical
check_content_match "$FIRST_RUN" "$SECOND_RUN" || true

# --- Output Results ---
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo "pass: assert-idempotent — no duplicates found, second-run matches first-run exactly"
  exit 0
else
  echo "FAIL: assert-idempotent"
  echo ""
  for failure in "${FAILURES[@]}"; do
    IFS='|' read -r reason evidence fix <<< "$failure"
    echo "$reason"
    echo "$evidence"
    echo "$fix"
    echo "Docs: references/regression-fixtures.md"
    echo ""
  done
  exit 1
fi
