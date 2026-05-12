# Subagent Workflows Reference

本文档定义子智能体从"角色说明"升级为"可路由工作流系统"的完整规范。

## 概述

v4 将子智能体协作从静态角色定义升级为动态工作流系统，包含：
- **Routing Rules**: 基于变更路径和标签自动路由到对应角色
- **Review Rubrics**: 每个角色的审查标准和通过/拒绝条件
- **Workflows**: 端到端工作流定义，包含触发条件、必需角色、门禁和完成标准

## 文件结构

```
subagents/
├── roles.json              # 角色定义（v3 已有）
├── README.md               # 角色说明文档（v3 已有）
├── routing-rules.yml       # 路由规则配置
├── review-rubrics/         # 审查标准
│   ├── architect.md
│   ├── editor-component.md
│   ├── runtime-dataflow.md
│   ├── quality-gate.md
│   └── governance-context.md
└── workflows/              # 工作流定义
    ├── feature-delivery.md
    ├── bug-fix.md
    ├── architecture-change.md
    ├── schema-migration.md
    └── release.md
```

## Routing Rules

路由规则定义在 `subagents/routing-rules.yml` 中，支持：
- `changed_paths`: 基于文件变更路径匹配
- `labels`: 基于 PR/MR 标签匹配
- `require_roles`: 必须参与审查的角色列表
- `blocking`: 是否阻断合并直到所有必需角色完成

## Workflow 结构

每个 workflow 必须包含以下章节：
- **Trigger**: 触发条件
- **Required Roles**: 必需参与的角色
- **Required Input Artifacts**: 输入工件
- **Required Output Artifacts**: 输出工件
- **Required Gates**: 必须通过的门禁
- **Required Docs Updates**: 必须更新的文档
- **Skip Conditions**: 跳过条件
- **Completion Criteria**: 完成标准

## Review Rubric 结构

每个 rubric 必须包含：
- **Review Scope**: 审查范围
- **Required Check Items**: 必须检查的条目
- **Pass Criteria**: 通过标准
- **Reject Criteria**: 拒绝标准
- **Reference**: 关联的路由规则和角色定义

## 工作流执行规则

1. 变更提交时，routing-rules.yml 自动匹配必需角色
2. 每个必需角色按对应 review-rubric 执行审查
3. blocking 规则的角色必须全部通过才能合并
4. 工作流中的 Required Gates 必须全部 pass
5. 同类问题第二次出现时，bug-fix workflow 要求固化为 gate/test/rule/ADR

## 与 v3 的兼容性

- 保留 `roles.json` 和 `README.md` 不变
- routing-rules.yml 中的角色 ID 必须与 roles.json 中的 id 字段一致
- review-rubrics 中的职责描述必须与 roles.json 中的 core_responsibilities 语义一致
