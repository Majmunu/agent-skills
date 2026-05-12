#!/usr/bin/env bash
# Harness Init — Quality Scoring Script
# Reads .harness/scorecard.yml and evaluates project harness quality across 7 dimensions.
# Outputs: total score, mode suggestion, autonomy level suggestion, blocking issues, next actions.
# Exit codes: 0=success (score computed), 1=error, 2=not-run (config missing)

set -euo pipefail

# --- Defaults ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.harness/scorecard.yml"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [--json] [--quiet]

Evaluate project harness quality across 7 dimensions and output score with recommendations.

Options:
  --json     Output results in JSON format
  --quiet    Output only the total score number
  --help     Show this help message

Configuration: .harness/scorecard.yml
Docs: references/scorecard-templates.md

Exit codes:
  0  Score computed successfully
  1  Error during evaluation
  2  Not configured (scorecard.yml missing)
EOF
  exit 1
}

# --- Argument Parsing ---
OUTPUT_JSON=false
OUTPUT_QUIET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)  OUTPUT_JSON=true; shift ;;
    --quiet) OUTPUT_QUIET=true; shift ;;
    --help|-h) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

# --- YAML Reading Helper ---
# Lightweight YAML value reader (supports simple key: value lines)
# Strips inline comments (# ...) and surrounding whitespace/quotes
read_yml_value() {
  local file="$1"
  local key_path="$2"
  local IFS='.'
  read -ra keys <<< "$key_path"
  local result=""

  if [[ ${#keys[@]} -eq 1 ]]; then
    result=$(grep -E "^${keys[0]}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  elif [[ ${#keys[@]} -eq 2 ]]; then
    result=$(sed -n "/^${keys[0]}:/,/^[a-z]/p" "$file" 2>/dev/null | grep -E "^[[:space:]]+${keys[1]}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  elif [[ ${#keys[@]} -eq 3 ]]; then
    # Support 3-level nesting (e.g. runtime.dev.health_check or runtime.checks.test)
    result=$(sed -n "/^${keys[0]}:/,/^[a-z]/p" "$file" 2>/dev/null | sed -n "/^[[:space:]]*${keys[1]}:/,/^[[:space:]]*[a-z]/p" | grep -E "^[[:space:]]+${keys[2]}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  fi
  echo "$result"
}

# --- Config Check ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "not-run: Quality scoring is not configured."
  echo "Command: score-quality.sh"
  echo "Reason: .harness/scorecard.yml does not exist"
  echo "Risk: Cannot evaluate project harness quality or recommend mode/autonomy level"
  exit 2
fi

# --- Read Thresholds ---
BOOTSTRAP_MIN=$(read_yml_value "$CONFIG_FILE" "thresholds.bootstrap_min")
ENFORCED_MIN=$(read_yml_value "$CONFIG_FILE" "thresholds.enforced_min")
AUTONOMY_L3_MIN=$(read_yml_value "$CONFIG_FILE" "thresholds.autonomy_l3_min")
AUTONOMY_L4_MIN=$(read_yml_value "$CONFIG_FILE" "thresholds.autonomy_l4_min")

# Fallback defaults if config values are empty
BOOTSTRAP_MIN="${BOOTSTRAP_MIN:-60}"
ENFORCED_MIN="${ENFORCED_MIN:-80}"
AUTONOMY_L3_MIN="${AUTONOMY_L3_MIN:-85}"
AUTONOMY_L4_MIN="${AUTONOMY_L4_MIN:-92}"

# --- Read Dimension Weights ---
W_CONTEXT_READABILITY=$(read_yml_value "$CONFIG_FILE" "weights.context_readability")
W_PLAN_DISCIPLINE=$(read_yml_value "$CONFIG_FILE" "weights.plan_discipline")
W_ARCHITECTURE_ENFORCEMENT=$(read_yml_value "$CONFIG_FILE" "weights.architecture_enforcement")
W_TEST_CONFIDENCE=$(read_yml_value "$CONFIG_FILE" "weights.test_confidence")
W_OBSERVABILITY_SURFACE=$(read_yml_value "$CONFIG_FILE" "weights.observability_surface")
W_ENTROPY_CONTROL=$(read_yml_value "$CONFIG_FILE" "weights.entropy_control")
W_AUTONOMY_READINESS=$(read_yml_value "$CONFIG_FILE" "weights.autonomy_readiness")

# Fallback defaults
W_CONTEXT_READABILITY="${W_CONTEXT_READABILITY:-20}"
W_PLAN_DISCIPLINE="${W_PLAN_DISCIPLINE:-15}"
W_ARCHITECTURE_ENFORCEMENT="${W_ARCHITECTURE_ENFORCEMENT:-20}"
W_TEST_CONFIDENCE="${W_TEST_CONFIDENCE:-15}"
W_OBSERVABILITY_SURFACE="${W_OBSERVABILITY_SURFACE:-15}"
W_ENTROPY_CONTROL="${W_ENTROPY_CONTROL:-10}"
W_AUTONOMY_READINESS="${W_AUTONOMY_READINESS:-5}"

# --- Scoring State ---
declare -A CHECK_STATUS
declare -A CHECK_WEIGHT
declare -A CHECK_FIX
BLOCKING_ISSUES=()
WARNINGS=()
NOTRUN_ITEMS=()

# --- Check Evaluation Functions ---

# Record a check result
# Usage: record_check <dimension> <check_id> <status> <weight> [fix_message]
record_check() {
  local dimension="$1"
  local check_id="$2"
  local status="$3"
  local weight="$4"
  local fix="${5:-}"

  CHECK_STATUS["${dimension}.${check_id}"]="$status"
  CHECK_WEIGHT["${dimension}.${check_id}"]="$weight"
  CHECK_FIX["${dimension}.${check_id}"]="$fix"

  if [[ "$status" == "fail" ]]; then
    BLOCKING_ISSUES+=("${dimension}.${check_id}")
  elif [[ "$status" == "warn" ]]; then
    WARNINGS+=("${dimension}.${check_id}")
  elif [[ "$status" == "not-run" ]]; then
    NOTRUN_ITEMS+=("${dimension}.${check_id}")
  fi
}

# --- Dimension 1: Context Readability (20) ---
evaluate_context_readability() {
  local dim="context_readability"

  # nav_file_exists (weight: 4)
  if [[ -f "$PROJECT_ROOT/AGENTS.md" || -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    record_check "$dim" "nav_file_exists" "pass" 4
  else
    record_check "$dim" "nav_file_exists" "fail" 4 \
      "Create AGENTS.md or CLAUDE.md at project root"
  fi

  # nav_file_size (weight: 3) — must be < 200 lines
  local nav_file=""
  if [[ -f "$PROJECT_ROOT/AGENTS.md" ]]; then
    nav_file="$PROJECT_ROOT/AGENTS.md"
  elif [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    nav_file="$PROJECT_ROOT/CLAUDE.md"
  fi

  if [[ -n "$nav_file" ]]; then
    local line_count
    line_count=$(wc -l < "$nav_file" | tr -d '[:space:]')
    if [[ "$line_count" -lt 200 ]]; then
      record_check "$dim" "nav_file_size" "pass" 3
    else
      record_check "$dim" "nav_file_size" "warn" 3 \
        "Navigation file has $line_count lines (limit: 200). Move details to docs/"
    fi
  else
    record_check "$dim" "nav_file_size" "not-run" 3 \
      "Cannot check size — navigation file does not exist"
  fi

  # docs_discoverable (weight: 4)
  if [[ -d "$PROJECT_ROOT/docs" ]] && [[ -f "$PROJECT_ROOT/docs/README.md" || -f "$PROJECT_ROOT/docs/index.md" || $(find "$PROJECT_ROOT/docs" -maxdepth 1 -name "*.md" 2>/dev/null | head -1) ]]; then
    record_check "$dim" "docs_discoverable" "pass" 4
  elif [[ -d "$PROJECT_ROOT/docs" ]]; then
    record_check "$dim" "docs_discoverable" "warn" 4 \
      "docs/ exists but has no README.md or index file"
  else
    record_check "$dim" "docs_discoverable" "fail" 4 \
      "Create docs/ directory with README.md or index"
  fi

  # context_snapshot_exists (weight: 5)
  if [[ -f "$PROJECT_ROOT/docs/harness/context-snapshot.md" ]]; then
    # Check if recent (within 7 days)
    local snapshot_age=0
    if command -v stat >/dev/null 2>&1; then
      local mod_time
      mod_time=$(stat -c %Y "$PROJECT_ROOT/docs/harness/context-snapshot.md" 2>/dev/null || stat -f %m "$PROJECT_ROOT/docs/harness/context-snapshot.md" 2>/dev/null || echo "0")
      local now
      now=$(date +%s)
      snapshot_age=$(( (now - mod_time) / 86400 ))
    fi
    if [[ "$snapshot_age" -gt 7 ]]; then
      record_check "$dim" "context_snapshot_exists" "warn" 5 \
        "Context snapshot is ${snapshot_age} days old. Run scripts/harness/update-context-snapshot.sh"
    else
      record_check "$dim" "context_snapshot_exists" "pass" 5
    fi
  else
    record_check "$dim" "context_snapshot_exists" "not-run" 5 \
      "Run scripts/harness/update-context-snapshot.sh to generate context snapshot"
  fi

  # runtime_surface_documented (weight: 4)
  if [[ -f "$PROJECT_ROOT/.harness/runtime.yml" || -f "$PROJECT_ROOT/docs/runtime-surface.md" ]]; then
    record_check "$dim" "runtime_surface_documented" "pass" 4
  else
    record_check "$dim" "runtime_surface_documented" "not-run" 4 \
      "Configure .harness/runtime.yml or create docs/runtime-surface.md"
  fi
}

# --- Dimension 2: Plan Discipline (15) ---
evaluate_plan_discipline() {
  local dim="plan_discipline"

  # exec_plans_dir_exists (weight: 3)
  if [[ -d "$PROJECT_ROOT/docs/exec-plans/active" ]]; then
    record_check "$dim" "exec_plans_dir_exists" "pass" 3
  else
    record_check "$dim" "exec_plans_dir_exists" "fail" 3 \
      "Create docs/exec-plans/active/ directory for execution plans"
  fi

  # tech_debt_tracker_exists (weight: 3)
  if [[ -f "$PROJECT_ROOT/docs/exec-plans/tech-debt-tracker.md" ]]; then
    record_check "$dim" "tech_debt_tracker_exists" "pass" 3
  else
    record_check "$dim" "tech_debt_tracker_exists" "fail" 3 \
      "Create docs/exec-plans/tech-debt-tracker.md"
  fi

  # plans_have_status (weight: 3)
  if [[ -d "$PROJECT_ROOT/docs/exec-plans/active" ]]; then
    local plans_without_status=0
    local total_plans=0
    while IFS= read -r plan_file; do
      total_plans=$((total_plans + 1))
      if ! grep -qi "^status:" "$plan_file" 2>/dev/null; then
        plans_without_status=$((plans_without_status + 1))
      fi
    done < <(find "$PROJECT_ROOT/docs/exec-plans/active" -name "*.md" 2>/dev/null)

    if [[ "$total_plans" -eq 0 ]]; then
      record_check "$dim" "plans_have_status" "not-run" 3 \
        "No active plans found to check"
    elif [[ "$plans_without_status" -eq 0 ]]; then
      record_check "$dim" "plans_have_status" "pass" 3
    else
      record_check "$dim" "plans_have_status" "fail" 3 \
        "$plans_without_status of $total_plans active plans missing Status field"
    fi
  else
    record_check "$dim" "plans_have_status" "not-run" 3 \
      "docs/exec-plans/active/ does not exist"
  fi

  # pr_links_plan (weight: 3)
  # Check if MR template or integrations.yml has plan_link_required
  if [[ -f "$PROJECT_ROOT/.harness/integrations.yml" ]]; then
    local plan_link_req
    plan_link_req=$(read_yml_value "$PROJECT_ROOT/.harness/integrations.yml" "code_host.plan_link_required")
    if [[ "$plan_link_req" == "true" ]]; then
      record_check "$dim" "pr_links_plan" "pass" 3
    else
      record_check "$dim" "pr_links_plan" "warn" 3 \
        "Set code_host.plan_link_required: true in .harness/integrations.yml"
    fi
  else
    record_check "$dim" "pr_links_plan" "not-run" 3 \
      "Configure .harness/integrations.yml with plan_link_required setting"
  fi

  # blocked_plans_documented (weight: 3)
  if [[ -d "$PROJECT_ROOT/docs/exec-plans/active" ]]; then
    local blocked_undocumented=0
    while IFS= read -r plan_file; do
      if grep -qi "status:.*blocked" "$plan_file" 2>/dev/null; then
        if ! grep -qi "blocked.*reason\|superseded.by\|blocking.*reason" "$plan_file" 2>/dev/null; then
          blocked_undocumented=$((blocked_undocumented + 1))
        fi
      fi
    done < <(find "$PROJECT_ROOT/docs/exec-plans/active" -name "*.md" 2>/dev/null)

    if [[ "$blocked_undocumented" -gt 0 ]]; then
      record_check "$dim" "blocked_plans_documented" "fail" 3 \
        "$blocked_undocumented blocked plans lack documented blocking reason"
    else
      record_check "$dim" "blocked_plans_documented" "pass" 3
    fi
  else
    record_check "$dim" "blocked_plans_documented" "not-run" 3 \
      "docs/exec-plans/active/ does not exist"
  fi
}

# --- Dimension 3: Architecture Enforcement (20) ---
evaluate_architecture_enforcement() {
  local dim="architecture_enforcement"

  # boundaries_doc_exists (weight: 4)
  if [[ -f "$PROJECT_ROOT/docs/architecture-boundaries.md" ]]; then
    record_check "$dim" "boundaries_doc_exists" "pass" 4
  else
    record_check "$dim" "boundaries_doc_exists" "fail" 4 \
      "Create docs/architecture-boundaries.md defining module boundaries"
  fi

  # boundary_script_exists (weight: 4)
  if [[ -f "$PROJECT_ROOT/scripts/harness/check-boundaries.sh" ]]; then
    record_check "$dim" "boundary_script_exists" "pass" 4
  else
    record_check "$dim" "boundary_script_exists" "fail" 4 \
      "Create scripts/harness/check-boundaries.sh to enforce architecture boundaries"
  fi

  # boundary_gate_passes (weight: 6)
  if [[ -f "$PROJECT_ROOT/scripts/harness/check-boundaries.sh" ]]; then
    if [[ -x "$PROJECT_ROOT/scripts/harness/check-boundaries.sh" ]]; then
      local gate_output
      if gate_output=$("$PROJECT_ROOT/scripts/harness/check-boundaries.sh" 2>&1); then
        record_check "$dim" "boundary_gate_passes" "pass" 6
      else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
          record_check "$dim" "boundary_gate_passes" "not-run" 6 \
            "Boundary check returned not-run: $(echo "$gate_output" | head -1)"
        else
          record_check "$dim" "boundary_gate_passes" "fail" 6 \
            "Boundary gate check failed. Run scripts/harness/check-boundaries.sh for details"
        fi
      fi
    else
      record_check "$dim" "boundary_gate_passes" "not-run" 6 \
        "scripts/harness/check-boundaries.sh is not executable"
    fi
  else
    record_check "$dim" "boundary_gate_passes" "not-run" 6 \
      "scripts/harness/check-boundaries.sh does not exist"
  fi

  # no_forbidden_imports (weight: 6)
  # Check if boundaries doc defines forbidden imports and if any exist
  if [[ -f "$PROJECT_ROOT/docs/architecture-boundaries.md" ]]; then
    # Look for forbidden import patterns in the boundaries doc
    local forbidden_patterns
    forbidden_patterns=$(grep -i "forbidden\|prohibited\|not.allowed" "$PROJECT_ROOT/docs/architecture-boundaries.md" 2>/dev/null | grep -oE "'[^']+'" | tr -d "'" || true)

    if [[ -z "$forbidden_patterns" ]]; then
      # No explicit forbidden patterns defined — pass if boundaries doc exists
      record_check "$dim" "no_forbidden_imports" "pass" 6
    else
      # Check source files for forbidden patterns
      local violations=0
      while IFS= read -r pattern; do
        if [[ -n "$pattern" ]]; then
          local found
          found=$(grep -r "$pattern" "$PROJECT_ROOT/src" "$PROJECT_ROOT/apps" "$PROJECT_ROOT/packages" 2>/dev/null | grep -v "node_modules" | head -5 || true)
          if [[ -n "$found" ]]; then
            violations=$((violations + 1))
          fi
        fi
      done <<< "$forbidden_patterns"

      if [[ "$violations" -eq 0 ]]; then
        record_check "$dim" "no_forbidden_imports" "pass" 6
      else
        record_check "$dim" "no_forbidden_imports" "fail" 6 \
          "$violations forbidden import patterns detected. Check docs/architecture-boundaries.md"
      fi
    fi
  else
    record_check "$dim" "no_forbidden_imports" "not-run" 6 \
      "Cannot check imports — docs/architecture-boundaries.md does not exist"
  fi
}

# --- Dimension 4: Test Confidence (15) ---
evaluate_test_confidence() {
  local dim="test_confidence"

  # test_command_configured (weight: 3)
  if [[ -f "$PROJECT_ROOT/.harness/runtime.yml" ]]; then
    local test_cmd
    test_cmd=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "runtime.checks.test")
    # Fallback: try 2-level key in case structure is flat
    if [[ -z "$test_cmd" ]]; then
      test_cmd=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "checks.test")
    fi
    if [[ -n "$test_cmd" && "$test_cmd" != "TODO: 待补充" && "$test_cmd" != "TODO:待补充" && "$test_cmd" != "TODO" ]]; then
      record_check "$dim" "test_command_configured" "pass" 3
    else
      record_check "$dim" "test_command_configured" "fail" 3 \
        "Set runtime.checks.test in .harness/runtime.yml"
    fi
  else
    record_check "$dim" "test_command_configured" "not-run" 3 \
      "Configure .harness/runtime.yml with test command"
  fi

  # tests_pass (weight: 4)
  if [[ -f "$PROJECT_ROOT/.harness/runtime.yml" ]]; then
    local test_cmd
    test_cmd=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "runtime.checks.test")
    if [[ -z "$test_cmd" ]]; then
      test_cmd=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "checks.test")
    fi
    if [[ -n "$test_cmd" && "$test_cmd" != "TODO: 待补充" && "$test_cmd" != "TODO:待补充" && "$test_cmd" != "TODO" ]]; then
      # Try to run the test command
      if eval "$test_cmd" >/dev/null 2>&1; then
        record_check "$dim" "tests_pass" "pass" 4
      else
        record_check "$dim" "tests_pass" "fail" 4 \
          "Test suite fails. Run: $test_cmd"
      fi
    else
      record_check "$dim" "tests_pass" "not-run" 4 \
        "Test command not configured in .harness/runtime.yml"
    fi
  else
    record_check "$dim" "tests_pass" "not-run" 4 \
      "Cannot run tests — .harness/runtime.yml does not exist"
  fi

  # fixtures_exist (weight: 3)
  if [[ -d "$PROJECT_ROOT/fixtures" ]] || [[ -d "$PROJECT_ROOT/tests/fixtures" ]] || [[ -d "$PROJECT_ROOT/test/fixtures" ]]; then
    record_check "$dim" "fixtures_exist" "pass" 3
  else
    record_check "$dim" "fixtures_exist" "fail" 3 \
      "Create test fixtures directory (fixtures/ or tests/fixtures/)"
  fi

  # golden_tests_pass (weight: 3)
  if [[ -f "$PROJECT_ROOT/tests/assert-golden.sh" ]]; then
    if [[ -x "$PROJECT_ROOT/tests/assert-golden.sh" ]]; then
      if "$PROJECT_ROOT/tests/assert-golden.sh" >/dev/null 2>&1; then
        record_check "$dim" "golden_tests_pass" "pass" 3
      else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
          record_check "$dim" "golden_tests_pass" "not-run" 3 \
            "Golden tests returned not-run"
        else
          record_check "$dim" "golden_tests_pass" "fail" 3 \
            "Golden baseline tests fail. Run tests/assert-golden.sh for details"
        fi
      fi
    else
      record_check "$dim" "golden_tests_pass" "not-run" 3 \
        "tests/assert-golden.sh is not executable"
    fi
  else
    record_check "$dim" "golden_tests_pass" "not-run" 3 \
      "Create tests/assert-golden.sh for baseline comparison testing"
  fi

  # ci_runs_tests (weight: 2)
  local ci_has_tests=false
  if [[ -f "$PROJECT_ROOT/.github/workflows/harness.yml" ]]; then
    if grep -qi "test\|npm test\|yarn test\|pnpm test" "$PROJECT_ROOT/.github/workflows/harness.yml" 2>/dev/null; then
      ci_has_tests=true
    fi
  fi
  if [[ -f "$PROJECT_ROOT/.gitlab-ci.yml" ]]; then
    if grep -qi "test\|npm test\|yarn test\|pnpm test" "$PROJECT_ROOT/.gitlab-ci.yml" 2>/dev/null; then
      ci_has_tests=true
    fi
  fi

  if [[ "$ci_has_tests" == "true" ]]; then
    record_check "$dim" "ci_runs_tests" "pass" 2
  elif [[ -f "$PROJECT_ROOT/.github/workflows/harness.yml" || -f "$PROJECT_ROOT/.gitlab-ci.yml" ]]; then
    record_check "$dim" "ci_runs_tests" "warn" 2 \
      "CI config exists but does not appear to run tests"
  else
    record_check "$dim" "ci_runs_tests" "not-run" 2 \
      "No CI configuration found. Add test job to CI pipeline"
  fi
}

# --- Dimension 5: Observability Surface (15) ---
evaluate_observability_surface() {
  local dim="observability_surface"

  # observability_yml_exists (weight: 3)
  if [[ -f "$PROJECT_ROOT/.harness/observability.yml" ]]; then
    record_check "$dim" "observability_yml_exists" "pass" 3
  else
    record_check "$dim" "observability_yml_exists" "fail" 3 \
      "Create .harness/observability.yml with logs/metrics/traces provider config"
  fi

  # query_logs_works (weight: 3)
  if [[ -f "$PROJECT_ROOT/scripts/harness/query-logs.sh" && -x "$PROJECT_ROOT/scripts/harness/query-logs.sh" ]]; then
    local log_output
    log_output=$("$PROJECT_ROOT/scripts/harness/query-logs.sh" --since 1h 2>&1) || true
    if echo "$log_output" | grep -q "^not-run:"; then
      record_check "$dim" "query_logs_works" "not-run" 3 \
        "Log query returned not-run. Configure logs provider in .harness/observability.yml"
    elif echo "$log_output" | grep -q "^Error:"; then
      record_check "$dim" "query_logs_works" "fail" 3 \
        "Log query failed. Check provider configuration"
    else
      record_check "$dim" "query_logs_works" "pass" 3
    fi
  else
    record_check "$dim" "query_logs_works" "not-run" 3 \
      "scripts/harness/query-logs.sh does not exist or is not executable"
  fi

  # query_metrics_works (weight: 3)
  if [[ -f "$PROJECT_ROOT/scripts/harness/query-metrics.sh" && -x "$PROJECT_ROOT/scripts/harness/query-metrics.sh" ]]; then
    local metrics_output
    metrics_output=$("$PROJECT_ROOT/scripts/harness/query-metrics.sh" --query 'up' --range 5m 2>&1) || true
    if echo "$metrics_output" | grep -q "^not-run:"; then
      record_check "$dim" "query_metrics_works" "not-run" 3 \
        "Metrics query returned not-run. Configure metrics provider in .harness/observability.yml"
    elif echo "$metrics_output" | grep -q "^Error:"; then
      record_check "$dim" "query_metrics_works" "fail" 3 \
        "Metrics query failed. Check provider configuration"
    else
      record_check "$dim" "query_metrics_works" "pass" 3
    fi
  else
    record_check "$dim" "query_metrics_works" "not-run" 3 \
      "scripts/harness/query-metrics.sh does not exist or is not executable"
  fi

  # ui_verification_configured (weight: 3)
  if [[ -f "$PROJECT_ROOT/.harness/runtime.yml" ]]; then
    local ui_provider
    ui_provider=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "runtime.ui.provider")
    if [[ -z "$ui_provider" ]]; then
      ui_provider=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "ui.provider")
    fi
    if [[ -n "$ui_provider" && "$ui_provider" != "not-configured" ]]; then
      record_check "$dim" "ui_verification_configured" "pass" 3
    else
      record_check "$dim" "ui_verification_configured" "not-run" 3 \
        "Set ui.provider in .harness/runtime.yml (e.g. playwright)"
    fi
  else
    record_check "$dim" "ui_verification_configured" "not-run" 3 \
      "Configure .harness/runtime.yml with ui.provider setting"
  fi

  # health_check_works (weight: 3)
  if [[ -f "$PROJECT_ROOT/.harness/runtime.yml" ]]; then
    local health_check
    health_check=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "runtime.dev.health_check")
    if [[ -z "$health_check" ]]; then
      health_check=$(read_yml_value "$PROJECT_ROOT/.harness/runtime.yml" "dev.health_check")
    fi
    if [[ -n "$health_check" && "$health_check" != "TODO: 待补充" && "$health_check" != "TODO:待补充" && "$health_check" != "TODO" ]]; then
      # Try the health check (with short timeout)
      if eval "$health_check" >/dev/null 2>&1; then
        record_check "$dim" "health_check_works" "pass" 3
      else
        record_check "$dim" "health_check_works" "warn" 3 \
          "Health check command failed (server may not be running): $health_check"
      fi
    else
      record_check "$dim" "health_check_works" "not-run" 3 \
        "Configure runtime.dev.health_check in .harness/runtime.yml"
    fi
  else
    record_check "$dim" "health_check_works" "not-run" 3 \
      "Configure .harness/runtime.yml with dev.health_check"
  fi
}

# --- Dimension 6: Entropy Control (10) ---
evaluate_entropy_control() {
  local dim="entropy_control"

  # entropy_gc_exists (weight: 2)
  if [[ -f "$PROJECT_ROOT/docs/entropy-gc.md" ]]; then
    record_check "$dim" "entropy_gc_exists" "pass" 2
  else
    record_check "$dim" "entropy_gc_exists" "fail" 2 \
      "Create docs/entropy-gc.md documenting entropy management strategy"
  fi

  # doc_gardening_configured (weight: 3)
  local gardening_configured=false
  if [[ -f "$PROJECT_ROOT/docs/harness/doc-gardening-report.md" ]]; then
    gardening_configured=true
  fi
  if [[ -f "$PROJECT_ROOT/.harness/gates.yml" ]]; then
    if grep -qi "gardening\|doc-garden" "$PROJECT_ROOT/.harness/gates.yml" 2>/dev/null; then
      gardening_configured=true
    fi
  fi

  if [[ "$gardening_configured" == "true" ]]; then
    record_check "$dim" "doc_gardening_configured" "pass" 3
  else
    record_check "$dim" "doc_gardening_configured" "not-run" 3 \
      "Configure doc gardening schedule or create docs/harness/doc-gardening-report.md"
  fi

  # no_expired_adr_exceptions (weight: 3)
  local adr_exceptions_dir="$PROJECT_ROOT/docs/decisions/ADR-exceptions"
  if [[ -d "$adr_exceptions_dir" ]]; then
    local expired_count=0
    local today
    today=$(date +%Y-%m-%d)
    while IFS= read -r exception_file; do
      local expiry
      expiry=$(grep -i "^expir\|^expires\|^expiry" "$exception_file" 2>/dev/null | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1 || true)
      if [[ -n "$expiry" && "$expiry" < "$today" ]]; then
        expired_count=$((expired_count + 1))
      fi
    done < <(find "$adr_exceptions_dir" -name "*.md" 2>/dev/null)

    if [[ "$expired_count" -eq 0 ]]; then
      record_check "$dim" "no_expired_adr_exceptions" "pass" 3
    else
      record_check "$dim" "no_expired_adr_exceptions" "fail" 3 \
        "$expired_count ADR exceptions are past expiry date. Remove or renew them"
    fi
  else
    # No exceptions dir means no expired exceptions — pass
    record_check "$dim" "no_expired_adr_exceptions" "pass" 3
  fi

  # drift_detection_active (weight: 2)
  local drift_active=false
  if [[ -f "$PROJECT_ROOT/tests/assert-golden.sh" ]]; then
    drift_active=true
  fi
  if [[ -d "$PROJECT_ROOT/tests/golden" ]]; then
    drift_active=true
  fi
  if [[ -f "$PROJECT_ROOT/tests/run-fixtures.sh" ]]; then
    drift_active=true
  fi

  if [[ "$drift_active" == "true" ]]; then
    record_check "$dim" "drift_detection_active" "pass" 2
  else
    record_check "$dim" "drift_detection_active" "not-run" 2 \
      "Enable drift detection via golden tests or structure tests"
  fi
}

# --- Dimension 7: Autonomy Readiness (5) ---
evaluate_autonomy_readiness() {
  local dim="autonomy_readiness"

  # autonomy_yml_exists (weight: 1)
  if [[ -f "$PROJECT_ROOT/.harness/autonomy.yml" ]]; then
    record_check "$dim" "autonomy_yml_exists" "pass" 1
  else
    record_check "$dim" "autonomy_yml_exists" "not-run" 1 \
      "Create .harness/autonomy.yml with autonomy level configuration"
  fi

  # agent_autonomy_doc_exists (weight: 1)
  if [[ -f "$PROJECT_ROOT/docs/agent-autonomy.md" ]]; then
    record_check "$dim" "agent_autonomy_doc_exists" "pass" 1
  else
    record_check "$dim" "agent_autonomy_doc_exists" "not-run" 1 \
      "Create docs/agent-autonomy.md documenting autonomy policies"
  fi

  # l2_criteria_met (weight: 2)
  # L2 requires: enforced_min score with passing gates
  # We check this after computing the total score — use a placeholder for now
  # This will be re-evaluated after all other dimensions are scored
  record_check "$dim" "l2_criteria_met" "not-run" 2 \
    "Achieve enforced_min score ($ENFORCED_MIN) with all critical gates passing"

  # approval_workflows_defined (weight: 1)
  if [[ -f "$PROJECT_ROOT/.harness/integrations.yml" ]]; then
    if grep -qi "approval_required_for" "$PROJECT_ROOT/.harness/integrations.yml" 2>/dev/null; then
      record_check "$dim" "approval_workflows_defined" "pass" 1
    else
      record_check "$dim" "approval_workflows_defined" "not-run" 1 \
        "Define approval_required_for in .harness/integrations.yml for dangerous operations"
    fi
  else
    record_check "$dim" "approval_workflows_defined" "not-run" 1 \
      "Configure .harness/integrations.yml with approval workflows"
  fi
}

# --- Score Calculation ---
calculate_dimension_score() {
  local dimension="$1"
  local max_score="$2"
  local deduction=0

  for key in "${!CHECK_STATUS[@]}"; do
    if [[ "$key" == "${dimension}."* ]]; then
      local status="${CHECK_STATUS[$key]}"
      local weight="${CHECK_WEIGHT[$key]}"

      case "$status" in
        fail)    deduction=$((deduction + weight)) ;;
        not-run) deduction=$((deduction + weight / 2)) ;;
        warn)    deduction=$((deduction + weight / 4)) ;;
        pass)    ;; # No deduction
      esac
    fi
  done

  local score=$((max_score - deduction))
  if [[ $score -lt 0 ]]; then
    score=0
  fi
  echo "$score"
}

