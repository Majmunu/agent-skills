# Scorecard Templates Reference

> Reference documentation for the harness quality scorecard system.
> Used by: `scripts/harness/score-quality.sh`
> Config: `.harness/scorecard.yml`

## Overview

The scorecard system quantifies project harness quality across 7 dimensions, producing a score from 0–100. This score drives mode recommendations (bootstrap vs enforced) and autonomy level suggestions (L1–L4).

## Scoring Dimensions

### 1. Context Readability (Weight: 20)

Measures how easily an agent can discover and understand the project context.

| Check ID | Description | Weight | How to Pass |
|---|---|---|---|
| `nav_file_exists` | Navigation file exists at root | 4 | Create AGENTS.md or CLAUDE.md at project root |
| `nav_file_size` | Navigation file < 200 lines | 3 | Keep navigation concise; move details to docs/ |
| `docs_discoverable` | docs/ directory is discoverable | 4 | Create docs/ with README.md or index |
| `context_snapshot_exists` | Context snapshot is present and recent | 5 | Run `scripts/harness/update-context-snapshot.sh` |
| `runtime_surface_documented` | Runtime surface is documented | 4 | Configure `.harness/runtime.yml` or create `docs/runtime-surface.md` |

**Why it matters:** Agents starting a new session need to quickly orient themselves. Poor context readability leads to wasted tokens re-discovering project structure.

---

### 2. Plan Discipline (Weight: 15)

Measures adherence to execution plan lifecycle and traceability.

| Check ID | Description | Weight | How to Pass |
|---|---|---|---|
| `exec_plans_dir_exists` | Active plans directory exists | 3 | Create `docs/exec-plans/active/` |
| `tech_debt_tracker_exists` | Tech debt tracker exists | 3 | Create `docs/exec-plans/tech-debt-tracker.md` |
| `plans_have_status` | Active plans contain Status field | 3 | Add `Status: in-progress` to all active plans |
| `pr_links_plan` | MR/PR descriptions link to plan | 3 | Include ExecPlan path in MR description template |
| `blocked_plans_documented` | Blocked plans have documented reasons | 3 | Add blocking reason and superseded-by references |

**Why it matters:** Without plan discipline, agents cannot determine what work is in progress, what is blocked, or what has been completed. This leads to duplicate work and conflicting changes.

---

### 3. Architecture Enforcement (Weight: 20)

Measures whether architectural boundaries are defined and actively enforced.

| Check ID | Description | Weight | How to Pass |
|---|---|---|---|
| `boundaries_doc_exists` | Architecture boundaries documented | 4 | Create `docs/architecture-boundaries.md` |
| `boundary_script_exists` | Boundary check script exists | 4 | Create `scripts/harness/check-boundaries.sh` |
| `boundary_gate_passes` | Boundary gate check passes | 6 | Fix all boundary violations detected by the gate |
| `no_forbidden_imports` | No forbidden cross-boundary imports | 6 | Remove or refactor forbidden import paths |

**Why it matters:** Architecture enforcement is the highest-weighted dimension because boundary violations compound over time and are expensive to fix. Automated enforcement prevents drift.

---

### 4. Test Confidence (Weight: 15)

Measures the reliability and coverage of the test infrastructure.

| Check ID | Description | Weight | How to Pass |
|---|---|---|---|
| `test_command_configured` | Test command in runtime.yml | 3 | Set `runtime.checks.test` in `.harness/runtime.yml` |
| `tests_pass` | Test suite passes | 4 | Fix failing tests |
| `fixtures_exist` | Test fixtures directory exists | 3 | Create fixture scenarios in `fixtures/` |
| `golden_tests_pass` | Golden baseline tests pass | 3 | Run `tests/assert-golden.sh --update` after intentional changes |
| `ci_runs_tests` | CI pipeline runs tests | 2 | Add test job to CI configuration |

**Why it matters:** Without passing tests, agents cannot verify that their changes are correct. Test confidence directly correlates with safe autonomous operation.

---

### 5. Observability Surface (Weight: 15)

Measures the ability to programmatically query logs, metrics, traces, and UI state.

| Check ID | Description | Weight | How to Pass |
|---|---|---|---|
| `observability_yml_exists` | Observability config exists | 3 | Create `.harness/observability.yml` |
| `query_logs_works` | Log queries return results | 3 | Configure logs provider and endpoint |
| `query_metrics_works` | Metrics queries return results | 3 | Configure metrics provider and endpoint |
| `ui_verification_configured` | UI verification is configured | 3 | Set `ui.provider` to `playwright` or similar |
| `health_check_works` | Health check responds | 3 | Configure `runtime.dev.health_check` URL |

**Why it matters:** Agents diagnosing issues need programmatic access to runtime signals. Without observability, debugging requires human intervention.

---

### 6. Entropy Control (Weight: 10)

Measures active management of documentation drift, stale exceptions, and AI-generated residue.

| Check ID | Description | Weight | How to Pass |
|---|---|---|---|
| `entropy_gc_exists` | Entropy GC documentation exists | 2 | Create `docs/entropy-gc.md` |
| `doc_gardening_configured` | Doc gardening is scheduled | 3 | Configure gardening automation or schedule |
| `no_expired_adr_exceptions` | No expired ADR exceptions | 3 | Remove or renew expired ADR exceptions |
| `drift_detection_active` | Drift detection is active | 2 | Enable golden tests or structure tests |

**Why it matters:** Without entropy control, documentation drifts from reality, exceptions accumulate without review, and AI-generated content degrades signal-to-noise ratio.

