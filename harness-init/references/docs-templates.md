# Documentation Templates

加载时机：**Step 3 创建 `.harness/docs/` 骨架时**读取本文件。

---

## Canonical Naming Policy

规则：
- Canonical path 是唯一事实源（single source of truth）。
- Legacy path 只允许作为 compatibility alias，不允许承载独立治理事实。
- Alias 文件只能保留跳转说明，不能继续新增规则正文。

---

## Canonical Structure

### Single-project

```txt
.harness/
├── docs/
│   ├── architecture-boundaries.md
│   ├── constraints.md
│   ├── testing.md
│   ├── ci-governance.md
│   ├── agent-autonomy.md
│   ├── observability.md
│   ├── feedback-loops.md
│   ├── entropy-gc.md
│   ├── exec-plans/
│   │   ├── active/
│   │   ├── completed/
│   │   └── tech-debt-tracker.md
│   ├── doc-gardening-report.md
│   └── decisions/
│       └── ADR-0001-harness-init.md
└── scripts/
```

### Multi-project

```txt
repo/
├── AGENTS.md (or CLAUDE.md)
├── .harness/
│   ├── docs/
│   │   ├── architecture-boundaries.md
│   │   ├── ci-governance.md
│   │   ├── agent-autonomy.md
│   │   ├── observability.md
│   │   ├── feedback-loops.md
│   │   ├── entropy-gc.md
│   │   ├── exec-plans/
│   │   │   ├── active/
│   │   │   ├── completed/
│   │   │   └── tech-debt-tracker.md
│   │   ├── doc-gardening-report.md
│   │   └── decisions/
│   └── scripts/
├── apps/<name>/
│   ├── AGENTS.md (or CLAUDE.md)
│   └── .harness/docs/
│       ├── architecture-boundaries.md
│       ├── constraints.md
│       ├── testing.md
│       ├── observability.md
│       ├── feedback-loops.md
│       ├── entropy-gc.md
│       └── exec-plans/
│           ├── active/
│           ├── completed/
│           └── tech-debt-tracker.md
└── packages/services/... (same local `.harness/docs/` shape)
```

---

## Plan Scope Policy

- `single-project` / `nested-project`：
  - use `.harness/docs/exec-plans/*`
- `multi-project`：
  - root `.harness/docs/exec-plans/*` only for cross-project / repository-level plans
  - `<project>/.harness/docs/exec-plans/*` for project-scoped plans

Plan gate must accept both styles:
- `.harness/docs/exec-plans/active/<plan>.md`
- `<project>/.harness/docs/exec-plans/active/<plan>.md`

---

## Compatibility Mapping

| Legacy Path | Canonical Path | Strategy |
|---|---|---|
| `docs/autonomy-levels.md` | `.harness/docs/agent-autonomy.md` | keep alias only when migrating |
| `docs/boundaries.md` | `.harness/docs/architecture-boundaries.md` | keep alias only when migrating |
| `docs/architecture-rules.md` | `.harness/docs/architecture-boundaries.md` | keep alias only when migrating |
| `docs/ci.md` | `.harness/docs/ci-governance.md` | keep alias only when migrating |
| `docs/runtime-observability.md` | `.harness/docs/observability.md` | keep alias only when migrating |
| `docs/plans/` | `.harness/docs/exec-plans/` | migrate/alias with no duplicated facts |

---

## Alias File Template

legacy markdown 文件必须使用：

```md
# Compatibility Alias

This file is kept for backward compatibility.

Canonical source of truth:

- `.harness/docs/<canonical-file>.md`

Do not update this file with new rules.
Update the canonical file instead.
```

---

## architecture-boundaries.md

```md
# Architecture Boundaries

## Layer Model

| Layer | Responsibility | Allowed Dependencies |
|---|---|---|
| domain | core business rules | — |
| application | use cases/orchestration | domain |
| infrastructure | db/api/integrations | application, domain |
| presentation | handlers/ui/adapters | application |

## Forbidden Dependencies

- infrastructure -> presentation
- domain -> infrastructure
- cross-project implicit imports without declared API

## Boundary Checks

- `.harness/scripts/check-boundaries.sh`
- `<stack-specific architecture checker command>`

## ADR Exceptions

Any boundary exception must link:
- `.harness/docs/decisions/ADR-exceptions/<id>.md`
```

---

## ci-governance.md

> 详细模板使用 `references/ci-governance.md`，此处保持最小骨架。

```md
# CI Governance

## Tracks

- bootstrap
- enforced

## Promotion Criteria

- stable_days >= 7
- failure_rate < 5%
- critical_path_coverage >= 85%
- false_positive_count == 0 for 7 days
- rollback_path_documented == true
- owner_assigned == true

## Demotion Criteria

- requires ADR exception with expiry

## Severity Priority

- security/auth/data-migration checks are blocking when matching scope/labels are touched
```