# Collect non-pass check IDs for a dimension (for the breakdown line)
get_dimension_issues() {
  local dimension="$1"
  local issues=""

  for key in "${!CHECK_STATUS[@]}"; do
    if [[ "$key" == "${dimension}."* ]]; then
      local status="${CHECK_STATUS[$key]}"
      local check_id="${key#${dimension}.}"
      if [[ "$status" != "pass" ]]; then
        if [[ -n "$issues" ]]; then
          issues="$issues, $check_id"
        else
          issues="$check_id"
        fi
      fi
    fi
  done
  echo "$issues"
}

# Get mode recommendation based on score
get_mode_recommendation() {
  local score="$1"
  if [[ $score -ge $ENFORCED_MIN ]]; then
    echo "enforced"
  elif [[ $score -ge $BOOTSTRAP_MIN ]]; then
    echo "bootstrap"
  else
    echo "not ready"
  fi
}

# Get autonomy level based on score
get_autonomy_level() {
  local score="$1"
  if [[ $score -ge $AUTONOMY_L4_MIN ]]; then
    echo "L4"
  elif [[ $score -ge $AUTONOMY_L3_MIN ]]; then
    echo "L3"
  elif [[ $score -ge $ENFORCED_MIN ]]; then
    echo "L2"
  else
    echo "L1"
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# --- Run All Dimension Evaluations ---
evaluate_context_readability
evaluate_plan_discipline
evaluate_architecture_enforcement
evaluate_test_confidence
evaluate_observability_surface
evaluate_entropy_control
evaluate_autonomy_readiness

# --- Calculate Scores ---
SCORE_CONTEXT=$(calculate_dimension_score "context_readability" "$W_CONTEXT_READABILITY")
SCORE_PLAN=$(calculate_dimension_score "plan_discipline" "$W_PLAN_DISCIPLINE")
SCORE_ARCH=$(calculate_dimension_score "architecture_enforcement" "$W_ARCHITECTURE_ENFORCEMENT")
SCORE_TEST=$(calculate_dimension_score "test_confidence" "$W_TEST_CONFIDENCE")
SCORE_OBS=$(calculate_dimension_score "observability_surface" "$W_OBSERVABILITY_SURFACE")
SCORE_ENTROPY=$(calculate_dimension_score "entropy_control" "$W_ENTROPY_CONTROL")
SCORE_AUTONOMY=$(calculate_dimension_score "autonomy_readiness" "$W_AUTONOMY_READINESS")

TOTAL_SCORE=$((SCORE_CONTEXT + SCORE_PLAN + SCORE_ARCH + SCORE_TEST + SCORE_OBS + SCORE_ENTROPY + SCORE_AUTONOMY))

# --- Re-evaluate l2_criteria_met based on total score ---
if [[ $TOTAL_SCORE -ge $ENFORCED_MIN ]]; then
  # Check if there are any blocking issues (fail status)
  if [[ ${#BLOCKING_ISSUES[@]} -eq 0 ]]; then
    CHECK_STATUS["autonomy_readiness.l2_criteria_met"]="pass"
    CHECK_FIX["autonomy_readiness.l2_criteria_met"]=""
    # Remove from NOTRUN_ITEMS
    NEW_NOTRUN=()
    for item in "${NOTRUN_ITEMS[@]}"; do
      if [[ "$item" != "autonomy_readiness.l2_criteria_met" ]]; then
        NEW_NOTRUN+=("$item")
      fi
    done
    NOTRUN_ITEMS=("${NEW_NOTRUN[@]}")
    # Recalculate autonomy score
    SCORE_AUTONOMY=$(calculate_dimension_score "autonomy_readiness" "$W_AUTONOMY_READINESS")
    TOTAL_SCORE=$((SCORE_CONTEXT + SCORE_PLAN + SCORE_ARCH + SCORE_TEST + SCORE_OBS + SCORE_ENTROPY + SCORE_AUTONOMY))
  fi
fi

# --- Determine Recommendations ---
MODE_REC=$(get_mode_recommendation "$TOTAL_SCORE")
AUTONOMY_REC=$(get_autonomy_level "$TOTAL_SCORE")

# --- Output ---
if [[ "$OUTPUT_QUIET" == "true" ]]; then
  echo "$TOTAL_SCORE"
  exit 0
fi

if [[ "$OUTPUT_JSON" == "true" ]]; then
  cat <<EOF
{
  "total_score": $TOTAL_SCORE,
  "mode": "$MODE_REC",
  "autonomy": "$AUTONOMY_REC",
  "dimensions": {
    "context_readability": { "score": $SCORE_CONTEXT, "max": $W_CONTEXT_READABILITY },
    "plan_discipline": { "score": $SCORE_PLAN, "max": $W_PLAN_DISCIPLINE },
    "architecture_enforcement": { "score": $SCORE_ARCH, "max": $W_ARCHITECTURE_ENFORCEMENT },
    "test_confidence": { "score": $SCORE_TEST, "max": $W_TEST_CONFIDENCE },
    "observability_surface": { "score": $SCORE_OBS, "max": $W_OBSERVABILITY_SURFACE },
    "entropy_control": { "score": $SCORE_ENTROPY, "max": $W_ENTROPY_CONTROL },
    "autonomy_readiness": { "score": $SCORE_AUTONOMY, "max": $W_AUTONOMY_READINESS }
  },
  "blocking_issues_count": ${#BLOCKING_ISSUES[@]},
  "thresholds": {
    "bootstrap_min": $BOOTSTRAP_MIN,
    "enforced_min": $ENFORCED_MIN,
    "autonomy_l3_min": $AUTONOMY_L3_MIN,
    "autonomy_l4_min": $AUTONOMY_L4_MIN
  }
}
EOF
  exit 0
fi

# --- Human-Readable Output ---
echo "=== Harness Quality Score ==="
echo "Total: ${TOTAL_SCORE}/100"

# Mode suggestion with threshold context
case "$MODE_REC" in
  "not ready")
    echo "Mode: not ready (bootstrap requires ${BOOTSTRAP_MIN}+)" ;;
  "bootstrap")
    echo "Mode: bootstrap (enforced requires ${ENFORCED_MIN}+)" ;;
  "enforced")
    echo "Mode: enforced" ;;
esac

# Autonomy suggestion with threshold context
case "$AUTONOMY_REC" in
  "L1") echo "Autonomy: L1 (L2 requires ${ENFORCED_MIN}+)" ;;
  "L2") echo "Autonomy: L2 (L3 requires ${AUTONOMY_L3_MIN}+)" ;;
  "L3") echo "Autonomy: L3 (L4 requires ${AUTONOMY_L4_MIN}+)" ;;
  "L4") echo "Autonomy: L4 (full autonomous)" ;;
