# MCP Integrations Reference

加载时机：**Step 6 Feedback Loops + Integrations**。

本文档说明 `.harness/integrations.yml` 配置文件的完整 schema、各 provider 的使用方式、MCP 危险操作边界，以及集成脚本的输入/输出规范。

---

## Configuration File

路径：`.harness/integrations.yml`

该文件由 harness-init 在 Step 6 生成，定义项目的代码托管平台、Issue 跟踪器和 MCP 服务器集成。所有 `scripts/harness/` 中的集成脚本从此文件读取 provider 配置。

**安全原则：** 配置文件中仅存储环境变量名称（如 `GITLAB_TOKEN`），绝不存储真实 token 值。

---

## Schema Overview

```yaml
version: 1
code_host:
  provider: <provider>           # gitlab | github | not-configured
  base_url: <url>                # 代码托管平台 URL
  token_env: <ENV_VAR>           # 存放 API token 的环境变量名
  merge_request_required: <bool> # 是否强制要求 MR
  plan_link_required: <bool>     # MR 描述中是否必须包含 ExecPlan 链接
  default_branch: <branch>       # 默认目标分支
  mr_template: <path>            # MR 描述模板路径
issue_tracker:
  provider: <provider>           # youtrack | jira | linear | not-configured
  base_url: <url>                # Issue 跟踪器 URL
  token_env: <ENV_VAR>           # 存放 API token 的环境变量名
  project_id: <id>               # 项目标识符
  required_for_plan: <bool>      # 创建 plan 前是否必须关联 issue
mcp:
  enabled: <bool>                # MCP 集成总开关
  dangerous_operations: <list>   # 需要人工审批的危险操作列表
  approval:
    method: <method>             # 审批方式
    approvers: <list>            # 审批人角色
    timeout: <duration>          # 审批超时时间
  servers:
    <server_name>:
      provider: <provider>
      approval_required_for: <list>
```

---

## Code Host Providers

### `gitlab` — GitLab

通过 GitLab REST API 进行 MR 创建、review 上下文获取等操作。

| 配置项 | 说明 | 示例值 |
|---|---|---|
| `base_url` | GitLab 实例 URL | `https://gitlab.example.com` |
| `token_env` | API token 环境变量名 | `GITLAB_TOKEN` |
| `merge_request_required` | 是否强制 MR | `true` |
| `plan_link_required` | MR 中是否必须包含 plan 链接 | `true` |
| `default_branch` | 默认目标分支 | `main` |
| `mr_template` | MR 描述模板路径 | `docs/templates/merge-request.md` |

**所需环境变量：**
- `GITLAB_TOKEN` — GitLab Personal Access Token 或 Project Token（需要 `api` scope）

**脚本行为（已配置）：**
```
create-merge-request.sh:
  → 创建 MR，自动在描述中包含 ExecPlan 路径
  → 输出 MR URL 和 ID

fetch-review-context.sh:
  → 获取 MR 评论、变更文件列表、CI 状态
  → 输出结构化 review 上下文
```

**脚本行为（未配置）：**
```
not-run: GITLAB_TOKEN or GitLab base_url is not configured.
Command: create-merge-request.sh --title "..." --branch "..."
Reason: .harness/integrations.yml code_host.token_env (GITLAB_TOKEN) is not set in environment, or code_host.base_url is "TODO: 待补充"
Risk: Cannot create merge requests or fetch review context programmatically
```

### `github` — GitHub

通过 GitHub REST/GraphQL API 进行 PR 创建、review 上下文获取等操作。

| 配置项 | 说明 | 示例值 |
|---|---|---|
| `base_url` | GitHub 实例 URL | `https://github.com` 或 `https://github.enterprise.com` |
| `token_env` | API token 环境变量名 | `GITHUB_TOKEN` |
| `merge_request_required` | 是否强制 PR | `true` |
| `plan_link_required` | PR 中是否必须包含 plan 链接 | `true` |

**所需环境变量：**
- `GITHUB_TOKEN` — GitHub Personal Access Token 或 Fine-grained Token

### `not-configured`

当 provider 设为 `not-configured` 时，所有代码托管相关脚本输出 `not-run`。

---

## Issue Tracker Providers

### `youtrack` — JetBrains YouTrack

通过 YouTrack REST API 同步 issue 状态和建立双向链接。

| 配置项 | 说明 | 示例值 |
|---|---|---|
| `base_url` | YouTrack 实例 URL | `https://youtrack.example.com` |
| `token_env` | API token 环境变量名 | `YOUTRACK_TOKEN` |
| `project_id` | 项目标识符 | `PROJ` |
| `required_for_plan` | 创建 plan 前是否必须关联 issue | `false` |

**所需环境变量：**
- `YOUTRACK_TOKEN` — YouTrack Permanent Token

**脚本行为（已配置）：**
```
sync-issues.sh:
  → 从 YouTrack 同步 issue 状态到本地 plan 文件
  → 输出同步的 issue 数量和状态变更

link-plan-to-issue.sh --plan <path> --issue <id>:
  → 在 ExecPlan 中添加 issue 链接
  → 在 YouTrack issue 中添加 plan 链接（双向）
  → 输出链接结果
```

