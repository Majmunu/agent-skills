#!/usr/bin/env bash
# =============================================================================
# tests/assert-golden.sh — Golden baseline comparison for harness-init
# =============================================================================
# Validates Requirements 24.1, 24.2, 24.3, 24.4, 24.5
#
# Usage:
#   tests/assert-golden.sh <generated-dir> <golden-dir> [--update]
#
# Arguments:
#   <generated-dir>  Directory containing harness-init generated output
#   <golden-dir>     Directory containing golden baseline files
#   --update         Update golden baselines from generated output (refresh)
#
# Behavior:
#   - Compares each file in <golden-dir> against the corresponding file in
#     <generated-dir>
#   - Normalizes timestamps, dynamic IDs, and non-deterministic content
#     before comparison
#   - Outputs FAIL with specific diff content, file paths, and line numbers
#     on mismatch
#   - Outputs pass when all golden files match generated output
#
# Exit codes:
#   0 — All golden baselines match (pass)
#   1 — One or more mismatches found (fail)
# =============================================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Patterns to normalize before comparison (Requirement 24.5)
# These are replaced with stable placeholders so diffs are meaningful
TIMESTAMP_ISO_PATTERN='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?'
TIMESTAMP_HUMAN_PATTERN='(Last Updated|Generated|Updated):.*[0-9]{4}-[0-9]{2}-[0-9]{2}'
UUID_PATTERN='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
HASH_PATTERN='[0-9a-fA-F]{32,64}'

# --- Argument Parsing ---
UPDATE_MODE=0
GENERATED_DIR=""
GOLDEN_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      UPDATE_MODE=1
      shift
      ;;
    --help|-h)
      echo "Usage: $0 <generated-dir> <golden-dir> [--update]"
      echo ""
      echo "Arguments:"
      echo "  <generated-dir>  Directory containing harness-init generated output"
      echo "  <golden-dir>     Directory containing golden baseline files"
      echo ""
      echo "Options:"
      echo "  --update         Update golden baselines from generated output"
      echo "  --help, -h       Show this help message"
      exit 0
      ;;
    *)
      if [[ -z "$GENERATED_DIR" ]]; then
        GENERATED_DIR="$1"
      elif [[ -z "$GOLDEN_DIR" ]]; then
        GOLDEN_DIR="$1"
      else
        echo "FAIL: assert-golden"
        echo "Reason: Unexpected argument: $1"
        echo "Evidence: Usage: $0 <generated-dir> <golden-dir> [--update]"
        echo "Fix: Provide exactly two positional arguments: generated directory and golden directory"
        echo "Docs: references/regression-fixtures.md"
        exit 1
      fi
      shift
      ;;
  esac
done

# --- Argument Validation ---
if [[ -z "$GENERATED_DIR" ]]; then
  echo "FAIL: assert-golden"
  echo "Reason: Missing required argument — generated output directory"
  echo "Evidence: Usage: $0 <generated-dir> <golden-dir> [--update]"
  echo "Fix: Provide the directory containing harness-init generated output as the first argument"
  echo "Docs: references/regression-fixtures.md"
  exit 1
fi

if [[ -z "$GOLDEN_DIR" ]]; then
  echo "FAIL: assert-golden"
  echo "Reason: Missing required argument — golden baseline directory"
  echo "Evidence: Usage: $0 <generated-dir> <golden-dir> [--update]"
  echo "Fix: Provide the golden baseline directory as the second argument"
  echo "Docs: references/regression-fixtures.md"
  exit 1
fi

if [[ ! -d "$GENERATED_DIR" ]]; then
  echo "FAIL: assert-golden"
  echo "Reason: Generated output directory does not exist: $GENERATED_DIR"
  echo "Evidence: Path not found on filesystem"
  echo "Fix: Ensure harness-init has been run and the output directory exists"
  echo "Docs: references/regression-fixtures.md"
  exit 1
fi

if [[ ! -d "$GOLDEN_DIR" ]]; then
  if [[ "$UPDATE_MODE" -eq 1 ]]; then
    # In update mode, create the golden directory if it doesn't exist
    mkdir -p "$GOLDEN_DIR"
  else
    echo "FAIL: assert-golden"
    echo "Reason: Golden baseline directory does not exist: $GOLDEN_DIR"
    echo "Evidence: Path not found on filesystem"
    echo "Fix: Create golden baselines with: $0 <generated-dir> <golden-dir> --update"
    echo "Docs: references/regression-fixtures.md"
    exit 1
  fi
fi

# --- Helper Functions ---

# Normalize content by replacing dynamic/non-deterministic values with stable placeholders
# This ensures timestamps, UUIDs, and hashes don't cause false-positive diffs
# Requirement 24.5
normalize_content() {
  local content="$1"

  # Replace ISO timestamps with placeholder
  content=$(echo "$content" | sed -E "s/$TIMESTAMP_ISO_PATTERN/<TIMESTAMP>/g")

  # Replace human-readable timestamp lines (e.g., "Last Updated: 2024-01-15")
  content=$(echo "$content" | sed -E "s/$TIMESTAMP_HUMAN_PATTERN/\1: <TIMESTAMP>/g")

  # Replace UUIDs with placeholder
  content=$(echo "$content" | sed -E "s/$UUID_PATTERN/<UUID>/g")

  # Replace standalone hex hashes (32-64 chars, only when they appear as whole tokens)
  # Be careful not to replace short hex strings that might be meaningful
  content=$(echo "$content" | sed -E "s/\b[0-9a-fA-F]{40,64}\b/<HASH>/g")

  # Strip trailing whitespace (normalize line endings)
  content=$(echo "$content" | sed 's/[[:space:]]*$//')

  echo "$content"
}

