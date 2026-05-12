#!/usr/bin/env bash
# assert-placeholder-gate.sh — Placeholder checker for harness-init generated files
#
# Scans generated files for <...> angle-bracket placeholder patterns (FAIL)
# and TODO/FIXME/TBD/待补充 markers (WARN).
#
# Usage: tests/assert-placeholder-gate.sh <directory>
#
# Requirements: 4.1, 4.2, 4.3, 4.4

set -euo pipefail

# --- Arguments ---
TARGET_DIR="${1:-}"

if [[ -z "$TARGET_DIR" ]]; then
  echo "FAIL: assert-placeholder-gate"
  echo "Reason: No target directory provided"
  echo "Evidence: Usage: tests/assert-placeholder-gate.sh <directory>"
  echo "Fix: Provide the fixture working directory as the first argument"
  echo "Docs: references/quality-gates.md"
  echo "Bypass: not allowed"
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "FAIL: assert-placeholder-gate"
  echo "Reason: Target directory does not exist: $TARGET_DIR"
  echo "Evidence: stat $TARGET_DIR → not found"
  echo "Fix: Ensure the directory exists before running this check"
  echo "Docs: references/quality-gates.md"
  echo "Bypass: not allowed"
  exit 1
fi

# --- Configuration ---
# File extensions to scan
FILE_PATTERNS=( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" )

# Patterns to exclude from angle-bracket detection (not real placeholders)
# - harness-init marker comments: <!-- harness-init:start --> <!-- harness-init:end -->
# - URLs containing ://
# - HTML/XML tags that are clearly structural (e.g., <br>, <hr>, </div>)
EXCLUDE_PATTERN='(harness-init:(start|end)|://|<br\s*/?>|<hr\s*/?>|</?\w+>)'

# Angle-bracket placeholder pattern: <word> or <word-word> or <WORD>
# Matches: <placeholder>, <project-name>, <TODO>, <branch>, etc.
# Must contain at least one letter (excludes pure punctuation like < > operators)
PLACEHOLDER_PATTERN='<[A-Za-z][A-Za-z0-9_. /-]*>'

# Warning markers (not fail)
WARN_MARKERS='(TODO|FIXME|TBD|待补充)'

# --- State ---
fail_count=0
warn_count=0
fail_evidence=""
warn_evidence=""

# --- Scan for angle-bracket placeholders (FAIL) ---
while IFS= read -r -d '' file; do
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Skip lines matching exclusion patterns
    if echo "$line" | grep -qE "$EXCLUDE_PATTERN"; then
      # Check if the line ONLY has excluded patterns or also has real placeholders
      # Remove excluded content and re-check
      cleaned=$(echo "$line" | sed -E "s~$EXCLUDE_PATTERN~~g")
      if ! echo "$cleaned" | grep -qE "$PLACEHOLDER_PATTERN"; then
        continue
      fi
    fi

    # Check for angle-bracket placeholders
    if echo "$line" | grep -qE "$PLACEHOLDER_PATTERN"; then
      # Extract the relative path for cleaner output
      rel_path="${file#"$TARGET_DIR"/}"
      match=$(echo "$line" | grep -oE "$PLACEHOLDER_PATTERN" | head -1)
      fail_evidence="${fail_evidence}  ${rel_path}:${line_num}: ${match}\n"
      fail_count=$((fail_count + 1))
    fi
  done < "$file"
done < <(find "$TARGET_DIR" -type f \( "${FILE_PATTERNS[@]}" \) -print0 2>/dev/null)

# --- Scan for TODO/FIXME/TBD/待补充 markers (WARN) ---
while IFS= read -r -d '' file; do
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    if echo "$line" | grep -qE "$WARN_MARKERS"; then
      rel_path="${file#"$TARGET_DIR"/}"
      match=$(echo "$line" | grep -oE "$WARN_MARKERS" | head -1)
      warn_evidence="${warn_evidence}  ${rel_path}:${line_num}: ${match}\n"
      warn_count=$((warn_count + 1))
    fi
  done < "$file"
done < <(find "$TARGET_DIR" -type f \( "${FILE_PATTERNS[@]}" \) -print0 2>/dev/null)

# --- Output Results ---

# Report warnings (non-blocking)
if [[ $warn_count -gt 0 ]]; then
  echo "warn: placeholder-gate — found $warn_count TODO/FIXME/TBD/待补充 marker(s)"
  printf "%b" "$warn_evidence"
fi

# Report failures (blocking)
if [[ $fail_count -gt 0 ]]; then
  echo "FAIL: placeholder-gate"
  echo "Reason: Found $fail_count angle-bracket placeholder(s) in generated files"
  printf "Evidence:\n%b" "$fail_evidence"
  echo "Fix: Replace <...> placeholders with concrete values or use 'TODO: 待补充' for undetermined values"
  echo "Docs: references/quality-gates.md"
  echo "Bypass: not allowed"
  exit 1
fi

# All clear
if [[ $warn_count -eq 0 ]]; then
  echo "pass: placeholder-gate — no placeholders or markers found"
else
  echo "pass: placeholder-gate — no angle-bracket placeholders found ($warn_count warn marker(s) noted above)"
fi
exit 0
