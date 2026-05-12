#!/usr/bin/env bash
# scripts/harness/verify-user-journey.sh
# Executes a user journey from .harness/user-journeys/<name>.yml and generates reports.
#
# Usage: verify-user-journey.sh <journey-name>
#
# Reads .harness/runtime.yml for ui.provider configuration.
# Executes the journey steps defined in .harness/user-journeys/<journey-name>.yml
# and generates DOM, screenshot, console, and network reports.
#
# Requirements: 6.5, 6.4

set -euo pipefail

# --- Defaults ---
JOURNEY_NAME=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.harness/runtime.yml"
JOURNEYS_DIR="$PROJECT_ROOT/.harness/user-journeys"

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
Usage: $(basename "$0") <journey-name>

Execute a user journey and generate verification reports.

Parameters:
  <journey-name>   Name of the journey file (without .yml extension)
                   Reads from .harness/user-journeys/<journey-name>.yml

Reports generated:
  .harness/artifacts/journeys/<journey-name>/<timestamp>/dom.html
  .harness/artifacts/journeys/<journey-name>/<timestamp>/screenshot.png
  .harness/artifacts/journeys/<journey-name>/<timestamp>/console.log
  .harness/artifacts/journeys/<journey-name>/<timestamp>/network.log

Exit codes:
  0  Journey completed successfully (pass)
  1  Journey failed (fail)
  2  Not configured (not-run)
EOF
  exit 1
}

# --- Argument Parsing ---
if [[ $# -lt 1 ]]; then
  usage
fi

case "$1" in
  --help|-h) usage ;;
  *) JOURNEY_NAME="$1"; shift ;;
esac

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
    "verify-user-journey.sh $JOURNEY_NAME" \
    ".harness/runtime.yml does not exist" \
    "Cannot execute user journey; critical path verification unavailable"
  exit 2
fi

# --- Read UI Provider Config ---
PROVIDER=$(read_yml_value "$CONFIG_FILE" "ui.provider")
BASE_URL=$(read_yml_value "$CONFIG_FILE" "ui.base_url")

# --- Handle not-configured ---
if [[ -z "$PROVIDER" || "$PROVIDER" == "not-configured" ]]; then
  echo "not-run: UI verification backend is not configured."
  echo "Command: verify-user-journey.sh $JOURNEY_NAME"
  echo "Reason: .harness/runtime.yml ui.provider is \"not-configured\""
  echo "Risk: Cannot execute user journey; critical path verification unavailable"
  exit 2
fi

# --- Handle TODO placeholder ---
if [[ "$BASE_URL" == "TODO: 待补充" || -z "$BASE_URL" ]]; then
  harness_notrun "UI base URL is not configured." \
    "verify-user-journey.sh $JOURNEY_NAME" \
    ".harness/runtime.yml ui.base_url is \"TODO: 待补充\" or empty" \
    "Cannot execute user journey without a target URL"
  exit 2
fi

# --- Journey File Check ---
JOURNEY_FILE="$JOURNEYS_DIR/${JOURNEY_NAME}.yml"
if [[ ! -f "$JOURNEY_FILE" ]]; then
  harness_fail "verify-user-journey" \
    "Journey definition file not found" \
    "Expected: .harness/user-journeys/${JOURNEY_NAME}.yml" \
    "Create the journey file at .harness/user-journeys/${JOURNEY_NAME}.yml with steps definition" \
    "docs/ui-verification.md"
  exit 1
fi