esac

echo ""
echo "--- Dimension Breakdown ---"

# Helper to format dimension line
print_dimension() {
  local name="$1"
  local score="$2"
  local max="$3"
  local issues
  issues=$(get_dimension_issues "$name")

  # Pad dimension name for alignment
  local padded_name
  padded_name=$(printf "%-30s" "$name:")

  if [[ -n "$issues" ]]; then
    # Determine the worst status for the issue label
    local has_fail=false
    local has_notrun=false
    local has_warn=false
    for key in "${!CHECK_STATUS[@]}"; do
      if [[ "$key" == "${name}."* ]]; then
        case "${CHECK_STATUS[$key]}" in
          fail) has_fail=true ;;
          not-run) has_notrun=true ;;
          warn) has_warn=true ;;
        esac
      fi
    done

    local issue_labels=""
    for key in "${!CHECK_STATUS[@]}"; do
      if [[ "$key" == "${name}."* && "${CHECK_STATUS[$key]}" != "pass" ]]; then
        local check_id="${key#${name}.}"
        local status="${CHECK_STATUS[$key]}"
        if [[ -n "$issue_labels" ]]; then
          issue_labels="$issue_labels, ${status}: ${check_id}"
        else
          issue_labels="${status}: ${check_id}"
        fi
      fi
    done

    echo "${padded_name} ${score}/${max}  (${issue_labels})"
  else
    echo "${padded_name} ${score}/${max}"
  fi
}

