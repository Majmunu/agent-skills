#!/usr/bin/env bash
# scripts/harness/capture-dom.sh
# Captures a DOM snapshot via Playwright when configured.
#
# Usage: capture-dom.sh [--url <url>]
#
# Reads .harness/runtime.yml for ui.provider configuration.
# When ui.provider is "playwright", captures DOM snapshot and saves to
# .harness/artifacts/dom/<timestamp>.html
#
# Requirements: 6.1, 6.4

set -euo pipefail

# --- Defaults ---
URL=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.harness/runtime.yml"

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
Usage: $(basename "$0") [--url <url>]

Capture a DOM snapshot of the running application.

Parameters:
  --url <url>   Override the base URL from runtime.yml (optional)

Exit codes:
  0  Capture successful
  1  Capture failed
  2  Not configured (not-run)
EOF
  exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)  URL="$2"; shift 2 ;;
    --help|-h) usage ;;
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

# --- Config Check ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  harness_notrun "UI verification backend is not configured." \
    "capture-dom.sh${URL:+ --url $URL}" \
    ".harness/runtime.yml does not exist" \
    "Cannot capture DOM snapshot; UI state verification unavailable"
  exit 2
fi

# --- Read UI Provider Config ---
PROVIDER=$(read_yml_value "$CONFIG_FILE" "ui.provider")
BASE_URL=$(read_yml_value "$CONFIG_FILE" "ui.base_url")

# Use override URL if provided
if [[ -n "$URL" ]]; then
  BASE_URL="$URL"
fi

# --- Handle not-configured ---
if [[ -z "$PROVIDER" || "$PROVIDER" == "not-configured" ]]; then
  echo "not-run: UI verification backend is not configured."
  echo "Command: capture-dom.sh${URL:+ --url $URL}"
  echo "Reason: .harness/runtime.yml ui.provider is \"not-configured\""
  echo "Risk: Cannot capture DOM snapshot; UI state verification unavailable"
  exit 2
fi

# --- Handle TODO placeholder ---
if [[ "$BASE_URL" == "TODO: 待补充" || -z "$BASE_URL" ]]; then
  harness_notrun "UI base URL is not configured." \
    "capture-dom.sh${URL:+ --url $URL}" \
    ".harness/runtime.yml ui.base_url is \"TODO: 待补充\" or empty" \
    "Cannot capture DOM snapshot without a target URL"
  exit 2
fi

# --- Provider: playwright ---
capture_dom_playwright() {
  # Check if npx/playwright is available
  if ! command -v npx >/dev/null 2>&1; then
    harness_notrun "capture-dom (playwright)" \
      "npx playwright ..." \
      "npx command not found; Playwright cannot be invoked" \
      "DOM snapshot capture unavailable; install Node.js and Playwright"
    exit 2
  fi

  # Create artifacts directory
  local artifact_dir="$PROJECT_ROOT/.harness/artifacts/dom"
  mkdir -p "$artifact_dir"

  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local output_file="$artifact_dir/${timestamp}.html"

  # Use Playwright to capture DOM content
  local script="
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('${BASE_URL}');
  await page.waitForLoadState('networkidle');
  const content = await page.content();
  process.stdout.write(content);
  await browser.close();
})();
"

  local dom_content
  if dom_content=$(echo "$script" | npx --yes playwright test --reporter=list 2>/dev/null) || \
     dom_content=$(node -e "$script" 2>/dev/null); then
    echo "$dom_content" > "$output_file"
    harness_pass "capture-dom: DOM snapshot saved to .harness/artifacts/dom/${timestamp}.html"
    echo "  Provider: playwright"
    echo "  URL:      $BASE_URL"
    echo "  Output:   $output_file"
    echo "  Size:     $(wc -c < "$output_file") bytes"
    exit 0
  else
    harness_fail "capture-dom" \
      "Playwright DOM capture failed" \
      "URL: ${BASE_URL}, Provider: playwright" \
      "Ensure the dev server is running and Playwright browsers are installed (npx playwright install)" \
      "docs/ui-verification.md"
    exit 1
  fi
}

# --- Provider: chrome-devtools-mcp ---
capture_dom_cdp() {
  harness_notrun "capture-dom (chrome-devtools-mcp)" \
    "MCP chrome-devtools DOM capture" \
    "chrome-devtools-mcp provider requires MCP server interaction (not available in shell scripts)" \
    "DOM snapshot capture unavailable via shell; use MCP tool directly"
  exit 2
}

# --- Dispatch by Provider ---
case "$PROVIDER" in
  playwright)
    capture_dom_playwright
    ;;
  chrome-devtools-mcp)
    capture_dom_cdp
    ;;
  *)
    harness_notrun "UI provider '$PROVIDER' is not supported for DOM capture." \
      "capture-dom.sh${URL:+ --url $URL}" \
      ".harness/runtime.yml ui.provider is \"$PROVIDER\" (unsupported)" \
      "Cannot capture DOM snapshot; supported providers: playwright, chrome-devtools-mcp"
    exit 2
    ;;
esac
