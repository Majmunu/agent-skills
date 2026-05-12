# Review Rubric: 项目治理与上下文同步负责人 (Governance & Context Sync Lead)

## Review Scope

- 执行计划生命周期
- 技术债追踪
- ADR 记录
- 反馈闭环
- 文档完整性
- 标签合规

## Required Check Items

1. 跨模块变更是否有关联的 ExecPlan
2. ExecPlan 状态是否正确（active/completed/blocked/superseded）
3. 技术债是否记录在 tech-debt-tracker.md
4. 重复失败是否已固化为 feedback-loop 规则
5. 重大决策是否有 ADR 记录
6. 固定记录标签（[REQ][RULE][EVIDENCE][RISK][VERIFY][GATE]）是否正确使用
7. 文档是否存在漂移（legacy docs 承载治理事实）
8. Context snapshot 是否需要更新

## Pass Criteria

- 跨模块变更有 ExecPlan 关联
- Plan 状态正确
- 技术债已记录
- 标签使用合规
- 无文档漂移

## Reject Criteria

- 跨模块变更无 ExecPlan
- Plan 状态不正确或缺失
- 重复失败未固化为规则
- 标签使用不合规
- Legacy docs 承载治理事实（应迁移到 canonical path）

## Reference

- Routing: `subagents/routing-rules.yml`
- Roles: `subagents/roles.json` → governance_context_sync_lead
