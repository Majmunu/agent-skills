# Implementation Plan: harness-init v4 Upgrade

## Overview

Incrementally upgrade harness-init from v3 to v4 by adding self-test infrastructure, agent-readable runtime capabilities, observability/quality scoring, context snapshots, subagent workflows, external integrations, security boundaries, and assembling the updated SKILL.md. Implementation uses Bash/Shell scripts, PowerShell for Windows fallback, YAML configs, and Markdown templates. All work is additive — existing v3 structure is preserved.

## Tasks

- [x] 1. Phase 1: Self-Test Infrastructure (Fixtures + Tests)
  - [x] 1.1 Create fixture directory structure with 8 scenarios
    - Create `fixtures/single-node-ts/` with package.json, tsconfig.json, src/index.ts
    - Create `fixtures/pnpm-monorepo/` with pnpm-workspace.yaml, root package.json, apps/editor/package.json, packages/ui/package.json
    - Create `fixtures/nested-project/` with parent/child project structure
    - Create `fixtures/polluted-root-nav/` with intentionally polluted AGENTS.md containing `cd apps/editor && npm run dev`
    - Create `fixtures/unknown-stack/` with minimal unrecognizable project structure
    - Create `fixtures/existing-claude-only/` with pre-existing CLAUDE.md but no AGENTS.md
    - Create `fixtures/legacy-docs-drift/` with v2 marker blocks and drifted legacy docs
    - Create `fixtures/windows-no-bash/` with PowerShell-only environment markers
    - _Requirements: 1.1, 1.4, 1.5, 1.6, 21.1_

  - [x] 1.2 Create `tests/run-fixtures.sh` test runner script
    - Implement copy-to-temp, dry-run, init, re-init workflow per fixture
    - Output pass/fail per fixture with structured failure info (Reason, Evidence, Fix, Docs)
    - Ensure script is executable and uses `#!/usr/bin/env bash`
    - _Requirements: 1.2, 1.3_

  - [x] 1.3 Create `tests/assert-idempotent.sh` idempotency checker
    - Verify no duplicate marker blocks after second run
    - Verify no duplicate package.json scripts entries
    - Verify no duplicate docs sections
    - Output pass when second-run file content matches first-run exactly
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 1.4 Create `tests/assert-root-nav-clean.sh` root navigation cleanliness checker
    - Detect `cd apps/` or `cd packages/` patterns in root navigation files
    - Detect project-specific env vars or database configs
    - Output fail with specific line numbers on violation
    - Output pass when only global rules, repo layout, and project index present
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 1.5 Create `tests/assert-placeholder-gate.sh` placeholder checker
    - Scan all generated files for `<...>` angle-bracket placeholder patterns
    - Output fail on `<...>` patterns found
    - Mark `TODO`, `FIXME`, `TBD`, `待补充` as warn (not fail)
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [x] 1.6 Create `tests/golden/` baseline directory and `tests/assert-golden.sh` golden test script
    - Create golden baseline files for single-node-ts fixture (minimum)
    - Implement diff comparison between generated output and golden baselines
    - Output fail with specific diff content, file paths, and line numbers on mismatch
    - Support `--update` flag to refresh baselines
    - Ignore timestamps and dynamic IDs in comparisons
    - _Requirements: 24.1, 24.2, 24.3, 24.4, 24.5_

- [~] 2. Checkpoint - Phase 1 complete
  - Ensure all test scripts are syntactically valid (shellcheck if available), ask the user if questions arise.

