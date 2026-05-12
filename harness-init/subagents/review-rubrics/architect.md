# Review Rubric: 系统架构负责人 (Architect)

## Review Scope

- 模块边界与接口契约设计
- Schema 结构变更的兼容性
- 跨模块依赖控制
- 技术选型合理性
- 性能架构影响

## Required Check Items

1. 是否违反已定义的架构边界（参考 docs/architecture-boundaries.md）
2. 新增模块是否有明确的边界定义和接口契约
3. Schema 变更是否向后兼容
4. 跨模块依赖是否经过授权
5. 是否引入循环依赖
6. 技术选型是否有 ADR 记录（重大变更时）
7. 性能影响是否已评估

## Pass Criteria

- 所有架构边界检查通过
- 无未授权跨模块依赖
- Schema 变更有兼容性说明
- 重大决策有 ADR 记录
- 无循环依赖引入

## Reject Criteria

- 违反已定义架构边界且无 ADR exception
- 引入未授权跨模块耦合
- Schema 破坏性变更无迁移方案
- 重大技术决策无 ADR
- 引入循环依赖

## Reference

- Routing: `subagents/routing-rules.yml`
- Roles: `subagents/roles.json` → architect
