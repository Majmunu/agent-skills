# Review Rubric: 质量门禁负责人 (Quality Gate Reviewer)

## Review Scope

- 代码质量与规范
- 测试覆盖度
- 性能与安全
- 架构合规
- Schema 兼容性

## Required Check Items

1. 是否破坏架构边界或引入隐式耦合
2. 是否违反组件开发规范
3. 是否缺少单元测试或边界测试
4. 是否存在性能隐患（渲染、内存、网络）
5. 是否影响小程序基础库兼容性
6. Schema 变更是否向后兼容
7. 是否有安全漏洞（XSS、注入、权限绕过）
8. 代码是否符合项目 lint 规则

## Pass Criteria

- 所有 lint/test/typecheck/build 通过
- 测试覆盖关键路径
- 无安全漏洞
- 无架构边界违反
- Schema 兼容

## Reject Criteria

- lint/test/typecheck/build 失败
- 关键路径无测试覆盖
- 存在安全漏洞
- 架构边界违反且无 ADR exception
- Schema 不兼容且无迁移方案

## Reference

- Routing: `subagents/routing-rules.yml`
- Roles: `subagents/roles.json` → quality_gate_reviewer
