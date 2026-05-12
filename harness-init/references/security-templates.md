# Security Templates Reference

本文档定义 harness-init 生成的安全相关模板和检查规范。

## 概述

安全模板覆盖以下领域：
- Secrets handling（密钥管理）
- Permission boundary（权限边界）
- MCP tool approval（MCP 工具审批）
- Production deployment approval（生产部署审批）
- Database migration approval（数据库迁移审批）
- Destructive operation approval（破坏性操作审批）
- Audit trail（审计追踪）

## 生成文件

| 文件 | 用途 |
|------|------|
| `docs/security-threat-model.md` | 安全威胁模型文档 |
| `scripts/harness/check-secrets.sh` | 密钥泄露检测脚本 |
| `scripts/harness/check-permissions.sh` | 权限边界检查脚本 |
| `.harness/integrations.yml` | 集成配置（含审批策略） |

## 密钥检测规则

`check-secrets.sh` 检测以下模式：

### 必须阻断（fail）
- `.env` 文件被 git 跟踪
- AWS Access Key（`AKIA[0-9A-Z]{16}`）
- OpenAI/Stripe secret key（`sk-[a-zA-Z0-9]{20,}`）
- GitHub PAT（`ghp_[a-zA-Z0-9]{36}`）
- GitLab PAT（`glpat-[a-zA-Z0-9-]{20,}`）
- Slack token（`xox[baprs]-...`）
- JWT token（`eyJ...`）
- Private key files（`-----BEGIN ... PRIVATE KEY-----`）
- CI 配置中硬编码 token

### 安全约束
- 不写入真实 token
- 不打印 token 值
- 不提交 `.env` 中的 secret
- 所有集成只使用环境变量占位

## 权限边界规则

`check-permissions.sh` 验证：
1. `.harness/integrations.yml` 中 MCP 危险操作有审批策略
2. production-deploy 在审批列表中
3. database-migration 在审批列表中
4. 所有 6 类危险操作都有对应策略

## 阻断策略

以下情况在任何模式下（bootstrap 或 enforced）都必须阻断：
- 密钥泄露（check-secrets fail）
- 未授权 auth 改动
- 无 rollback 的 data migration
- 无审批的 production deploy

## 输出格式要求

所有安全检查脚本必须使用统一输出格式：

```txt
FAIL: <gate-name>
Reason: <why failed>
Evidence: <file:line or command output>
Fix: <concrete remediation steps>
Docs: <canonical doc path>
Bypass: not allowed
```

安全相关 gate 的 Bypass 字段必须为 `not allowed`。