**脚本行为（未配置）：**
```
not-run: YOUTRACK_TOKEN or YouTrack base_url is not configured.
Command: sync-issues.sh
Reason: .harness/integrations.yml issue_tracker.token_env (YOUTRACK_TOKEN) is not set in environment, or issue_tracker.base_url is "TODO: 待补充"
Risk: Cannot sync issue status or establish bidirectional plan-issue links
```

### `jira` — Atlassian Jira

通过 Jira REST API 同步 issue 状态。

| 配置项 | 说明 | 示例值 |
|---|---|---|
| `base_url` | Jira 实例 URL | `https://jira.example.com` |
| `token_env` | API token 环境变量名 | `JIRA_TOKEN` |
| `project_id` | 项目 key | `PROJ` |

### `linear` — Linear

通过 Linear GraphQL API 同步 issue 状态。

| 配置项 | 说明 | 示例值 |
|---|---|---|
| `base_url` | Linear API URL | `https://linear.app` |
| `token_env` | API token 环境变量名 | `LINEAR_TOKEN` |
| `project_id` | Team identifier | `TEAM-ID` |

### `not-configured`

当 provider 设为 `not-configured` 时，所有 issue tracker 相关脚本输出 `not-run`。

---

## MCP (Model Context Protocol) Configuration

### Overview

MCP 配置定义了智能体可以通过 Model Context Protocol 调用的外部工具服务器，以及对危险操作的安全边界。

### Dangerous Operations

以下操作被定义为**危险操作**，在任何模式下（bootstrap 或 enforced）都必须获得人工审批后才能执行：

| 操作 | 说明 | 风险等级 |
|---|---|---|
| `delete` | 删除资源（文件、分支、数据库记录等） | 高 — 不可逆数据丢失 |
| `force-push` | 强制推送覆盖远程分支历史 | 高 — 历史丢失、协作中断 |
| `production-deploy` | 部署到生产环境 | 高 — 影响线上用户 |
| `permission-change` | 修改访问权限或安全策略 | 高 — 安全边界变更 |
| `database-migration` | 执行数据库 schema 变更 | 高 — 数据完整性风险 |
| `secret-rotation` | 轮换密钥或凭证 | 高 — 服务中断风险 |

### Approval Policy

```yaml
approval:
  method: comment        # 审批方式：comment | label | api-call
  approvers:             # 可审批的角色
    - tech-lead
    - security
  timeout: "24h"         # 超时后自动拒绝
```

**审批方式说明：**

| 方式 | 说明 |
|---|---|
| `comment` | 在 MR/PR 中通过特定格式评论审批（如 `/approve-dangerous delete`） |
| `label` | 在 MR/PR 中添加特定 label 表示审批（如 `approved:dangerous-op`） |
| `api-call` | 通过外部审批系统 API 获取审批状态 |

### Approval Flow

```
1. Agent 请求执行危险操作
2. check-permissions.sh 检测到操作在 dangerous_operations 列表中
3. 脚本输出 FAIL 并要求人工审批
4. 人工通过配置的 method 进行审批
5. Agent 再次执行，check-permissions.sh 验证审批有效
6. 操作执行
```

### MCP Server Configuration

每个 MCP server 定义包含：

| 字段 | 说明 |
|---|---|
| `provider` | MCP server 的 provider 标识 |
| `approval_required_for` | 该 server 中需要审批的操作列表（从 `dangerous_operations` 中选取） |

**示例：**
```yaml
servers:
  browser:
    provider: "playwright-mcp"
    approval_required_for:
      - delete
      - production-deploy
  filesystem:
    provider: "fs-mcp"
    approval_required_for:
      - delete
      - permission-change
```

### MCP 安全边界

1. **默认拒绝**：未在 `servers` 中明确列出的 MCP server 不可使用
2. **操作白名单**：每个 server 仅允许执行其配置中定义的操作
3. **危险操作阻断**：`dangerous_operations` 列表中的操作在获得审批前一律阻断
4. **审计追踪**：所有 MCP 操作（包括被阻断的）记录到 `.harness/runs/` 目录

---

## Integration Scripts Interface

### sync-issues.sh

同步 issue tracker 中的 issue 状态到本地 plan 文件。

**输入：**
```bash
scripts/harness/sync-issues.sh [--project <project-id>] [--since <duration>]
```

| 参数 | 说明 | 必填 |
|---|---|---|
| `--project <id>` | 项目标识符（覆盖 integrations.yml 中的 project_id） | 否 |
| `--since <duration>` | 仅同步指定时间范围内更新的 issue | 否 |

**输出（成功）：**
```
provider: youtrack
endpoint: https://youtrack.example.com
project: PROJ
---
synced: 5
updated: 2 (PROJ-123: In Progress → Done, PROJ-456: Open → In Progress)
skipped: 3 (no status change)
---
status: success
```