---

## agent-autonomy.md

> 详细模板使用 `references/agent-autonomy.md`，此处保持最小骨架。

```md
# Agent Autonomy

## Levels

- L1 Assisted Coding
- L2 Self-checking Contributor
- L3 PR Owner
- L4 Low-risk Auto-merge

## Promotion Requirements

- previous_level_stable_days >= 14
- rollback_strategy_exists == true
- audit_trail_complete == true
- enforced_ci_green_rate >= 95%
- critical_incidents == 0
- owner_approval == true

## Rollback Triggers

- CI regression / production incident / SLO degradation / security finding
```

---

## observability.md

> 详细模板使用 `references/observability-templates.md`，此处保持最小骨架。

```md
# Observability

## Minimum Surface

- health check command
- log query command
- metrics query command
- SLO check command
- rollback verification command

## Canonical Scripts

- `.harness/scripts/query-logs.sh`
- `.harness/scripts/query-metrics.sh`
```

---

## constraints.md

```md
# Constraints

## Non-negotiables

- No silent fallback
- No fake success path
- No swallowed errors
- No hardcoded secrets
- No cross-layer dependency violations

## Enforced By

- `.harness/scripts/check-boundaries.sh`
- `.harness/scripts/check-naming.sh`
- `.harness/scripts/check-file-size.sh`
- `.harness/scripts/check-logging.sh`
```

---

## testing.md

```md
# Testing

## Validation Commands

- unit: `<unit test command>`
- integration: `<integration test command>`
- regression: `.harness/scripts/regression.sh`
- full validate: `.harness/scripts/validate.sh`

## Required Acceptance

- lint pass
- type-check pass
- tests pass
- architecture checks pass
```

---

## feedback-loops.md

```md
# Feedback Loops

## Rule

If the same class of failure appears twice, harden it into at least one:
- test
- constraint
- convention
- ADR
- lint rule
- CI check
- monitoring check
- execution plan checklist item

## Required Fields

### Learning Backfill Rule

Before closing a task, decide whether a stable lesson should be written back to harness docs. Write only reusable, auditable facts.

Targets:
- new boundary rule: `.harness/docs/architecture-boundaries.md`
- new engineering constraint: `.harness/docs/constraints.md`
- new validation requirement: `.harness/docs/testing.md` or harness scripts
- repeated failure: `.harness/docs/feedback-loops.md`
- stale/duplicate/obsolete governance: `.harness/docs/entropy-gc.md`

If there is nothing to backfill, report `Learning Backfill: none`.

### Failure Pattern
### First Occurrence
### Second Occurrence
### Root Cause
### Hardened As
### Linked Test / Rule / ADR / Check
### Owner
### Review Date
```

---

## entropy-gc.md

```md
# Entropy & GC

## Must Track

- stale docs
- duplicate rules
- deprecated aliases
- unused scripts
- dead plans
- flaky checks
- abandoned ADR exceptions
- old compatibility wrappers
- obsolete CI jobs

## Compatibility Inventory

| Path | Canonical Target | Reason | Owner | Review Date | Removal Condition |
|---|---|---|---|---|---|
| <legacy> | <canonical> | <why> | <owner> | <date> | <condition> |
```

---

## exec-plans/active/README.md

```md
# Active Execution Plans

All medium/large tasks must have an execution plan here before implementation.

In multi-project repositories:
- root `.harness/docs/exec-plans/active/` is for cross-project/repository plans
- project-level plans belong to `<project>/.harness/docs/exec-plans/active/`

Each execution plan should include a lightweight Context Package that lists required docs, relevant patterns, affected surfaces, validation chain, and learning backfill target.
```

## exec-plans/completed/README.md

```md
# Completed Execution Plans

Move finished plans from `.harness/docs/exec-plans/active/` to this directory.
```

## exec-plans/tech-debt-tracker.md

```md
# Tech Debt Tracker

| ID | Date | Scope | Debt | Impact | Owner | Status | Linked Plan/ADR |
|---|---|---|---|---|---|---|---|
| TD-001 | YYYY-MM-DD | <scope> | <debt> | <impact> | <owner> | open | <link> |
```

---

## decisions/ADR-0001-harness-init.md

```md
# ADR-0001: Harness Init

## Context

<当前仓库现状与接入原因>

## Decision

<采用 canonical path + compatibility alias + strong gates>

## Consequences

- canonical docs are source of truth
- legacy docs/scripts are alias/wrapper only
- CI adopts bootstrap + enforced tracks
```
