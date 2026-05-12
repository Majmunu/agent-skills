#!/usr/bin/env bash
# Harness Init — Context Snapshot: Update Script
# Scans project state sources and generates docs/harness/context-snapshot.md
# This snapshot is an INDEX ONLY — it does not replace source documents.
# Exit codes: 0=success, 1=failure, 2=not-run

set -euo pipefail

# --- Defaults ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/docs/harness"
OUTPUT_FILE="$OUTPUT_DIR/context-snapshot.md"

# --- Source Paths ---
ACTIVE_PLANS_DIR="$PROJECT_ROOT/docs/exec-plans/active"
COMPLETED_PLANS_DIR="$PROJECT_ROOT/docs/exec-plans/completed"
TECH_DEBT_FILE="$PROJECT_ROOT/docs/exec-plans/tech-debt-tracker.md"
ADR_EXCEPTIONS_DIR="$PROJECT_ROOT/docs/decisions/ADR-exceptions"
SCORECARD_CONFIG="$PROJECT_ROOT/.harness/scorecard.yml"
AUTONOMY_CONFIG="$PROJECT_ROOT/.harness/autonomy.yml"
GATES_CONFIG="$PROJECT_ROOT/.harness/gates.yml"
INTEGRATIONS_CONFIG="$PROJECT_ROOT/.harness/integrations.yml"
RUNTIME_CONFIG="$PROJECT_ROOT/.harness/runtime.yml"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run]

Scan project state and generate docs/harness/context-snapshot.md.

The snapshot is an index-only document that aggregates status from:
  - Active and recently completed execution plans
  - Tech debt tracker
  - ADR exceptions
  - Quality scorecard
  - Autonomy configuration
  - Gate results
  - Integration status

Options:
  --dry-run   Print snapshot to stdout without writing to file
  --help, -h  Show this help

Exit codes:
  0  Snapshot generated successfully
  1  Generation failed
  2  Not-run (critical source files missing)
EOF
  exit 0
}

DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
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

  if [[ ! -f "$file" ]]; then
    echo ""
    return
  fi

  if [[ ${#keys[@]} -eq 1 ]]; then
    result=$(grep -E "^${keys[0]}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  elif [[ ${#keys[@]} -eq 2 ]]; then
    result=$(sed -n "/^${keys[0]}:/,/^[a-z]/p" "$file" 2>/dev/null | grep -E "^[[:space:]]+${keys[1]}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  fi
  echo "$result"
}

# --- Detect CI Mode ---
detect_ci_mode() {
  # Check environment variable first
  if [[ -n "${HARNESS_CI_MODE:-}" ]]; then
    echo "$HARNESS_CI_MODE"
    return
  fi
  # Read from gates config
  if [[ -f "$GATES_CONFIG" ]]; then
    local mode
    mode=$(read_yml_value "$GATES_CONFIG" "mode")
    if [[ -n "$mode" ]]; then
      echo "$mode"
      return
    fi
  fi
  echo "bootstrap"
}

# --- Detect Autonomy Level ---
detect_autonomy_level() {
  if [[ -f "$AUTONOMY_CONFIG" ]]; then
    local level
    level=$(read_yml_value "$AUTONOMY_CONFIG" "level")
    if [[ -n "$level" && "$level" != "TODO: 待补充" ]]; then
      echo "$level"
      return
    fi
  fi
  echo "L1"
}

# --- Get Quality Score ---
get_quality_score() {
  local score_script="$SCRIPT_DIR/score-quality.sh"
  if [[ -x "$score_script" ]]; then
    local output
    output=$("$score_script" 2>/dev/null || true)
    local score
    score=$(echo "$output" | grep -E "^Total:" | head -1 | sed 's/Total:[[:space:]]*//' | sed 's|/100||')
    if [[ -n "$score" ]]; then
      echo "$score"
      return
    fi
  fi
  echo "N/A"
}

# --- List Active Plans ---
list_active_plans() {
  if [[ ! -d "$ACTIVE_PLANS_DIR" ]]; then
    echo "_(No active plans directory found)_"
    return
  fi
  local plans
  plans=$(find "$ACTIVE_PLANS_DIR" -name "*.md" -type f 2>/dev/null | sort)
  if [[ -z "$plans" ]]; then
    echo "_(No active plans)_"
    return
  fi
  while IFS= read -r plan; do
    local name
    name=$(basename "$plan" .md)
    local status=""
    if grep -q "^Status:" "$plan" 2>/dev/null; then
      status=$(grep "^Status:" "$plan" | head -1 | sed 's/^Status:[[:space:]]*//')
    fi
    local rel_path="${plan#"$PROJECT_ROOT"/}"
    echo "- **$name** — Status: ${status:-unknown} — \`$rel_path\`"
  done <<< "$plans"
}

# --- List Recently Completed Plans ---
list_completed_plans() {
  if [[ ! -d "$COMPLETED_PLANS_DIR" ]]; then
    echo "_(No completed plans directory found)_"
    return
  fi
  # Show up to 5 most recently modified completed plans
  local plans
  plans=$(find "$COMPLETED_PLANS_DIR" -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2-)
  if [[ -z "$plans" ]]; then
    # Fallback for systems without -printf (macOS)
    plans=$(find "$COMPLETED_PLANS_DIR" -name "*.md" -type f 2>/dev/null | head -5)
  fi
  if [[ -z "$plans" ]]; then
    echo "_(No completed plans)_"
    return
  fi
  while IFS= read -r plan; do
    local name
    name=$(basename "$plan" .md)
    local rel_path="${plan#"$PROJECT_ROOT"/}"
    echo "- **$name** — \`$rel_path\`"
  done <<< "$plans"
}

# --- List Open Tech Debts ---
list_tech_debts() {
  if [[ ! -f "$TECH_DEBT_FILE" ]]; then
    echo "_(No tech debt tracker found)_"
    return
  fi
  # Extract items marked as open/pending (lines starting with - [ ])
  local debts
  debts=$(grep -E "^[[:space:]]*-[[:space:]]\[[ ]\]" "$TECH_DEBT_FILE" 2>/dev/null | head -10)
  if [[ -z "$debts" ]]; then
    echo "_(No open tech debts)_"
    return
  fi
  echo "$debts"
}

# --- List Failing Gates ---
list_failing_gates() {
  local check_script="$SCRIPT_DIR/check-all.sh"
  if [[ ! -x "$check_script" ]]; then
    echo "_(Gate runner not available)_"
    return
  fi
  local output
  output=$("$check_script" 2>/dev/null || true)
  local failures
  failures=$(echo "$output" | grep -E "^FAIL:" | head -10)
  if [[ -z "$failures" ]]; then
    local not_runs
    not_runs=$(echo "$output" | grep -E "^not-run:" | head -5)
    if [[ -n "$not_runs" ]]; then
      echo "$not_runs"
    else
      echo "_(All gates passing)_"
    fi
    return
  fi
  echo "$failures"
}

# --- List Active ADR Exceptions ---
list_adr_exceptions() {
  if [[ ! -d "$ADR_EXCEPTIONS_DIR" ]]; then
    echo "_(No ADR exceptions directory found)_"
    return
  fi
  local exceptions
  exceptions=$(find "$ADR_EXCEPTIONS_DIR" -name "*.md" -type f 2>/dev/null | sort)
  if [[ -z "$exceptions" ]]; then
    echo "_(No active ADR exceptions)_"
    return
  fi
  while IFS= read -r exc; do
    local name
    name=$(basename "$exc" .md)
    local rel_path="${exc#"$PROJECT_ROOT"/}"
    # Check for expiry
    local expiry=""
    if grep -qi "expires\|expiry\|valid.until" "$exc" 2>/dev/null; then
      expiry=$(grep -i "expires\|expiry\|valid.until" "$exc" | head -1 | sed 's/^[^:]*:[[:space:]]*//')
    fi
    if [[ -n "$expiry" ]]; then
      echo "- **$name** — Expires: $expiry — \`$rel_path\`"
    else
      echo "- **$name** — \`$rel_path\`"
    fi
  done <<< "$exceptions"
}

# --- Detect Integration Status ---
detect_integration_status() {
  if [[ ! -f "$INTEGRATIONS_CONFIG" ]]; then
    echo "| Code Host | not-configured |"
    echo "| Issue Tracker | not-configured |"
    echo "| MCP | not-configured |"
    return
  fi
  local code_host
  code_host=$(read_yml_value "$INTEGRATIONS_CONFIG" "code_host.provider")
  local issue_tracker
  issue_tracker=$(read_yml_value "$INTEGRATIONS_CONFIG" "issue_tracker.provider")
  local mcp_enabled
  mcp_enabled=$(read_yml_value "$INTEGRATIONS_CONFIG" "mcp.enabled")

  echo "| Code Host | ${code_host:-not-configured} |"
  echo "| Issue Tracker | ${issue_tracker:-not-configured} |"
  echo "| MCP | ${mcp_enabled:-false} |"
}

# --- Generate Next Recommended Actions ---
generate_next_actions() {
  local actions=()
  local score="$1"

  # Check for missing critical files
  if [[ ! -d "$ACTIVE_PLANS_DIR" ]]; then
    actions+=("Create \`docs/exec-plans/active/\` directory for execution plans")
  fi
  if [[ ! -f "$TECH_DEBT_FILE" ]]; then
    actions+=("Create \`docs/exec-plans/tech-debt-tracker.md\` to track technical debt")
  fi
  if [[ ! -f "$SCORECARD_CONFIG" ]]; then
    actions+=("Create \`.harness/scorecard.yml\` for quality scoring configuration")
  fi
  if [[ ! -f "$AUTONOMY_CONFIG" ]]; then
    actions+=("Create \`.harness/autonomy.yml\` for autonomy level configuration")
  fi
  if [[ ! -f "$INTEGRATIONS_CONFIG" ]]; then
    actions+=("Create \`.harness/integrations.yml\` for external integration configuration")
  fi

  # Score-based recommendations
  if [[ "$score" != "N/A" ]]; then
    if [[ "$score" -lt 60 ]]; then
      actions+=("Improve quality score to 60+ to reach bootstrap mode")
    elif [[ "$score" -lt 80 ]]; then
      actions+=("Improve quality score to 80+ to reach enforced mode")
    elif [[ "$score" -lt 85 ]]; then
      actions+=("Improve quality score to 85+ for L3 autonomy eligibility")
    fi
  fi

  if [[ ${#actions[@]} -eq 0 ]]; then
    echo "_(No immediate actions required)_"
    return
  fi

  local i=1
  for action in "${actions[@]}"; do
    echo "$i. $action"
    ((i++))
  done
}

# --- Recent Incidents ---
list_recent_incidents() {
  local incidents_dir="$PROJECT_ROOT/docs/incidents"
  if [[ ! -d "$incidents_dir" ]]; then
    echo "_(No incidents directory found)_"
    return
  fi
  # Show up to 5 most recent incidents
  local incidents
  incidents=$(find "$incidents_dir" -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2-)
  if [[ -z "$incidents" ]]; then
    incidents=$(find "$incidents_dir" -name "*.md" -type f 2>/dev/null | head -5)
  fi
  if [[ -z "$incidents" ]]; then
    echo "_(No recorded incidents)_"
    return
  fi
  while IFS= read -r inc; do
    local name
    name=$(basename "$inc" .md)
    local rel_path="${inc#"$PROJECT_ROOT"/}"
    echo "- **$name** — \`$rel_path\`"
  done <<< "$incidents"
}

# --- Generate Snapshot ---
generate_snapshot() {
  local ci_mode
  ci_mode=$(detect_ci_mode)
  local autonomy_level
  autonomy_level=$(detect_autonomy_level)
  local quality_score
  quality_score=$(get_quality_score)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")

  cat <<EOF
# Context Snapshot

<!-- Harness Init Contract Version: v3 -->
<!-- Generated/Updated by: harness-init -->
<!-- Scope: root -->

> **This is an index-only document.** It aggregates status from source documents
> and does not replace them. Always refer to the linked source for full details.

**Last Updated:** $timestamp

---

## Project Status Summary

| Dimension | Value |
|---|---|
| CI Mode | $ci_mode |
| Autonomy Level | $autonomy_level |
| Quality Score | ${quality_score}/100 |

---

## Active Plans

$(list_active_plans)

Source: \`docs/exec-plans/active/\`

---

## Recently Completed Plans

$(list_completed_plans)

Source: \`docs/exec-plans/completed/\`

---

## Open Tech Debts

$(list_tech_debts)

Source: \`docs/exec-plans/tech-debt-tracker.md\`

---

## Failing Gates

$(list_failing_gates)

Source: Run \`scripts/harness/check-all.sh\` for full gate report.

---

## Active ADR Exceptions

$(list_adr_exceptions)

Source: \`docs/decisions/ADR-exceptions/\`

---

## Recent Incidents

$(list_recent_incidents)

Source: \`docs/incidents/\`

---

## Integration Status

| Integration | Status |
|---|---|
$(detect_integration_status)

Source: \`.harness/integrations.yml\`

---

## Next Recommended Actions

$(generate_next_actions "$quality_score")

---

## Source Documents

This snapshot aggregates information from:

- \`docs/exec-plans/active/\` — Active execution plans
- \`docs/exec-plans/completed/\` — Completed execution plans
- \`docs/exec-plans/tech-debt-tracker.md\` — Technical debt tracking
- \`docs/decisions/ADR-exceptions/\` — Architecture decision exceptions
- \`.harness/scorecard.yml\` — Quality scoring configuration
- \`.harness/autonomy.yml\` — Autonomy level configuration
- \`.harness/gates.yml\` — Gate configuration and mode
- \`.harness/integrations.yml\` — External integrations
- \`docs/incidents/\` — Incident records

To update this snapshot, run:

\`\`\`bash
scripts/harness/update-context-snapshot.sh
\`\`\`
EOF
}

# --- Main ---
main() {
  local snapshot
  snapshot=$(generate_snapshot)

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "$snapshot"
    echo ""
    echo "pass: Context snapshot generated (dry-run, not written to file)"
    exit 0
  fi

  # Ensure output directory exists
  mkdir -p "$OUTPUT_DIR"

  # Write snapshot
  echo "$snapshot" > "$OUTPUT_FILE"

  echo "pass: Context snapshot updated at docs/harness/context-snapshot.md"
  echo "Last Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")"
  exit 0
}

main