print_dimension "context_readability" "$SCORE_CONTEXT" "$W_CONTEXT_READABILITY"
print_dimension "plan_discipline" "$SCORE_PLAN" "$W_PLAN_DISCIPLINE"
print_dimension "architecture_enforcement" "$SCORE_ARCH" "$W_ARCHITECTURE_ENFORCEMENT"
print_dimension "test_confidence" "$SCORE_TEST" "$W_TEST_CONFIDENCE"
print_dimension "observability_surface" "$SCORE_OBS" "$W_OBSERVABILITY_SURFACE"
print_dimension "entropy_control" "$SCORE_ENTROPY" "$W_ENTROPY_CONTROL"
print_dimension "autonomy_readiness" "$SCORE_AUTONOMY" "$W_AUTONOMY_READINESS"

# --- Blocking Issues ---
if [[ ${#BLOCKING_ISSUES[@]} -gt 0 ]]; then
  echo ""
  echo "--- Blocking Issues ---"
  ISSUE_NUM=1
  for issue_key in "${BLOCKING_ISSUES[@]}"; do
    FIX="${CHECK_FIX[$issue_key]:-No fix recommendation available}"
    echo "${ISSUE_NUM}. ${issue_key}"
    echo "   Reason: ${FIX}"

    # Determine docs reference based on dimension
    DIMENSION="${issue_key%%.*}"
    DOCS_REF=""
    case "$DIMENSION" in
      context_readability) DOCS_REF="references/nav-templates.md" ;;
      plan_discipline) DOCS_REF="references/exec-plan-templates.md" ;;
      architecture_enforcement) DOCS_REF="references/quality-gates.md" ;;
      test_confidence) DOCS_REF="references/regression-fixtures.md" ;;
      observability_surface) DOCS_REF="references/observability-runtime.md" ;;
      entropy_control) DOCS_REF="references/gc-templates.md" ;;
      autonomy_readiness) DOCS_REF="references/agent-autonomy.md" ;;
    esac
    if [[ -n "$DOCS_REF" ]]; then
      echo "   Fix: ${FIX}"
      echo "   Docs: ${DOCS_REF}"
    fi
    echo ""
    ISSUE_NUM=$((ISSUE_NUM + 1))
  done
