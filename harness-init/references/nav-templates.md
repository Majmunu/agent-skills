# Navigation Templates

加载时机：**Step 2 创建/更新 AGENTS.md 或 CLAUDE.md**。

---

## Root Template (Multi-project)

```md
# AGENTS.md

<!-- harness-init:start root-nav version=2 -->
Harness Init Contract Version: v2
Generated/Updated by: harness-init

This repository contains multiple project scopes.

## Global Rule

Before editing files, read the nearest navigation file (`AGENTS.md` or `CLAUDE.md`) for the target path.

Scope resolution:
1. Start from the file or directory being edited.
2. Walk upward until a navigation file is found.
3. Apply that local file.
4. Also apply this root file.
5. If local and root rules conflict, local wins unless root is security/compliance.

## Repository Layout

| Scope | Path | Guide |
|---|---|---|
| <project-name> | `<path>` | `<path>/AGENTS.md` or `<path>/CLAUDE.md` |

## Shared Commands

Only include commands that apply to the whole repository.

- `<repo-wide install command>`
- `<repo-wide test command>`
- `<repo-wide lint command>`
- Do not include scope-specific commands (`cd apps/...`, `build:<project>`).

## Harness Operating System

Canonical docs:
- Architecture Boundaries: `.harness/docs/architecture-boundaries.md`
- CI Governance: `.harness/docs/ci-governance.md`
- Agent Autonomy: `.harness/docs/agent-autonomy.md`
- Observability: `.harness/docs/observability.md`
- Feedback Loops: `.harness/docs/feedback-loops.md`
- Entropy & GC: `.harness/docs/entropy-gc.md`
- Execution Plans: `.harness/docs/exec-plans/`
  - root scope: cross-project / repository-level plans
  - project scope: `<project>/.harness/docs/exec-plans/`

Canonical script root:
- `.harness/scripts/`

Before medium/large work:
1. create or update execution plan:
   - project-scoped work: `<project>/.harness/docs/exec-plans/active/`
   - cross-project/repository work: `.harness/docs/exec-plans/active/`
2. validate architecture boundaries
3. run harness checks
4. update feedback/entropy docs when needed

## Shared Constraints

- Root docs are repository-wide facts only.
- Project docs are project-specific facts only.
- Cross-module changes must link an execution plan in scope-correct path:
  - cross-project/repository work: `.harness/docs/exec-plans/*`
  - project-scoped work: `<project>/.harness/docs/exec-plans/*`
- Fresh init does not generate legacy docs/scripts outside `.harness/`.
- If the same failure happens twice, harden it into test/constraint/convention/ADR/check.

## Gate Policy

- bootstrap and enforced tracks are governed by `.harness/docs/ci-governance.md`
- security/auth/data-migration checks are blocking when matching scope/labels are touched, unless ADR exception exists and is not expired

## Engineering Workflow

After initialization, use `harness-engineering` for:
- implementation
- refactoring
- debugging
- code review
- architecture changes
- test and CI fixes
<!-- harness-init:end root-nav version=2 -->
```

---

## Project Template

```md
# <project-path> Agent Guide

<!-- harness-init:start project-nav <project-path> version=2 -->
Harness Init Contract Version: v2
Generated/Updated by: harness-init

## Project Overview

- Purpose: <one sentence>
- Main runtime: <node/python/go/rust/java/etc>
- Main source paths: <paths>

## Navigation

- Architecture Boundaries: `.harness/docs/architecture-boundaries.md`
- Constraints: `.harness/docs/constraints.md`
- Testing: `.harness/docs/testing.md`
- Observability: `.harness/docs/observability.md`
- Feedback Loops: `.harness/docs/feedback-loops.md`
- Entropy & GC: `.harness/docs/entropy-gc.md`
- Decisions: `.harness/docs/decisions/`

## Commands

Run from repository root:

- Install: `<install command>`
- Dev: `<dev command>`
- Lint: `<lint command>`
- Type-check: `<type-check command>`
- Test: `<test command>`
- Build: `<build command>`
- Boundary check (POSIX): `HARNESS_TARGET_SCOPE=<project-path> bash .harness/scripts/check-boundaries.sh`
- Boundary check (PowerShell): `$env:HARNESS_TARGET_SCOPE='<project-path>'; pwsh -File .harness/scripts/check-boundaries.ps1`
- Validate (POSIX): `HARNESS_TARGET_SCOPE=<project-path> bash .harness/scripts/validate.sh`
- Validate (PowerShell): `$env:HARNESS_TARGET_SCOPE='<project-path>'; pwsh -File .harness/scripts/validate.ps1`
- Regression (POSIX): `HARNESS_TARGET_SCOPE=<project-path> bash .harness/scripts/regression.sh`
- Regression (PowerShell): `$env:HARNESS_TARGET_SCOPE='<project-path>'; pwsh -File .harness/scripts/regression.ps1`
- Pre-release (POSIX): `HARNESS_TARGET_SCOPE=<project-path> bash .harness/scripts/pre-release.sh`
- Pre-release (PowerShell): `$env:HARNESS_TARGET_SCOPE='<project-path>'; pwsh -File .harness/scripts/pre-release.ps1`

## Runtime Context

- Health: `<health check command or URL>`
- Logs query (POSIX): `HARNESS_TARGET_SCOPE=<project-path> bash .harness/scripts/query-logs.sh`
- Logs query (PowerShell): `$env:HARNESS_TARGET_SCOPE='<project-path>'; pwsh -File .harness/scripts/query-logs.ps1`
- Metrics query (POSIX): `HARNESS_TARGET_SCOPE=<project-path> bash .harness/scripts/query-metrics.sh`
- Metrics query (PowerShell): `$env:HARNESS_TARGET_SCOPE='<project-path>'; pwsh -File .harness/scripts/query-metrics.ps1`

## Hard Constraints

- No silent fallbacks.
- No fake success paths.
- Keep dependency direction one-way.
- Update docs when behavior or boundaries change.
- Validate before completion.

## Planning Rule

Medium/large tasks must have an execution plan before implementation:
- `<project-path>/.harness/docs/exec-plans/active/<date-topic>.md`

Cross-module changes must link a plan in PR description.
<!-- harness-init:end project-nav <project-path> version=2 -->
```

---

## Single-project Template

```md
# AGENTS.md

<!-- harness-init:start root-nav version=2 -->
Harness Init Contract Version: v2
Generated/Updated by: harness-init

## Project Overview

- Purpose: <one sentence>
- Main runtime: <node/python/go/rust/java/etc>
- Primary app paths: `src/`, `cmd/`, `apps/`, `packages/`

## Harness Operating System

Canonical docs:
- Architecture Boundaries: `.harness/docs/architecture-boundaries.md`
- CI Governance: `.harness/docs/ci-governance.md`
- Agent Autonomy: `.harness/docs/agent-autonomy.md`
- Observability: `.harness/docs/observability.md`
- Feedback Loops: `.harness/docs/feedback-loops.md`
- Entropy & GC: `.harness/docs/entropy-gc.md`
- Execution Plans: `.harness/docs/exec-plans/`

Canonical scripts:
- `.harness/scripts/check-all.sh`
- `.harness/scripts/check-critical.sh`
- `.harness/scripts/check-placeholders.sh`
- `.harness/scripts/check-boundaries.sh`
- `.harness/scripts/check-plan-required.sh`
- `.harness/scripts/validate.sh`
- `.harness/scripts/regression.sh`

Before medium/large work:
1. create/update execution plan
2. run boundary checks
3. run harness validation
4. update feedback loop when repeated failures happen

## Commands

- Install: `<install command>`
- Dev: `<dev command>`
- Lint: `<lint command>`
- Type-check: `<type-check command>`
- Test: `<test command>`
- Build: `<build command>`

## Runtime Context

- Health: `<health check command or URL>`
- CI: `<CI provider link>`
- Logs query: `.harness/scripts/query-logs.sh`
- Metrics query: `.harness/scripts/query-metrics.sh`

## Working Rules

- Canonical docs are source of truth.
- Legacy docs/scripts are alias/wrapper only.
- If same failure repeats twice, harden into test/constraint/convention/ADR/check.
<!-- harness-init:end root-nav version=2 -->
```

---

## CLAUDE.md Parity Rule

如果同时生成 `AGENTS.md` 与 `CLAUDE.md`：
- 两者必须语义等价（strict parity）
- 不允许一个文件承载事实、另一个仅做模糊指针
- 仅在用户明确要求时使用 pointer mode
