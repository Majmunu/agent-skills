#!/usr/bin/env bash
# scripts/harness/capture-screenshot.sh
# Captures a page screenshot via the configured UI provider.
#
# Usage: capture-screenshot.sh [--url <url>] [--full-page]
#
# Reads .harness/runtime.yml for ui.provider configuration.
# Captures page screenshot and saves to .harness/artifacts/screenshots/<timestamp>.png
#
# Requirements: 6.2, 6.4

set -euo pipefail

# --- Defaults ---
URL=""
FULL_PAGE=""
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
Usage: $(basename "$0") [--url <url>] [--full-page]

Capture a screenshot of the running application.

Parameters:
  --url <url>     Override the base URL from runtime.yml (optional)
  --full-page     Capture full scrollable page (optional)

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
    --url)       URL="$2"; shift 2 ;;
    --full-page) FULL_PAGE="true"; shift ;;
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

# --- Config Check ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  harness_notrun "UI verification backend is not configured." \
    "capture-screenshot.sh${URL:+ --url $URL}" \
    ".harness/runtime.yml does not exist" \
    "Cannot capture screenshot; UI visual verification unavailable"
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
  echo "Command: capture-screenshot.sh${URL:+ --url $URL}"
  echo "Reason: .harness/runtime.yml ui.provider is \"not-configured\""
  echo "Risk: Cannot capture screenshot; UI visual verification unavailable"
  exit 2
fi

# --- Handle TODO placeholder ---
if [[ "$BASE_URL" == "TODO: 待补充" || -z "$BASE_URL" ]]; then
  harness_notrun "UI base URL is not configured." \
    "capture-screenshot.sh${URL:+ --url $URL}" \
    ".harness/runtime.yml ui.base_url is \"TODO: 待补充\" or empty" \
    "Cannot capture screenshot without a target URL"
  exit 2
fi

# --- Provider: playwright ---
capture_screenshot_playwright() {
  # Check if npx/playwright is available
  if ! command -v npx >/dev/null 2>&1; then
    harness_notrun "capture-screenshot (playwright)" \
      "npx playwright ..." \
      "npx command not found; Playwright cannot be invoked" \
      "Screenshot capture unavailable; install Node.js and Playwright"
    exit 2
  fi

  # Create artifacts directory
  local artifact_dir="$PROJECT_ROOT/.harness/artifacts/screenshots"
  mkdir -p "$artifact_dir"

  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local output_file="$artifact_dir/${timestamp}.png"

  # Determine full-page option
  local full_page_opt="false"
  if [[ "$FULL_PAGE" == "true" ]]; then
    full_page_opt="true"
  fi

  # Use Playwright to capture screenshot
  local script="
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('${BASE_URL}');
  await page.waitForLoadState('networkidle');
  await page.screenshot({ path: '${output_file}', fullPage: ${full_page_opt} });
  await browser.close();
  console.log('done');
})();
"

  if node -e "$script" 2>/dev/null; then
    harness_pass "capture-screenshot: screenshot saved to .harness/artifacts/screenshots/${timestamp}.png"
    echo "  Provider:   playwright"
    echo "  URL:        $BASE_URL"
    echo "  Full page:  ${FULL_PAGE:-false}"
    echo "  Output:     $output_file"
    if [[ -f "$output_file" ]]; then
      echo "  Size:       $(wc -c < "$output_file") bytes"
    fi
    exit 0
  else
    harness_fail "capture-screenshot" \
      "Playwright screenshot capture failed" \
      "URL: ${BASE_URL}, Provider: playwright, Full page: ${FULL_PAGE:-false}" \
      "Ensure the dev server is running and Playwright browsers are installed (npx playwright install)" \
      "docs/ui-verification.md"
    exit 1
  fi
}

# --- Provider: chrome-devtools-mcp ---
capture_screenshot_cdp() {
  harness_notrun "capture-screenshot (chrome-devtools-mcp)" \
    "MCP chrome-devtools screenshot capture" \
    "chrome-devtools-mcp provider requires MCP server interaction (not available in shell scripts)" \
    "Screenshot capture unavailable via shell; use MCP tool directly"
  exit 2
}

# --- Dispatch by Provider ---
case "$PROVIDER" in
  playwright)
    capture_screenshot_playwright
    ;;
  chrome-devtools-mcp)
    capture_screenshot_cdp
    ;;
  *)
    harness_notrun "UI provider '$PROVIDER' is not supported for screenshot capture." \
      "capture-screenshot.sh${URL:+ --url $URL}" \
      ".harness/runtime.yml ui.provider is \"$PROVIDER\" (unsupported)" \
      "Cannot capture screenshot; supported providers: playwright, chrome-devtools-mcp"
    exit 2
    ;;
esac
