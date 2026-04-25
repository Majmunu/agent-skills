---
name: harness-init
description: 初始化或修复项目 harness 基础设施，包括 AGENTS.md/CLAUDE.md 导航文件、.harness/docs 事实源、任务级上下文包、执行计划、架构边界、CI 门禁、反馈闭环、熵治理与初始化报告。支持 Node/TypeScript、Python、Go、Rust、Java、Kotlin 与 monorepo。Use when the user asks to initialize, repair, migrate, or audit harness/agent infrastructure, bootstrap AGENTS.md or CLAUDE.md, create .harness docs scaffold, establish agent-ready engineering constraints, or improve harness-init itself.
---

# Harness Init

为项目建立可持续演化的 agent harness。目标不是堆叠 prompt，而是把上下文、约束、验证和治理写回仓库，并保持可检查、可回滚、可重复运行。

## Core Rules

- 先盘点现状，再初始化；不要覆盖已有 `AGENTS.md`、`CLAUDE.md`、`.harness/`、业务 docs、hooks 或 CI。
- 使用 Read -> compare -> patch/append 策略；重复运行不得产生重复 marker block。
- 导航文件是目录，不是百科全书；root 导航只放全局规则，项目规则写到最近的项目导航文件。
- Canonical path 是唯一事实源；legacy path 只能是 alias/wrapper，不能承载独立治理事实。
- 强门禁默认 fail-fast：plan-required、architecture boundary、alias integrity、wrapper integrity、placeholder angle-bracket。
- `security/auth/data-migration` 作用域命中时，对应检查在 bootstrap 与 enforced 轨道都必须阻断。
- execution plan 必须包含轻量 Context Package；只引用路径，不复制事实源正文。
- 禁止引入第二套 task/journal/hook 系统；不要生成 `.trellis/`、session journal 或新的任务 CLI。
- preflight 失败可以进入 degraded mode，但所有结果必须标注 `pass|fail|warn|not-run`；`not-run` 不能算作 `pass`。

## Canonical Surface

Canonical docs:

- `.harness/docs/architecture-boundaries.md`
- `.harness/docs/ci-governance.md`
- `.harness/docs/agent-autonomy.md`
- `.harness/docs/observability.md`
- `.harness/docs/feedback-loops.md`
- `.harness/docs/entropy-gc.md`
- `.harness/docs/exec-plans/active/`
- `.harness/docs/exec-plans/completed/`
- `.harness/docs/exec-plans/tech-debt-tracker.md`

Canonical scripts:

- `.harness/scripts/check-all.sh`
- `.harness/scripts/check-critical.sh`
- `.harness/scripts/check-placeholders.sh`
- `.harness/scripts/check-boundaries.sh`
- `.harness/scripts/check-plan-required.sh`
- `.harness/scripts/validate.sh`
- `.harness/scripts/regression.sh`

Fresh init must not create legacy root docs/scripts outside `.harness/` by default. Repair/migration mode may create temporary aliases or wrappers only when existing repo references require them.

## Reference Map

Load only the files needed for the active step.

| File | Use |
| --- | --- |
| `references/runtime-preflight.md` | Step 0 preflight, degraded mode, shell compatibility |
| `references/stack-detection.md` | Step 1 repo/project detection, scope rules, stack commands |
| `references/nav-templates.md` | Step 2 `AGENTS.md` / `CLAUDE.md` marker templates |
| `references/docs-templates.md` | Step 3 `.harness/docs` templates |
| `references/exec-plan-templates.md` | Execution plan and Context Package template |
| `references/tooling-templates.md` | Stack-specific package scripts, CI, harness script templates |
| `references/structure-tests.md` | Boundary checks, plan gate, alias/wrapper checks |
| `references/ci-governance.md` | bootstrap/enforced tracks and promotion/demotion |
| `references/quality-gates.md` | Required gate matrix and result states |
| `references/agent-autonomy.md` | L1-L4 autonomy policy |
| `references/observability-templates.md` | Health/log/metric/rollback surface |
| `references/gc-templates.md` | Entropy, drift, doc-gardening, GC |
| `references/report-templates.md` | Dry-run, init report, repair report |
| `references/repair-mode.md` | Existing harness repair/migration |
| `references/regression-fixtures.md` | harness-init regression fixture matrix |

