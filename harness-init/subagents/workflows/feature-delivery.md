# Workflow: Feature Delivery

> 零代码小程序设计平台 — 功能交付工作流

## Trigger

- New feature request received
- ExecPlan created for the feature
- Feature spec/issue assigned and ready for implementation

## Required Roles

| Role | Condition | Responsibility |
|------|-----------|----------------|
| `architect` | If cross-module change | 确认模块边界、Schema 设计、接口契约 |
| `editor_component_specialist` | If scope involves editor/UI | 编辑器侧功能实现 |
| `runtime_dataflow_engineer` | If scope involves runtime/dataflow | 运行时侧功能实现 |
| `quality_gate_reviewer` | Always | 全链路质量审查 |
| `governance_context_sync_lead` | Always | 计划管理、上下文同步、文档更新 |

**Role selection logic:** Based on feature scope — editor-related features route to `editor_component_specialist`, runtime/dataflow features route to `runtime_dataflow_engineer`. Cross-module features require both plus `architect` as blocking reviewer.

## Required Input Artifacts

- **ExecPlan** (mandatory if cross-module change) — defines scope, phases, dependencies
- **Feature spec/issue** — clear description of requirements, acceptance criteria
- Architecture boundaries reference (if touching module boundaries)

## Required Output Artifacts

- **Implementation code** — feature code following project conventions
- **Tests** — unit tests, integration tests as appropriate for scope
- **Updated documentation** — relevant docs reflecting the new feature

## Required Gates

| Gate | Type | Blocking |
|------|------|----------|
| `lint` | Automated | Yes |
| `test` | Automated | Yes |
| `typecheck` | Automated | Yes |
| `build` | Automated | Yes |
| UI verification | Manual/Visual | Yes (if UI-related) |
| Architecture boundary check | Automated + Review | Yes (if cross-module) |

## Required Docs Updates

- Update active plan status (in-progress → completed)
- Update `context-snapshot` with current project state
- Update relevant module documentation if API/interface changes

## Skip Conditions

This workflow may be **skipped** (use lightweight commit flow instead) when ALL of the following are true:

- Change is < 10 lines of code
- Change affects a single file only
- No cross-module impact
- No Schema/interface changes
- No new dependencies introduced

> When skipped, standard lint/test/typecheck/build gates still apply.

## Completion Criteria

- [ ] All automated gates pass (lint, test, typecheck, build)
- [ ] Plan status updated to `completed`
- [ ] Review approved by all required roles (based on scope)
- [ ] Documentation updated to reflect changes
- [ ] Context snapshot reflects current state
- [ ] No unresolved blocking comments from reviewers