- [x] 3. Phase 2: Agent-Readable Runtime (Worktree, UI Verification, Runtime Surface)
  - [x] 3.1 Create `scripts/harness/worktree-create.sh` worktree creation script
    - Accept `<task-id>` and `<branch>` arguments
    - Create git worktree at `.worktrees/harness-<task-id>`
    - Warn (not overwrite) if path already exists, provide cleanup command
    - Refuse any operation that would delete main workspace content
    - _Requirements: 5.1, 5.2, 5.7_

  - [x] 3.2 Create `scripts/harness/worktree-clean.sh` worktree cleanup script
    - Only clean `.worktrees/harness-*` paths
    - Refuse cleanup if uncommitted changes exist (unless `--force`)
    - Refuse execution if target path is outside `.worktrees/`
    - _Requirements: 5.3, 5.4, 5.5_

  - [x] 3.3 Create `scripts/harness/worktree-run.sh` worktree command runner
    - Accept `<task-id>` and `<command>` arguments
    - Execute command in corresponding worktree
    - Capture stdout/stderr to `.harness/runs/<task-id>/`
    - _Requirements: 5.6_

  - [x] 3.4 Create UI verification scripts
    - Create `scripts/harness/capture-dom.sh` — capture DOM snapshot via Playwright when configured
    - Create `scripts/harness/capture-screenshot.sh` — capture page screenshot
    - Create `scripts/harness/check-console.sh` — check for console errors (with allowlist support)
    - Create `scripts/harness/verify-user-journey.sh` — execute user journey from `.harness/user-journeys/<name>.yml`
    - Output `not-run: UI verification backend is not configured.` when `ui.provider` is `not-configured`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 3.5 Create `.harness/runtime.yml` template and `references/runtime-surface.md`
    - Define runtime.yml schema: dev server command, health check URL, lint/test/typecheck/build commands, log paths, UI provider
    - Use `TODO: 待补充` for undetermined values, `not-configured` as default UI provider
    - Create `references/runtime-surface.md` reference documentation
    - Create `docs/runtime-surface.md` template for target projects
    - _Requirements: 19.1, 19.2, 19.3, 19.4_

- [~] 4. Checkpoint - Phase 2 complete
  - Ensure all scripts are syntactically valid, ask the user if questions arise.

- [x] 5. Phase 3: Observability + Quality Score
  - [x] 5.1 Create observability query scripts
    - Create `scripts/harness/query-logs.sh` with `--since`, `--level`, `--keyword` params
    - Create `scripts/harness/query-metrics.sh` with PromQL support (Prometheus/VictoriaMetrics)
    - Create `scripts/harness/query-traces.sh` with trace-id and service-name query support
    - Read provider config from `.harness/observability.yml`
    - Use grep/rg for `file` provider; output `not-run` when provider endpoint not configured
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 5.2 Create `.harness/observability.yml` template and `references/observability-runtime.md`
    - Define observability.yml schema: logs/metrics/traces providers and endpoints
    - Create `references/observability-runtime.md` reference documentation
    - _Requirements: 7.6, 21.5_

  - [x] 5.3 Create `scripts/harness/score-quality.sh` quality scoring script
    - Implement 7-dimension scoring: context_readability(20), plan_discipline(15), architecture_enforcement(20), test_confidence(15), observability_surface(15), entropy_control(10), autonomy_readiness(5)
    - Read config from `.harness/scorecard.yml`
    - Output current score, mode suggestion, autonomy level suggestion
    - List blocking issues with fix recommendations per dimension
    - Apply thresholds: bootstrap_min=60, enforced_min=80, autonomy_l3_min=85, autonomy_l4_min=92
    - Deduct points for unconfigured items (never give pass for unconfigured)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 5.4 Create `.harness/scorecard.yml` template and `references/scorecard-templates.md`
    - Define scorecard.yml schema with 7 dimensions, weights, and check items
    - Create `references/scorecard-templates.md` reference documentation
    - _Requirements: 8.1, 21.5_

- [~] 6. Checkpoint - Phase 3 complete
  - Ensure all scripts are syntactically valid, ask the user if questions arise.

- [ ] 7. Phase 4: Context Snapshot + Subagent Workflows
  - [x] 7.1 Create `scripts/harness/update-context-snapshot.sh` and context snapshot template
    - Scan active plans, completed plans, tech-debt-tracker, ADR exceptions, scorecard, autonomy config
    - Generate `docs/harness/context-snapshot.md` with: CI Mode, Autonomy Level, Quality Score, Active Plans, Recently Completed Plans, Open Tech Debts, Failing Gates, Active ADR Exceptions, Recent Incidents, Integration Status, Next Recommended Actions
    - Include `Last Updated` timestamp
    - Ensure snapshot is index-only (does not replace source documents)
    - Create `references/context-snapshot.md` reference documentation
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 21.5_

  - [x] 7.2 Create `subagents/routing-rules.yml` routing configuration
    - Define role routing rules based on `changed_paths` and `labels`
    - Support `blocking: true` to prevent merge until required roles complete review
    - Ensure consistency with existing `subagents/roles.json`
    - _Requirements: 10.1, 10.2, 10.3_

  - [~] 7.3 Create workflow definition files in `subagents/workflows/`
    - Create `subagents/workflows/feature-delivery.yml` — with ExecPlan check, lint/test/typecheck/build gates
    - Create `subagents/workflows/bug-fix.yml` — with repeat-issue hardening rule
    - Create `subagents/workflows/architecture-change.yml`
    - Create `subagents/workflows/schema-migration.yml`
    - Create `subagents/workflows/release.yml`
    - Each workflow includes: Trigger, Required Roles, Required Input/Output Artifacts, Required Gates, Skip Conditions, Completion Criteria
    - _Requirements: 10.4, 10.5, 10.6_

  - [~] 7.4 Create `subagents/review-rubrics/` review criteria files
    - Create `subagents/review-rubrics/architect.md`
    - Create `subagents/review-rubrics/editor-component.md`
    - Create `subagents/review-rubrics/runtime-dataflow.md`
    - Create `subagents/review-rubrics/quality-gate.md`
    - Create `subagents/review-rubrics/governance-context.md`
    - Each rubric includes: review scope, required check items, pass criteria, reject criteria
    - Ensure consistency with routing-rules.yml and roles.json
    - Create `references/subagent-workflows.md` reference documentation
    - _Requirements: 25.1, 25.2, 25.3, 25.4, 21.5_

