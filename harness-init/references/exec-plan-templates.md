# Execution Plan Templates

加载时机：**Step 3 文档骨架 + Step 5 计划门禁配置**。

---

## First-class Plan Rule

以下改动必须先创建 execution plan（`.harness/docs/exec-plans/active/*.md`）再实施：
- cross-module changes
- cross-project changes
- public API changes
- database/schema changes
- CI/CD changes
- dependency boundary changes
- auth/security/permission changes（可由 PR label 触发）
- data migration（可由 PR label 触发）
- infrastructure changes
- changed files count `> 5`
- changes requiring rollback planning（可由 PR label `rollback-required` 触发）

---

## Plan Scope Policy

- `single-project` / `nested-project`：
  - use `.harness/docs/exec-plans/*`
- `multi-project`：
  - root `.harness/docs/exec-plans/*` only for cross-project/repository-level plans
  - `<project>/.harness/docs/exec-plans/*` for project-scoped plans

plan gate must accept:
- `.harness/docs/exec-plans/active/<plan>.md`
- `<project>/.harness/docs/exec-plans/active/<plan>.md`

---

## Plan Lifecycle

状态流转：
- `active -> completed`
- `active -> blocked`
- `active -> superseded`

规则：
- `active` 计划放在 `.harness/docs/exec-plans/active/`
- `completed` 计划移到 `.harness/docs/exec-plans/completed/`
- `blocked/superseded` 计划必须注明原因与后续处理

---

## Execution Plan Template

```md
# Execution Plan: <title>

Status: active
Owner: <agent/human/team>
Created: <YYYY-MM-DD>
Scope: <paths/modules>
Risk: low | medium | high

## Goal

## Non-goals

## Affected Areas

## Dependencies

## Risks

## Rollback Plan

## Steps

## Validation

## Observability Checks

## Completion Criteria

## Linked PRs / Commits

## Post-completion Notes
```

---

## Plan Gate Script Contract

canonical 脚本：`.harness/scripts/check-plan-required.sh`

门禁必须同时验证：
1. PR 描述包含 plan 路径（支持 root 与 project-scoped `.harness/docs/exec-plans/*`）
2. 路径对应文件存在
3. 计划文件状态合法（默认仅 `active|completed`，可配置扩展）

额外规则：
- 若计划路径在 `active/` 或 `completed/`，文件前 60 行必须包含 `Status:` 字段。
- multi-project 下：
  - 单项目作用域变更优先要求 `<project>/.harness/docs/exec-plans/*`
  - 跨项目/仓库级变更要求 `.harness/docs/exec-plans/*`
- 非 PR 事件自动跳过门禁。

---

## Machine-checkable Trigger Config

建议在仓库写入 `.harness/plan-required-rules.yml`：

`check-plan-required.sh` 当前版本会读取该文件中的布尔开关、阈值和 labels 列表（轻量解析，无需额外依赖）。

```yaml
version: 1
triggers:
  cross_scope_change: true
  cross_project_change: true
  db_schema_change: true
  ci_change: true
  boundary_config_change: true
  infra_change: true
  changed_files_gt: 5
  labels:
    - security
    - auth
    - migration
    - public-api
    - rollback-required
allowed_plan_statuses:
  - active
  - completed
```