# Compare two files after normalization
# Args: generated_file, golden_file, relative_path
# Returns: 0 if match, 1 if mismatch (outputs diff info)
compare_file() {
  local generated_file="$1"
  local golden_file="$2"
  local rel_path="$3"

  # Check if generated file exists
  if [[ ! -f "$generated_file" ]]; then
    echo "  MISMATCH: $rel_path"
    echo "    Status: File missing in generated output"
    echo "    Expected: Present (exists in golden baseline)"
    echo "    Fix: Ensure harness-init generates this file for the fixture"
    return 1
  fi

  # Normalize both files
  local gen_normalized
  local gold_normalized
  gen_normalized=$(normalize_content "$(cat "$generated_file")")
  gold_normalized=$(normalize_content "$(cat "$golden_file")")

  # Compare normalized content
  local diff_output
  diff_output=$(diff --unified=3 \
    <(echo "$gold_normalized") \
    <(echo "$gen_normalized") \
    2>/dev/null) || true

  if [[ -n "$diff_output" ]]; then
    # Extract line numbers from diff output
    local line_info
    line_info=$(echo "$diff_output" | grep '^@@' | head -5)

    echo "  MISMATCH: $rel_path"
    echo "    Diff:"
    # Show first 20 lines of diff for readability
    echo "$diff_output" | head -20 | sed 's/^/      /'
    if [[ $(echo "$diff_output" | wc -l) -gt 20 ]]; then
      echo "      ... (diff truncated, $(echo "$diff_output" | wc -l) total lines)"
    fi
    echo "    Lines: $line_info"
    return 1
  fi

  return 0
}

# Update golden baselines from generated output
# Args: generated_dir, golden_dir
update_baselines() {
  local gen_dir="$1"
  local gold_dir="$2"

  echo "Updating golden baselines..."
  echo "  Source: $gen_dir"
  echo "  Target: $gold_dir"
  echo ""

  # If golden dir has existing files, compare what's there and update
  # Only copy files that already exist in golden (or all if golden is empty)
  local file_count=0
  local golden_has_files=0

  if [[ -n "$(find "$gold_dir" -type f 2>/dev/null)" ]]; then
    golden_has_files=1
  fi

  if [[ "$golden_has_files" -eq 1 ]]; then
    # Update existing golden files from generated output
    while IFS= read -r -d '' golden_file; do
      local rel_path="${golden_file#"$gold_dir"/}"
      local gen_file="$gen_dir/$rel_path"

      if [[ -f "$gen_file" ]]; then
        # Ensure target directory exists
        mkdir -p "$(dirname "$golden_file")"
        cp "$gen_file" "$golden_file"
        echo "  Updated: $rel_path"
        file_count=$((file_count + 1))
      else
        echo "  Warning: $rel_path exists in golden but not in generated output (kept as-is)"
      fi
    done < <(find "$gold_dir" -type f -not -name "README.md" -print0 2>/dev/null)
  else
    # Golden is empty — copy all generated files
    if [[ -d "$gen_dir" ]]; then
      cp -r "$gen_dir"/. "$gold_dir/"
      file_count=$(find "$gold_dir" -type f | wc -l)
      echo "  Copied all files from generated output ($file_count files)"
    fi
  fi

  echo ""
  echo "pass: assert-golden — baselines updated ($file_count files)"
  exit 0
}

# --- Main Execution ---

# Handle --update mode (Requirement 24.4)
if [[ "$UPDATE_MODE" -eq 1 ]]; then
  update_baselines "$GENERATED_DIR" "$GOLDEN_DIR"
fi

# --- Comparison Mode (Requirement 24.2, 24.3) ---

FAILURES=()
TOTAL_FILES=0
MATCHED_FILES=0

# Iterate over all files in the golden baseline directory
while IFS= read -r -d '' golden_file; do
  # Skip README.md in golden root (it's documentation, not a baseline)
  if [[ "$golden_file" == "$GOLDEN_DIR/README.md" ]]; then
    continue
  fi

  TOTAL_FILES=$((TOTAL_FILES + 1))

  # Compute relative path
  local_rel_path="${golden_file#"$GOLDEN_DIR"/}"

  # Find corresponding file in generated output
  generated_file="$GENERATED_DIR/$local_rel_path"

  # Compare files
  if compare_file "$generated_file" "$golden_file" "$local_rel_path"; then
    MATCHED_FILES=$((MATCHED_FILES + 1))
  else
    FAILURES+=("$local_rel_path")
  fi
done < <(find "$GOLDEN_DIR" -type f -print0 2>/dev/null | sort -z)

# --- Output Results ---

if [[ $TOTAL_FILES -eq 0 ]]; then
  echo "warn: assert-golden — no golden baseline files found in $GOLDEN_DIR"
  echo "  Fix: Create baselines with: $0 <generated-dir> $GOLDEN_DIR --update"
  exit 0
fi

if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo "pass: assert-golden — all $TOTAL_FILES golden baseline(s) match"
  exit 0
else
  echo "FAIL: assert-golden"
  echo "Reason: Generated output does not match golden baselines"
  echo "Evidence: ${#FAILURES[@]} of $TOTAL_FILES file(s) differ:"
  for failed_file in "${FAILURES[@]}"; do
    echo "  - $failed_file"
  done
  echo "Fix: Review diffs above. If changes are intentional, update baselines with: $0 $GENERATED_DIR $GOLDEN_DIR --update"
  echo "Docs: references/regression-fixtures.md"
  exit 1
fi
