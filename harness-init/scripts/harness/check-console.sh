#!/usr/bin/env bash
# scripts/harness/check-console.sh
# Checks for console errors in the running application (with allowlist support).
#
# Usage: check-console.sh [--url <url>] [--allowlist <file>]
#
# Reads .harness/runtime.yml for ui.provider configuration.
# Reports console errors found during page load, excluding allowlisted patterns.
#
# Requirements: 6.3, 6.4

set -euo pipefail

# --- Defaults ---
URL=""
ALLOWLIST_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.harness/runtime.yml"
DEFAULT_ALLOWLIST="$PROJECT_ROOT/.harness/console-allowlist.yml"

# --- Output Helpers ---
if [[ -f "${SCRIPT_DIR}/_lib.sh" ]]; then
  # shellcheck source=_lib.sh
  source "${SCRIPT_DIR}/_lib.sh"
else
  harness_pass()   { echo "pass: $1"; }
  harness_fail()   { echo "FAIL: $1"; echo "Reason: ${2:-}"; echo "Evidence: ${3:-}"; echo "Fix: ${4:-}"; echo "Docs: ${5:-}"; echo "Bypass: ${6:-not allowed}"; }
  harness_warn()   { echo "warn: $1"; }
  harness_notrun() { echo "not-run: $1"; echo "Command: ${2:-}"; echo "Reason: ${3:-}"; echo "Risk: ${4:-}"; }
fi

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [--url <url>] [--allowlist <file>]

Check for console errors in the running application.

Parameters:
  --url <url>          Override the base URL from runtime.yml (optional)
  --allowlist <file>   Path to allowlist file with patterns to ignore (optional)
                       Default: .harness/console-allowlist.yml

Exit codes:
  0  No console errors found (pass)
  1  Console errors detected (fail)
  2  Not configured (not-run)
EOF
  exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)       URL="$2"; shift 2 ;;
    --allowlist) ALLOWLIST_FILE="$2"; shift 2 ;;
    --help|-h)   usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

