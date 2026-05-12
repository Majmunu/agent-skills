# Permission Boundaries Reference

本文档定义 harness-init 生成的权限边界和审批策略模板。

## 概述

权限边界确保危险操作不会在无人工审批的情况下执行。所有集成（MCP、GitLab、YouTrack）的危险操作必须经过明确的审批流程。

## 危险操作列表

以下操作在任何模式下（bootstrap 或 enforced）都必须要求人工审批：

| 操作 | 风险等级 | 审批要求 |
|------|---------|---------|
| delete (repository/file) | Critical | 必须人工审批 |
| force-push | Critical | 必须人工审批 |
| production-deploy | Critical | 必须人工审批 |
| permission-change | Critical | 必须人工审批 |
| database-migration | Critical | 必须人工审批 + ExecPlan |
| secret-rotation | High | 必须人工审批 |
| external-network-write | High | 必须人工审批 |

## 配置位置

权限边界配置在 `.harness/integrations.yml` 的 `mcp.servers.*.approval_required_for` 字段中。

## 检查脚本

`scripts/harness/check-permissions.sh` 验证：
1. `.harness/integrations.yml` 存在
2. MCP 危险操作有 `approval_required_for` 策略
3. production-deploy 在审批列表中
4. database-migration 在审批列表中

## 审批流程

1. 智能体请求执行危险操作
2. 系统检查 `approval_required_for` 列表
3. 如果操作在列表中，阻断执行
4. 等待人工审批（通过 MR 评论、issue 确认或 CLI 确认）
5. 审批通过后执行操作
6. 记录审计日志

## 与 Gate 的关系

- `check-permissions.sh` 是 gate 之一
- 在 bootstrap 模式下：warn（但 security 相关仍阻断）
- 在 enforced 模式下：fail（必须配置完整审批策略）

## 输出格式

```txt
pass: check-permissions (all checks passed)
fail: check-permissions (N issue(s) found)
warn: check-permissions (N warning(s))
not-run: check-permissions (reason)
```

失败时输出结构化信息：
```txt
FAIL: check-permissions:<sub-check>
Reason: <why failed>
Evidence: <file:line or config detail>
Fix: <concrete remediation steps>
Docs: references/permission-boundaries.md
Bypass: not allowed
```