fi

# --- Next Actions ---
echo ""
echo "--- Next Actions ---"
ACTION_NUM=1

# Prioritize blocking issues first
for issue_key in "${BLOCKING_ISSUES[@]}"; do
  if [[ $ACTION_NUM -gt 5 ]]; then break; fi
  FIX="${CHECK_FIX[$issue_key]:-Fix ${issue_key}}"
  echo "${ACTION_NUM}. ${FIX}"
  ACTION_NUM=$((ACTION_NUM + 1))
done

# Then not-run items
for issue_key in "${NOTRUN_ITEMS[@]}"; do
  if [[ $ACTION_NUM -gt 5 ]]; then break; fi
  FIX="${CHECK_FIX[$issue_key]:-Configure ${issue_key}}"
  echo "${ACTION_NUM}. ${FIX}"
  ACTION_NUM=$((ACTION_NUM + 1))
done

# Then warnings
for issue_key in "${WARNINGS[@]}"; do
  if [[ $ACTION_NUM -gt 5 ]]; then break; fi
  FIX="${CHECK_FIX[$issue_key]:-Address warning: ${issue_key}}"
  echo "${ACTION_NUM}. ${FIX}"
  ACTION_NUM=$((ACTION_NUM + 1))
done

if [[ $ACTION_NUM -eq 1 ]]; then
  echo "No actions needed — all checks pass!"
fi

exit 0