# --- YAML Reading Helper ---
read_yml_value() {
  local file="$1"
  local key_path="$2"
  local IFS='.'
  read -ra keys <<< "$key_path"
  local result=""

  if [[ ${#keys[@]} -eq 1 ]]; then
    result=$(grep -E "^${keys[0]}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  elif [[ ${#keys[@]} -eq 2 ]]; then
    result=$(sed -n "/^${keys[0]}:/,/^[a-z]/p" "$file" 2>/dev/null | grep -E "^[[:space:]]+${keys[1]}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  elif [[ ${#keys[@]} -eq 3 ]]; then
    result=$(sed -n "/^${keys[0]}:/,/^[a-z]/p" "$file" 2>/dev/null | sed -n "/^[[:space:]]*${keys[1]}:/,/^[[:space:]]*[a-z]/p" | grep -E "^[[:space:]]+${keys[2]}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  fi
  echo "$result"
}

# Read allowlist patterns from file (one pattern per line, ignoring comments and empty lines)
read_allowlist() {
  local file="$1"
  local patterns=()
  if [[ -f "$file" ]]; then
    while IFS= read -r line; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      # Strip leading "- " for YAML list format
      line="${line#- }"
      line="${line#\"}"
      line="${line%\"}"
      [[ -n "$line" ]] && patterns+=("$line")
    done < "$file"
  fi
  printf '%s\n' "${patterns[@]}"
}

# Check if an error message matches any allowlist pattern
is_allowlisted() {
  local message="$1"
  local allowlist_file="$2"

  if [[ ! -f "$allowlist_file" ]]; then
    return 1
  fi

  while IFS= read -r pattern; do
    [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
    pattern="${pattern#- }"
    pattern="${pattern#\"}"
    pattern="${pattern%\"}"
    if [[ -n "$pattern" ]] && echo "$message" | grep -qE "$pattern" 2>/dev/null; then
      return 0
    fi
  done < "$allowlist_file"
  return 1
}

# --- Config Check ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  harness_notrun "UI verification backend is not configured." \
    "check-console.sh${URL:+ --url $URL}" \
    ".harness/runtime.yml does not exist" \
    "Cannot check console errors; runtime error detection unavailable"
  exit 2
fi

# --- Read UI Provider Config ---
PROVIDER=$(read_yml_value "$CONFIG_FILE" "ui.provider")
BASE_URL=$(read_yml_value "$CONFIG_FILE" "ui.base_url")

# Use override URL if provided
if [[ -n "$URL" ]]; then
  BASE_URL="$URL"
fi

# Use default allowlist if not specified
if [[ -z "$ALLOWLIST_FILE" ]]; then
  ALLOWLIST_FILE="$DEFAULT_ALLOWLIST"
fi

# --- Handle not-configured ---
if [[ -z "$PROVIDER" || "$PROVIDER" == "not-configured" ]]; then
  echo "not-run: UI verification backend is not configured."
  echo "Command: check-console.sh${URL:+ --url $URL}"
  echo "Reason: .harness/runtime.yml ui.provider is \"not-configured\""
  echo "Risk: Cannot check console errors; runtime error detection unavailable"
  exit 2
fi

# --- Handle TODO placeholder ---
if [[ "$BASE_URL" == "TODO: 待补充" || -z "$BASE_URL" ]]; then
  harness_notrun "UI base URL is not configured." \
    "check-console.sh${URL:+ --url $URL}" \
    ".harness/runtime.yml ui.base_url is \"TODO: 待补充\" or empty" \
    "Cannot check console errors without a target URL"
  exit 2
fi

# --- Provider: playwright ---
check_console_playwright() {
  # Check if npx/node is available
  if ! command -v npx >/dev/null 2>&1; then
    harness_notrun "check-console (playwright)" \
      "npx playwright ..." \
      "npx command not found; Playwright cannot be invoked" \
      "Console error checking unavailable; install Node.js and Playwright"
    exit 2
  fi

  # Use Playwright to capture console errors
  local script="
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });
  page.on('pageerror', err => {
    errors.push(err.message);
  });
  await page.goto('${BASE_URL}');
  await page.waitForLoadState('networkidle');
  // Wait a bit for any async errors
  await new Promise(r => setTimeout(r, 2000));
  await browser.close();
  if (errors.length > 0) {
    console.log(JSON.stringify(errors));
  } else {
    console.log('[]');
  }
})();
"

  local output
  if ! output=$(node -e "$script" 2>/dev/null); then
    harness_fail "check-console" \
      "Playwright console check failed to execute" \
      "URL: ${BASE_URL}, Provider: playwright" \
      "Ensure the dev server is running and Playwright browsers are installed (npx playwright install)" \
      "docs/ui-verification.md"
    exit 1
  fi

  # Parse errors from JSON output
  if [[ "$output" == "[]" || -z "$output" ]]; then
    harness_pass "check-console: no console errors detected"
    echo "  Provider: playwright"
    echo "  URL:      $BASE_URL"
    exit 0
  fi

  # Filter through allowlist
  local filtered_errors=()
  local allowlisted_count=0

  # Parse JSON array (simple line-by-line extraction)
  while IFS= read -r error_msg; do
    # Clean up JSON formatting
    error_msg="${error_msg#\"}"
    error_msg="${error_msg%\"}"
    error_msg="${error_msg%,}"
    [[ -z "$error_msg" || "$error_msg" == "[" || "$error_msg" == "]" ]] && continue

    if is_allowlisted "$error_msg" "$ALLOWLIST_FILE"; then
      ((allowlisted_count++)) || true
    else
      filtered_errors+=("$error_msg")
    fi
  done <<< "$(echo "$output" | tr ',' '\n' | sed 's/^\[//' | sed 's/\]$//')"

  if [[ ${#filtered_errors[@]} -eq 0 ]]; then
    harness_pass "check-console: no unallowlisted console errors (${allowlisted_count} allowlisted)"
    echo "  Provider:    playwright"
    echo "  URL:         $BASE_URL"
    echo "  Allowlisted: $allowlisted_count"
    exit 0
  else
    harness_fail "check-console" \
      "Console errors detected (${#filtered_errors[@]} errors, ${allowlisted_count} allowlisted)" \
      "$(printf '%s\n' "${filtered_errors[@]}" | head -5)" \
      "Fix the console errors or add patterns to .harness/console-allowlist.yml" \
      "docs/ui-verification.md"
    exit 1
  fi
}

# --- Provider: chrome-devtools-mcp ---
check_console_cdp() {
  harness_notrun "check-console (chrome-devtools-mcp)" \
    "MCP chrome-devtools console check" \
    "chrome-devtools-mcp provider requires MCP server interaction (not available in shell scripts)" \
    "Console error checking unavailable via shell; use MCP tool directly"
  exit 2
}

# --- Dispatch by Provider ---
case "$PROVIDER" in
  playwright)
    check_console_playwright
    ;;
  chrome-devtools-mcp)
    check_console_cdp
    ;;
  *)
    harness_notrun "UI provider '$PROVIDER' is not supported for console checking." \
      "check-console.sh${URL:+ --url $URL}" \
      ".harness/runtime.yml ui.provider is \"$PROVIDER\" (unsupported)" \
      "Cannot check console errors; supported providers: playwright, chrome-devtools-mcp"
    exit 2
    ;;
esac