- [~] 8. Checkpoint - Phase 4 complete
  - Ensure all workflow and routing files are valid YAML, ask the user if questions arise.

- [ ] 9. Phase 5: GitLab/YouTrack/MCP + Security
  - [x] 9.1 Create `.harness/integrations.yml` integration configuration template
    - Define code_host (GitLab), issue_tracker (YouTrack), and mcp sections
    - Use environment variable placeholders only (`GITLAB_TOKEN`, `YOUTRACK_TOKEN`) — never real tokens
    - Define MCP dangerous operations list: delete, force-push, production-deploy, permission-change, database-migration, secret-rotation
    - Create `references/mcp-integrations.md` reference documentation
    - _Requirements: 11.1, 11.2, 11.4, 21.5_

  - [~] 9.2 Create integration operation scripts
    - Create `scripts/harness/sync-issues.sh` — sync issue status from tracker to local plan files
    - Create `scripts/harness/link-plan-to-issue.sh` — bidirectional link between ExecPlan and issue
    - Create `scripts/harness/fetch-review-context.sh` — fetch MR/PR review context (comments, changed files, CI status)
    - Create `scripts/harness/create-merge-request.sh` — create MR with plan link and standard description template
    - All scripts output `not-run` with missing config details when token/base_url not configured
    - Auto-include ExecPlan path in MR description
    - _Requirements: 26.1, 26.2, 26.3, 26.4, 26.5, 26.6, 11.3_

  - [~] 9.3 Create `scripts/harness/check-secrets.sh` secret detection script
    - Detect `.env` tracked by git
    - Detect common token patterns (API keys, JWT, etc.)
    - Detect private key patterns
    - Detect hardcoded tokens in CI configs
    - Output fail with specific file and line number on detection
    - _Requirements: 12.2, 12.3_

  - [~] 9.4 Create `scripts/harness/check-permissions.sh` permission boundary checker
    - Verify dangerous operations in `.harness/integrations.yml` have approval policies configured
    - Block MCP dangerous operations until human approval obtained
    - Create `references/permission-boundaries.md` reference documentation
    - _Requirements: 12.4, 11.5, 21.5_

  - [~] 9.5 Create `docs/security-threat-model.md` template and `references/security-templates.md`
    - Include sections: Assets, Trust Boundaries, Secrets Handling, MCP Tool Boundaries, Dangerous Operations, Required Human Approval, Audit Trail, Incident Response
    - Create `references/security-templates.md` reference documentation
    - _Requirements: 12.1, 12.5, 21.5_

  - [~] 9.6 Create enhanced gate output format and `references/worktree-sandbox.md`, `references/ui-verification.md`
    - Update all gate scripts to output structured failure info: Reason, Evidence, Fix, Docs, Bypass
    - Prohibit bare `FAIL`/`error`/`not valid` messages without fix info
    - Ensure not-run states include: command not executed, reason, residual risk
    - In enforced mode: not-run on critical gates = fail (unless ADR exception)
    - In bootstrap mode: allow warn/not-run on non-critical, but security checks still block
    - Create `references/worktree-sandbox.md` and `references/ui-verification.md` reference docs
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 21.5_

- [~] 10. Checkpoint - Phase 5 complete
  - Ensure all scripts and YAML configs are syntactically valid, ask the user if questions arise.

