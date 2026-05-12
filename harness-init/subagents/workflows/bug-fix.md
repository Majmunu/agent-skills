# Workflow: Bug Fix

> 零代码小程序设计平台 — 缺陷修复工作流

## Trigger

- Bug report filed (user-reported or internal)
- Production incident detected
- Test failure in CI/CD pipeline
- Regression identified during review

## Required Roles

| Role | Condition | Responsibility |
|------|-----------|----------------|
| `editor_component_specialist` | If bug in editor/UI domain | 编辑器侧问题定位与修复 |
| `runtime_dataflow_engineer` | If bug in runtime/dataflow domain | 运行时侧问题定位与修复 |
| `quality_gate_reviewer` | Always | 验证修复、审查回归测试 |
| `governance_context_sync_lead` | If repeat issue | 更新 feedback-loops、固化规则 |

**Role selection logic:** Route to the relevant domain specialist based on where the bug manifests. If the bug crosses module boundaries, `architect` may be consulted for root cause analysis.

## Required Input Artifacts

- **Reproduction steps** — clear steps to reproduce the issue
- **Error evidence** — error logs, screenshots, stack traces, or failing test output
- Related issue/ticket reference (if exists)
- Affected version/environment information

## Required Output Artifacts

- **Fix code** — minimal, focused fix addressing root cause
- **Regression test** — test that fails before fix and passes after
  - If regression test is not possible, a **documented reason** must be provided (e.g., environment-specific issue, timing-dependent behavior)
- Root cause analysis (for production incidents)

## Required Gates

| Gate | Type | Blocking |
|------|------|----------|
| `lint` | Automated | Yes |
| `test` | Automated | Yes |
| `typecheck` | Automated | Yes |
| `build` | Automated | Yes |
| Regression test passes | Automated | Yes |

## Required Docs Updates

- Update `feedback-loops.md` if this is a **repeat issue** (same root cause appearing second time)
- Update `tech-debt-tracker.md` if the bug reveals a **systemic issue** requiring future refactoring
- Update relevant module docs if the fix changes behavior or API semantics

## Skip Conditions

**None** — all bugs require at minimum:
- A regression test, OR
- A documented exception explaining why a regression test is not feasible

> There is no "trivial bug" exemption. Even single-line fixes must have test coverage or documented reasoning.

## Completion Criteria

- [ ] Fix verified — bug no longer reproducible with original reproduction steps
- [ ] Regression test added and passing (or documented exception provided)
- [ ] All automated gates pass (lint, test, typecheck, build)
- [ ] **Repeat-issue rule applied** if this is the second occurrence of the same failure pattern:
  - Must be hardened as one of: gate / test / rule / ADR
  - Recorded in `feedback-loops.md` with prevention mechanism
- [ ] Root cause documented (for production incidents)
- [ ] Review approved by `quality_gate_reviewer`