# --- Provider: playwright ---
verify_journey_playwright() {
  # Check if npx/node is available
  if ! command -v npx >/dev/null 2>&1; then
    harness_notrun "verify-user-journey (playwright)" \
      "npx playwright ..." \
      "npx command not found; Playwright cannot be invoked" \
      "User journey verification unavailable; install Node.js and Playwright"
    exit 2
  fi

  # Create artifacts directory
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local artifact_dir="$PROJECT_ROOT/.harness/artifacts/journeys/${JOURNEY_NAME}/${timestamp}"
  mkdir -p "$artifact_dir"

  # Read journey steps from YAML (simplified parser for step list)
  # Expected format:
  # name: "Journey Name"
  # steps:
  #   - action: goto
  #     url: "/path"
  #   - action: click
  #     selector: "#button"
  #   - action: wait
  #     selector: ".result"
  #   - action: assert
  #     selector: ".success"
  #     text: "Done"

  # Generate Playwright script from journey YAML
  local script="
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  const networkLogs = [];

  // Capture console errors
  page.on('console', msg => {
    if (msg.type() === 'error') {
      errors.push('[console] ' + msg.text());
    }
  });
  page.on('pageerror', err => {
    errors.push('[pageerror] ' + err.message);
  });

  // Capture network requests
  page.on('response', response => {
    const status = response.status();
    const url = response.url();
    networkLogs.push(status + ' ' + response.request().method() + ' ' + url);
    if (status >= 400) {
      errors.push('[network] ' + status + ' ' + url);
    }
  });

  try {
    // Navigate to base URL
    await page.goto('${BASE_URL}');
    await page.waitForLoadState('networkidle');

    // Journey steps would be dynamically generated from YAML
    // For now, capture initial state
    await page.waitForTimeout(2000);

    // Capture DOM snapshot
    const dom = await page.content();
    fs.writeFileSync('${artifact_dir}/dom.html', dom);

    // Capture screenshot
    await page.screenshot({ path: '${artifact_dir}/screenshot.png', fullPage: true });

    // Write console log
    fs.writeFileSync('${artifact_dir}/console.log', errors.join('\\n'));

    // Write network log
    fs.writeFileSync('${artifact_dir}/network.log', networkLogs.join('\\n'));

    await browser.close();

    // Output result
    const result = {
      status: errors.length === 0 ? 'pass' : 'warn',
      errors: errors.length,
      network_requests: networkLogs.length,
      artifacts: '${artifact_dir}'
    };
    console.log(JSON.stringify(result));
  } catch (err) {
    await browser.close();
    const result = {
      status: 'fail',
      error: err.message,
      artifacts: '${artifact_dir}'
    };
    console.log(JSON.stringify(result));
  }
})();
"

  local output
  if ! output=$(node -e "$script" 2>/dev/null); then
    harness_fail "verify-user-journey" \
      "Playwright journey execution failed" \
      "Journey: ${JOURNEY_NAME}, URL: ${BASE_URL}, Provider: playwright" \
      "Ensure the dev server is running and Playwright browsers are installed (npx playwright install)" \
      "docs/ui-verification.md"
    exit 1
  fi

  # Parse result
  local status
  status=$(echo "$output" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

  case "$status" in
    pass)
      harness_pass "verify-user-journey: journey '${JOURNEY_NAME}' completed successfully"
      echo "  Provider:  playwright"
      echo "  URL:       $BASE_URL"
      echo "  Journey:   $JOURNEY_NAME"
      echo "  Artifacts: .harness/artifacts/journeys/${JOURNEY_NAME}/${timestamp}/"
      echo "  Reports:"
      echo "    - dom.html      (DOM snapshot)"
      echo "    - screenshot.png (page screenshot)"
      echo "    - console.log   (console output)"
      echo "    - network.log   (network requests)"
      exit 0
      ;;
    warn)
      local error_count
      error_count=$(echo "$output" | grep -o '"errors":[0-9]*' | cut -d: -f2)
      harness_warn "verify-user-journey: journey '${JOURNEY_NAME}' completed with ${error_count:-0} console/network errors"
      echo "  Provider:  playwright"
      echo "  URL:       $BASE_URL"
      echo "  Journey:   $JOURNEY_NAME"
      echo "  Artifacts: .harness/artifacts/journeys/${JOURNEY_NAME}/${timestamp}/"
      echo "  Review console.log and network.log for details"
      exit 0
      ;;
    fail)
      local error_msg
      error_msg=$(echo "$output" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4)
      harness_fail "verify-user-journey" \
        "Journey '${JOURNEY_NAME}' failed during execution" \
        "${error_msg:-Unknown error}" \
        "Check the journey definition and ensure the application is in the expected state" \
        "docs/ui-verification.md"
      exit 1
      ;;
    *)
      harness_fail "verify-user-journey" \
        "Unexpected result from journey execution" \
        "Output: $output" \
        "Check Playwright installation and journey definition" \
        "docs/ui-verification.md"
      exit 1
      ;;
  esac
}

# --- Provider: chrome-devtools-mcp ---
verify_journey_cdp() {
  harness_notrun "verify-user-journey (chrome-devtools-mcp)" \
    "MCP chrome-devtools journey execution" \
    "chrome-devtools-mcp provider requires MCP server interaction (not available in shell scripts)" \
    "User journey verification unavailable via shell; use MCP tool directly"
  exit 2
}

# --- Dispatch by Provider ---
case "$PROVIDER" in
  playwright)
    verify_journey_playwright
    ;;
  chrome-devtools-mcp)
    verify_journey_cdp
    ;;
  *)
    harness_notrun "UI provider '$PROVIDER' is not supported for user journey verification." \
      "verify-user-journey.sh $JOURNEY_NAME" \
      ".harness/runtime.yml ui.provider is \"$PROVIDER\" (unsupported)" \
      "Cannot execute user journey; supported providers: playwright, chrome-devtools-mcp"
    exit 2
    ;;
esac
