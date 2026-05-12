# Security Threat Model

> Harness Init Contract Version: v3
> Generated/Updated by: harness-init
> Scope: root

## Assets

- 源代码仓库
- 用户数据（小程序用户信息、页面数据、Schema 数据）
- API 密钥和访问令牌（GitLab、YouTrack、MCP、微信开放平台）
- CI/CD 流水线配置
- 部署凭证和基础设施访问
- 数据库连接信息

## Trust Boundaries

| 边界 | 内部 | 外部 |
|------|------|------|
| 开发环境 | 本地代码、本地数据库 | 远程 API、第三方服务 |
| CI/CD | 构建产物、测试环境 | 生产环境、外部注册表 |
| 运行时 | 小程序沙箱 | 微信 API、用户设备 |
| 集成 | 内部工具 | GitLab、YouTrack、MCP servers |

## Secrets Handling

### 规则

- 所有密钥通过环境变量传递，不写入代码或配置文件
- `.env` 文件必须在 `.gitignore` 中
- CI 密钥使用平台原生 secret 管理（GitLab CI Variables、GitHub Secrets）
- 定期轮换密钥（建议周期：90 天）

### 检查

- `scripts/harness/check-secrets.sh` 自动检测泄露风险
- 检测 `.env` 被 git 跟踪
- 检测常见 token pattern
- 检测私钥文件
- 检测 CI 配置中硬编码 token

## MCP Tool Boundaries

### 允许的操作（无需审批）

- 读取文件系统
- 查询 issue 状态
- 获取 MR/PR 信息
- 读取 CI 状态

### 需要人工审批的操作

- delete（删除仓库/文件）
- force-push（强制推送）
- production-deploy（生产部署）
- permission-change（权限变更）
- database-migration（数据库迁移）
- secret-rotation（密钥轮换）
- external-network-write（外部网络写操作）

## Dangerous Operations

| 操作 | 风险 | 缓解措施 |
|------|------|---------|
| 生产部署 | 服务中断、数据丢失 | 人工审批 + 回滚方案 |
| 数据库迁移 | 数据损坏、不可逆变更 | ExecPlan + 人工审批 + 回滚脚本 |
| 密钥轮换 | 服务中断 | 人工审批 + 渐进式轮换 |
| 强制推送 | 历史丢失 | 人工审批 + 备份确认 |
| 权限变更 | 未授权访问 | 人工审批 + 审计日志 |

## Required Human Approval

以下场景必须获得人工审批后才能执行：

1. **生产环境部署** — 任何影响线上服务的变更
2. **数据库 Schema 迁移** — 必须有 ExecPlan + rollback 方案
3. **权限/角色变更** — 影响访问控制的任何修改
4. **密钥轮换** — 可能导致服务中断
5. **删除操作** — 不可逆的数据或代码删除
6. **强制推送** — 可能丢失 git 历史

## Audit Trail

所有危险操作必须记录：

- 操作类型
- 执行时间
- 执行者（人工或智能体）
- 审批者
- 操作结果（成功/失败/回滚）
- 关联的 ExecPlan 或 issue

建议存储位置：`docs/harness/audit-log.md` 或集成到 issue tracker。

## Incident Response

1. **检测** — 通过 check-secrets.sh、check-permissions.sh 或监控告警发现
2. **评估** — 确定影响范围和严重程度
3. **遏制** — 立即撤销泄露的密钥、阻断未授权访问
4. **修复** — 修复根因、更新安全策略
5. **复盘** — 记录 ADR、更新 feedback-loops.md、固化为 gate/rule