## Mode Decision

1. Detect repository root.
2. Detect project boundaries.
3. Decide one mode:
   - `single-project`: root navigation and root `.harness/docs`.
   - `multi-project`: root navigation is an index; each project gets nearest navigation and project `.harness/docs`.
   - `nested-project`: update only the current project scope unless the user explicitly asks to modify the parent.
4. If `scope=<path>` is provided, initialize only that scope and use `HARNESS_TARGET_SCOPE=<path>` for checks.

Nearest navigation file wins:

- For `apps/editor/src/App.tsx`, read `apps/editor/AGENTS.md` or `apps/editor/CLAUDE.md`, then root navigation.
- Local rules override root rules except security/compliance root rules.

## Execution Flow

Maintain a visible checklist for these steps if no task tracker exists.

### Step 0: Dry-run Plan

Read `references/runtime-preflight.md` and `references/report-templates.md`.

Output before writing:

- repo mode
- detected project roots
- files to create/update/skip
- root-level writes and project-level writes
- runtime capability matrix
- warnings and degraded-mode risks

Proceed without asking only when the edit scope is clear and non-destructive. If existing rules conflict, stop and ask the user to choose the source of truth.

### Step 1: Inventory

Read `references/stack-detection.md`.

Inventory:

- navigation files
- existing `.harness/`, legacy docs, scripts, hooks, CI
- project manifests and workspaces
- existing package scripts and validation commands
- duplicate or conflicting fact sources

Report:

- files/commands to reuse
- missing artifacts to create
- conflicts requiring user decision
- boundary report with `repository_root`, `project_roots`, `repo_mode`, `workspace_candidates`, `scope`, `ignore_rules`

Create `.harnessignore` only if absent, using minimal default ignores: `node_modules/`, `dist/`, `build/`, `examples/`, `fixtures/`, `vendor/`, `third_party/`.

### Step 2: Navigation

Read `references/nav-templates.md`.

Rules:

- Update only marked `harness-init` blocks when a navigation file already exists.
- Marker blocks must include `version=2`, `Harness Init Contract Version: v2`, and `Generated/Updated by: harness-init`.
- In multi-project mode, root navigation is global-only and must not include project-local commands.
- Project commands, runtime context, project docs, and project validation live in the nearest project navigation file.
- If both `AGENTS.md` and `CLAUDE.md` are maintained, keep them semantically equivalent unless the user explicitly chooses pointer mode.

### Step 2.5: Runtime Context

Add runtime context only where it belongs:

- repo-wide health/CI/logs in root navigation
- project-specific health/logs/metrics in project navigation
- use TODO text for unknown values; never leave `<...>` placeholders in generated files

### Step 3: Docs Scaffold

Read `references/docs-templates.md` and `references/exec-plan-templates.md`.

Create or update canonical docs only. In multi-project mode:

- root `.harness/docs` contains repository-wide facts only
- `<project>/.harness/docs` contains project-specific facts only
- root execution plans are for cross-project/repository work
- project execution plans are for project-scoped work

Execution plan template must include Context Package:

- `Required Docs`
- `Relevant Patterns`
- `Affected Surfaces`
- `Validation Chain`
- `Learning Backfill`

### Step 4: Guides, Sensors, Observability

Read `references/tooling-templates.md` and `references/observability-templates.md`.

Add only missing command surface:

