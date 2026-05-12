# Workflow: Architecture Change

> 零代码小程序设计平台 — 架构变更工作流

## Trigger

- Architecture decision needed (new pattern, technology, or approach)
- Module boundary change (splitting, merging, or redefining boundaries)
- New technology introduction (framework, library, or infrastructure)
- Significant interface/contract modification
- Cross-cutting concern redesign (auth, logging, error handling)

## Required Roles

| Role | Condition | Responsibility |
|------|-----------|----------------|
| `architect` | Always (**blocking**) | 架构决策、边界设计、技术评审 |
| `quality_gate_reviewer` | Always | 架构合规审查、影响评估 |
| `governance_context_sync_lead` | Always | ADR 记录、计划管理、文档同步 |

**Note:** `architect` role is **blocking** — no architecture change may proceed without explicit architect approval.

## Required Input Artifacts

- **ExecPlan** (mandatory) — detailed execution plan with phases, risks, rollback strategy
- **ADR draft** — Architecture Decision Record documenting:
  - Context and problem statement
  - Decision drivers
  - Considered options with pros/cons
  - Decision outcome
  - Consequences (positive, negative, neutral)
- Impact analysis — affected modules, interfaces, and downstream dependencies
- Migration strategy (if changing existing architecture)

## Required Output Artifacts

- **Updated `architecture-boundaries.md`** — reflecting new module boundaries and contracts
- **ADR** (finalized) — stored in `docs/decisions/`
- **Implementation** — code changes implementing the architecture decision
- Migration scripts (if applicable)
- Updated interface contracts/types

## Required Gates

| Gate | Type | Blocking |
|------|------|----------|
| Architecture boundary gate | Review | Yes |
| Plan-required gate | Automated | Yes (ExecPlan must exist) |
| `lint` | Automated | Yes |
| `test` | Automated | Yes |
| `typecheck` | Automated | Yes |
| `build` | Automated | Yes |
| Architect approval | Manual | Yes (blocking) |

## Required Docs Updates

- `architecture-boundaries.md` — updated with new boundaries, contracts, constraints
- ADR filed in `docs/decisions/` with sequential numbering
- Active ExecPlan updated with progress and status
- `context-snapshot` updated to reflect architectural state
- Affected module READMEs updated if public interfaces change

## Skip Conditions

**None** — architecture changes always require the full workflow.

> No exemptions. Even "small" boundary adjustments can have cascading effects. The ADR process ensures decisions are recorded and reversible.

## Completion Criteria

- [ ] ADR approved by `architect` and filed in `docs/decisions/`
- [ ] Architecture boundary gate passes (no undeclared cross-boundary dependencies)
- [ ] All required roles approve:
  - `architect` — confirms design is sound
  - `quality_gate_reviewer` — confirms no quality/security regressions
  - `governance_context_sync_lead` — confirms documentation is complete
- [ ] All automated gates pass (lint, test, typecheck, build)
- [ ] ExecPlan status updated to `completed`
- [ ] `architecture-boundaries.md` reflects the new state
- [ ] No unresolved ADR exceptions or open questions