---

### 7. Autonomy Readiness (Weight: 5)

Measures preparedness for higher autonomy levels (L3/L4).

| Check ID | Description | Weight | How to Pass |
|---|---|---|---|
| `autonomy_yml_exists` | Autonomy config exists | 1 | Create `.harness/autonomy.yml` |
| `agent_autonomy_doc_exists` | Autonomy documentation exists | 1 | Create `docs/agent-autonomy.md` |
| `l2_criteria_met` | L2+ criteria satisfied | 2 | Achieve enforced_min score with passing gates |
| `approval_workflows_defined` | Approval workflows defined | 1 | Define approval policies for dangerous operations |

**Why it matters:** Autonomy readiness is the lowest-weighted dimension because it builds on all others. A project cannot safely operate at L3/L4 without the foundation of the other 6 dimensions.

---

## Thresholds

| Threshold | Score | Meaning |
|---|---|---|
| `bootstrap_min` | 60 | Minimum to operate in bootstrap mode (non-critical gates may warn) |
| `enforced_min` | 80 | Minimum to enter enforced mode (all critical gates must pass) |
| `autonomy_l3_min` | 85 | Minimum for L3 autonomy (supervised autonomous execution) |
| `autonomy_l4_min` | 92 | Minimum for L4 autonomy (full autonomous with rollback) |

### Mode Recommendations

Based on the total score, `score-quality.sh` outputs a mode recommendation:

- **Score < 60**: `not ready` — Project harness is incomplete. Focus on critical gaps.
- **Score 60–79**: `bootstrap` — Basic harness in place. Non-critical gates may warn/not-run.
- **Score 80–84**: `enforced` — Full harness active. All critical gates must pass.
- **Score 85–91**: `enforced + L3 autonomy` — Agent can execute supervised autonomous tasks.
- **Score 92–100**: `enforced + L4 autonomy` — Agent can execute fully autonomous with rollback.

### Autonomy Level Mapping

| Level | Score Required | Description |
|---|---|---|
| L1 | < 60 | Human-directed: Agent follows explicit instructions only |
| L2 | 60–84 | Human-supervised: Agent proposes, human approves |
| L3 | 85–91 | Supervised autonomous: Agent executes with monitoring |
| L4 | 92–100 | Full autonomous: Agent executes with rollback capability |

---

## Scoring Algorithm

```
For each dimension D:
  max_score = weights[D]
  
  For each check in dimension:
    if check.status == "fail":
      deduction += check.weight           # Full deduction
    elif check.status == "not-run":
      deduction += check.weight * 0.5     # 50% deduction (unknown ≠ pass)
    elif check.status == "warn":
      deduction += check.weight * 0.25    # 25% deduction
    elif check.status == "pass":
      deduction += 0                      # No deduction
  
  dimension_score = max(0, max_score - deduction)

total_score = sum(all dimension_scores)
```

### Key Rules

1. **Unconfigured items are never pass.** If a check cannot be evaluated because the tool/config is missing, it scores `not-run` (50% deduction).
2. **Weights within a dimension must sum to the dimension weight.** This ensures each check's contribution is proportional.
3. **Blocking issues are reported per dimension.** Any check with status `fail` is listed as a blocking issue with a fix recommendation.

---

## Output Format

`score-quality.sh` outputs the following structure:

```
=== Harness Quality Score ===
Total: 73/100
Mode: bootstrap (enforced requires 80+)
Autonomy: L2 (L3 requires 85+)

--- Dimension Breakdown ---
context_readability:       16/20  (warn: context_snapshot_exists)
plan_discipline:           12/15  (fail: pr_links_plan)
architecture_enforcement:  20/20
test_confidence:           10/15  (not-run: golden_tests_pass, ci_runs_tests)
observability_surface:      6/15  (not-run: query_metrics_works, ui_verification_configured, health_check_works)
entropy_control:            7/10  (warn: doc_gardening_configured)
autonomy_readiness:         2/5   (not-run: l2_criteria_met, approval_workflows_defined)

--- Blocking Issues ---
1. plan_discipline.pr_links_plan
   Reason: MR descriptions do not include ExecPlan path
   Fix: Add ExecPlan path to MR description template in .harness/integrations.yml
   Docs: references/exec-plan-templates.md

--- Next Actions ---
1. Configure context snapshot (run update-context-snapshot.sh)
2. Add ExecPlan link to MR template
3. Configure metrics provider in .harness/observability.yml
```

---

## Configuration File Location

The scorecard configuration lives at `.harness/scorecard.yml` in the target project root. It is generated by harness-init during Step 5.5 (Quality Score + CI Governance).

### Customization

Projects may adjust:
- **Weights**: Redistribute points across dimensions (must still sum to 100)
- **Thresholds**: Raise or lower mode/autonomy thresholds
- **Check items**: Add project-specific checks within a dimension

Projects must NOT:
- Remove dimensions entirely (all 7 must be present)
- Set thresholds below safe minimums (bootstrap_min < 40, enforced_min < 60)
- Assign weight 0 to security-related checks

---

## Integration with CI

The scorecard integrates with CI pipelines via the `harness-score` job:

- **bootstrap mode**: Score is informational. Warn if below `bootstrap_min`.
- **enforced mode**: Score below `enforced_min` blocks the pipeline.
- **autonomy gates**: Score below autonomy thresholds prevents autonomous operation escalation.

See `references/ci-governance.md` for CI pipeline configuration details.