**退出码：** `0` 成功 | `1` 失败 | `2` 未配置

### link-plan-to-issue.sh

建立 ExecPlan 与 issue 的双向链接。

**输入：**
```bash
scripts/harness/link-plan-to-issue.sh --plan <plan-path> --issue <issue-id>
```

| 参数 | 说明 | 必填 |
|---|---|---|
| `--plan <path>` | ExecPlan 文件路径 | 是 |
| `--issue <id>` | Issue 标识符（如 `PROJ-123`） | 是 |

**输出（成功）：**
```
provider: youtrack
---
plan: docs/exec-plans/active/feature-auth.md
issue: PROJ-123
link_in_plan: added
link_in_issue: added
---
status: success
```

**退出码：** `0` 成功 | `1` 失败 | `2` 未配置

### fetch-review-context.sh

从代码托管平台获取 MR/PR 的审查上下文。

**输入：**
```bash
scripts/harness/fetch-review-context.sh --mr <mr-id>
```

| 参数 | 说明 | 必填 |
|---|---|---|
| `--mr <id>` | Merge Request / Pull Request ID | 是 |

**输出（成功）：**
```
provider: gitlab
endpoint: https://gitlab.example.com
mr: !42
---
title: "feat: add user authentication"
status: open
ci_status: passed
changed_files: 12
comments: 3
unresolved_threads: 1
plan_link: docs/exec-plans/active/feature-auth.md
---
comments:
  - author: reviewer1, file: src/auth.ts:42, body: "Consider using bcrypt instead"
  - author: reviewer2, file: src/middleware.ts:15, body: "Missing error handling"
---
status: success
```

**退出码：** `0` 成功 | `1` 失败 | `2` 未配置

### create-merge-request.sh

创建包含 plan 链接和标准描述模板的 MR。

**输入：**
```bash
scripts/harness/create-merge-request.sh --title <title> --branch <branch> [--plan <plan-path>] [--target <branch>]
```

| 参数 | 说明 | 必填 |
|---|---|---|
| `--title <title>` | MR 标题 | 是 |
| `--branch <branch>` | 源分支 | 是 |
| `--plan <path>` | 关联的 ExecPlan 路径 | 否（若 plan_link_required=true 则必填） |
| `--target <branch>` | 目标分支（默认使用 default_branch） | 否 |

**输出（成功）：**
```
provider: gitlab
endpoint: https://gitlab.example.com
---
mr_id: 42
mr_url: https://gitlab.example.com/project/-/merge_requests/42
title: "feat: add user authentication"
source_branch: feature/auth
target_branch: main
plan_link: docs/exec-plans/active/feature-auth.md
---
status: success
```

**退出码：** `0` 成功 | `1` 失败 | `2` 未配置

---

## Environment Variables

| 变量名 | 用途 | 对应 provider |
|---|---|---|
| `GITLAB_TOKEN` | GitLab API 认证 | gitlab |
| `GITHUB_TOKEN` | GitHub API 认证 | github |
| `YOUTRACK_TOKEN` | YouTrack API 认证 | youtrack |
| `JIRA_TOKEN` | Jira API 认证 | jira |
| `LINEAR_TOKEN` | Linear API 认证 | linear |

脚本在执行前检查对应环境变量是否存在。若不存在，输出 `not-run` 并说明缺失的配置项。

---

## Integration with Quality Score

`score-quality.sh` 不直接评分集成配置，但集成状态影响以下维度：

| 维度 | 影响 |
|---|---|
| `plan_discipline` | `plan_link_required=true` 时，PR 无 plan 链接会扣分 |
| `autonomy_readiness` | 审批工作流已定义时加分 |

---

## Integration with Context Snapshot

`update-context-snapshot.sh` 在 `Integration Status` 部分输出：

```markdown
## Integration Status

| Integration | Provider | Status |
|---|---|---|
| Code Host | gitlab | configured (GITLAB_TOKEN present) |
| Issue Tracker | youtrack | not-run (YOUTRACK_TOKEN missing) |
| MCP | disabled | — |
```

---

## Security Considerations

1. **Token 存储**：所有 token 通过环境变量传递，配置文件中仅存储变量名
2. **Token 验证**：脚本仅检查环境变量是否存在，不验证 token 有效性（避免不必要的 API 调用）
3. **最小权限**：建议为每个集成使用最小权限的 token（如 GitLab 的 read_api + write_repository）
4. **审计**：所有集成操作的输入/输出记录到 `.harness/runs/` 目录
5. **MCP 边界**：危险操作在任何模式下都阻断，不受 bootstrap/enforced 模式影响

---

## Stub Behavior Contract

当 provider 为 `not-configured` 或 token 环境变量未设置时：

1. 脚本输出 `not-run` 状态（非 pass、非 fail）
2. 说明未执行的命令
3. 说明原因（哪个配置缺失）
4. 说明残余风险
5. 退出码为 `2`

绝不输出 fake success。绝不在输出中暴露 token 值。