- lint / type-check / test / build when supported by the stack
- `.harness/scripts/reproduce.sh`
- `.harness/scripts/validate.sh`
- `.harness/scripts/regression.sh`
- `.harness/scripts/pre-release.sh`
- `.harness/scripts/query-logs.sh`
- `.harness/scripts/query-metrics.sh`

Do not invent successful tests for projects that do not have a test harness. Record missing commands as `not-run` or TODO with residual risk.

### Step 5: Structure Tests and Gates

Read `references/structure-tests.md` and `references/quality-gates.md`.

Configure:

- boundary check
- plan-required gate
- placeholder check
- alias integrity
- wrapper integrity
- file-size / naming / logging checks when applicable
- `.harness/plan-required-rules.yml`
- `.harness/gate-severity.yml`

Plan gate must validate root and project-scoped plan paths, file existence, and legal status.

### Step 5.5: CI Governance

Read `references/ci-governance.md`.

Configure:

- `bootstrap-observe`: non-critical checks, allowed to warn/fail by policy
- `critical-gates`: only `.harness/scripts/check-critical.sh`, always blocking
- `enforced`: full required checks
- promotion and demotion criteria
- PR context injection for plan gate (`GITHUB_EVENT_NAME`, `PR_BODY_FILE`, `.harness/pr-body.txt`)

### Step 6: Feedback Loops

Read `references/docs-templates.md`.

Write the rule:

- if the same class of failure appears twice, harden it into test / constraint / convention / ADR / lint rule / CI check / monitoring check / plan checklist
- before closing a task, decide whether a stable lesson needs Learning Backfill
- if nothing should be backfilled, report `Learning Backfill: none`

### Step 7: Entropy and GC

Read `references/gc-templates.md`.

Track:

- stale docs
- duplicate rules
- deprecated aliases
- unused scripts
- dead plans
- flaky checks
- abandoned ADR exceptions
- obsolete CI jobs

Add doc-gardening and drift-check entrypoints only when they can run honestly in the target environment.

### Step 8: Validation

Read `references/quality-gates.md` and `references/report-templates.md`.

Run the strongest available validation chain:

- generated harness structure check
- placeholder check
- plan-required gate where PR context exists
- alias/wrapper integrity
- stack-specific lint/type-check/test/build when available

Every skipped command must be reported as `not-run` with reason and residual risk.

### Step 9: Init Report

Read `references/report-templates.md`.

Write `.harness/docs/init-report.md` with:

- mode and detected projects
- created/updated/skipped files
- compatibility mapping
- CI track
- autonomy level
- strong gate results
- runtime capability matrix
- validations not run
- warnings
- next step: use `harness-engineering` for implementation work

## Repair Mode

Use repair mode when `.harness/`, legacy harness docs, or generated navigation blocks already exist.

Read `references/repair-mode.md`.

Repair must:

- preserve user-authored content
- detect duplicate marker blocks
- detect project-specific content in root navigation
- move local content to nearest project navigation file
- regenerate missing canonical docs
- convert legacy docs to alias only when needed
- migrate or remove legacy wrappers according to compatibility contract
- report remaining manual work

## Acceptance Checklist

After init or repair, verify:

- repo mode is correct
- root navigation is not polluted
- every confirmed project root has nearest navigation
- root/project docs are separated
- execution plans include Context Package
- plan-required gate handles root and project plan scopes
- critical gates cannot be skipped in PR context
- legacy docs are alias only
- legacy scripts are wrapper only or absent
- marker blocks are idempotent
- `<...>` placeholders fail validation
- TODO placeholders warn unless unknown-stack ADR allows them
- init report records preflight, created/updated/skipped files, warnings, and not-run validations

## Handoff

When initialization is complete:

- `harness-init` stops at navigation, docs scaffold, gates, scripts, reports, and repair.
- `harness-engineering` owns later implementation, refactoring, debugging, review, CI fixes, and feature delivery.
- Any repeated failure discovered during later work must be backfilled into harness docs according to `feedback-loops.md`.