- [ ] 11. Phase 6: CI Templates, PowerShell Fallback, Version Upgrade & SKILL.md Assembly
  - [~] 11.1 Create CI template files
    - Create `templates/.github/workflows/harness.yml` with jobs: harness-critical, harness-docs, harness-score, harness-security, harness-self-test
    - Create `templates/gitlab-ci/harness.gitlab-ci.yml` with stages: harness-preflight, harness-gates, harness-score, harness-security
    - Support `HARNESS_CI_MODE=bootstrap` (allow non-critical warn/not-run, block critical security)
    - Support `HARNESS_CI_MODE=enforced` (block critical gate warn/not-run)
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

  - [~] 11.2 Create PowerShell degraded-mode scripts in `templates/scripts/harness-pwsh/`
    - Create `self-test.ps1` — core self-test functionality
    - Create `score-quality.ps1` — quality scoring
    - Create `update-context-snapshot.ps1` — context snapshot update
    - Create `check-secrets.ps1` — secret detection
    - Create `check-permissions.ps1` — permission boundary check
    - Match bash output format (pass/fail/warn/not-run) and structured failure info
    - Output not-run with reason for checks not covered by PowerShell version
    - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5_

  - [~] 11.3 Create v2→v3 repair mode migration logic
    - Implement scanning for `Harness Init Contract Version: v2` blocks
    - Output migration suggestions: old block location, suggested v3 replacement, migration steps, risk notes
    - Never auto-delete v2 blocks — only migrate on explicit `repair apply`
    - Mark conflicts when v2 and v3 content overlap functionally
    - Provide keep/migrate/remove options per v2 block
    - _Requirements: 27.1, 27.2, 27.3, 27.4, 27.5, 15.3, 15.4_

  - [~] 11.4 Update SKILL.md with v4 changes
    - Update version from 3.0.0 to 4.0.0
    - Update Contract Version from v2 to v3 (new markers: `Harness Init Contract Version: v3`, `Generated/Updated by: harness-init`, `Scope: <root|project|nested-project>`)
    - Update Execution Flow to 10-step v4 flow (Steps 0, 1, 2, 2.5, 3, 4, 5, 5.5, 6, 7, 8, 9)
    - Add support for dry-run, apply, repair, degraded mode in each step
    - Update Reference Files table with all new references
    - Preserve all existing v3 content and policies
    - _Requirements: 15.1, 15.2, 15.5, 20.1, 20.2, 20.3_

  - [~] 11.5 Create `templates/scripts/harness/` directory with template versions of all new scripts
    - Copy/template all scripts from `scripts/harness/` into `templates/scripts/harness/`
    - These are the templates that harness-init will deploy to target projects
    - _Requirements: 21.3_

  - [~] 11.6 Ensure idempotency and monorepo isolation contracts in all new content
    - Verify all new scripts use read→compare→patch/append strategy
    - Verify package.json merge only adds missing scripts
    - Verify Makefile append only adds missing targets
    - Verify CI/hook files preserve existing jobs
    - Verify all generated blocks include scope info (root/project/nested-project)
    - Verify root navigation never contains `cd apps/xxx` project-level commands
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 17.1, 17.2, 17.3, 17.4, 17.5_

  - [~] 11.7 Ensure status semantics and init report output
    - Verify all scripts use only pass/fail/warn/not-run status identifiers
    - Verify not-run never masquerades as pass
    - Verify not-run records: command not executed, reason, residual risk
    - Create init report template covering: Summary, Generated Files, Modified Files, Skipped Files, Degraded Mode Items, Gate Results, Quality Score, Integration Status, Next Actions
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 22.1, 22.2, 22.3_

- [~] 12. Final Checkpoint - All phases complete
  - Ensure all tests pass (run `tests/run-fixtures.sh` if possible), verify directory structure matches requirements, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP (none in this plan — all tasks are core implementation)
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation between phases
- This is a Skill project — implementation creates templates, scripts, fixtures, and reference docs (not a typical application)
- All shell scripts should use `#!/usr/bin/env bash` and be marked executable
- All YAML files should be valid and parseable
- Existing v3 content in SKILL.md and references/ must be preserved (additive changes only)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "3.5", "5.2", "5.4"] },
    { "id": 1, "tasks": ["1.2", "1.3", "1.4", "1.5", "3.1", "3.2", "3.3", "5.1"] },
    { "id": 2, "tasks": ["1.6", "3.4", "5.3", "7.1", "7.2", "9.1"] },
    { "id": 3, "tasks": ["7.3", "7.4", "9.2", "9.3", "9.4", "9.5"] },
    { "id": 4, "tasks": ["9.6", "11.1", "11.2"] },
    { "id": 5, "tasks": ["11.3", "11.4", "11.5"] },
    { "id": 6, "tasks": ["11.6", "11.7"] }
  ]
}
```
