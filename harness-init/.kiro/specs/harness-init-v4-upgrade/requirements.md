# Requirements Document

## Introduction

将 `harness-init` 从 v3（高级工程治理 Skill）升级为 v4（智能体可驾驶工程操作系统初始化器）。本次升级采用增量方式，在保留现有 v3 结构的基础上，补齐自测试基础设施、agent-readable runtime、深度可观测性、质量评分、上下文快照、子智能体工作流、外部集成和安全边界等能力。

## Glossary

- **Harness_Init**: 项目 harness 基础设施初始化 Skill，负责生成导航文件、文档骨架、门禁脚本、运行时配置等工件
- **Fixture**: 用于测试 Harness_Init 自身行为的模拟项目目录结构
- **Golden_Test**: 将 Harness_Init 输出与预期基准文件进行比对的回归测试
- **Worktree_Sandbox**: 基于 git worktree 创建的隔离工作环境，用于在不影响主工作区的情况下执行任务
- **Gate**: 质量门禁检查脚本，输出 pass/fail/warn/not-run 状态
- **Scorecard**: 基于 7 个维度对项目 harness 质量进行量化评分的配置文件
- **Context_Snapshot**: 记录当前项目状态摘要的文档，供新会话 agent 快速恢复上下文
- **Subagent_Workflow**: 定义子智能体协作的路由规则、审查标准和工作流程
- **MCP**: Model Context Protocol，智能体与外部工具交互的协议
- **EARS_Pattern**: Easy Approach to Requirements Syntax，需求书写模式
- **Canonical_Path**: 唯一事实源路径，legacy path 只能作为 alias/wrapper
- **Degraded_Mode**: 运行时依赖不可用时的降级执行模式
- **Idempotent_Operation**: 重复执行产生相同结果、不产生重复内容的操作
- **Contract_Version**: Harness Init 生成块的版本标识，本次从 v2 升级到 v3
- **Runtime_Surface**: 目标项目的运行面定义，包括 dev server、health check、测试命令等
- **UI_Verification**: 通过 DOM snapshot、截图、console 检查等方式验证 UI 正确性的能力
- **Observability_Runtime**: logs/metrics/traces 的程序化查询能力
- **Integration_Provider**: 外部集成服务提供者（GitLab、YouTrack、MCP server 等）

## Requirements

### Requirement 1: 自测试基础设施 - Fixture 体系

**User Story:** 作为 Harness_Init 维护者，我希望拥有一套 fixture 测试体系，以便在修改模板后能自动检测回归问题。

#### Acceptance Criteria

1. THE Harness_Init SHALL 提供至少 8 个 fixture 目录，分别覆盖 single-node-ts、pnpm-monorepo、nested-project、polluted-root-nav、unknown-stack、existing-claude-only、legacy-docs-drift 和 windows-no-bash 场景
2. WHEN `tests/run-fixtures.sh` 被执行时，THE Test_Runner SHALL 将每个 fixture 复制到临时目录、执行 dry-run、执行 init、再次执行 init，并输出每个 fixture 的 pass/fail 结果
3. WHEN 某个 fixture 测试失败时，THE Test_Runner SHALL 输出包含 Reason、Evidence、Fix、Docs 字段的结构化失败信息
4. THE Harness_Init SHALL 在 `fixtures/single-node-ts/` 中包含 package.json、tsconfig.json 和 src/index.ts 作为最低内容
5. THE Harness_Init SHALL 在 `fixtures/pnpm-monorepo/` 中包含 pnpm-workspace.yaml、根 package.json、apps/editor/package.json 和 packages/ui/package.json 作为最低内容
6. THE Harness_Init SHALL 在 `fixtures/polluted-root-nav/` 中包含一个故意含有项目级命令（如 `cd apps/editor && npm run dev`）的 AGENTS.md 文件

### Requirement 2: 自测试基础设施 - 幂等性断言

**User Story:** 作为 Harness_Init 维护者，我希望验证重复执行不会产生重复内容，以确保操作的幂等性。

#### Acceptance Criteria

1. WHEN `tests/assert-idempotent.sh` 被执行时，THE Idempotency_Checker SHALL 验证重复运行 Harness_Init 不会产生重复 marker block
2. WHEN `tests/assert-idempotent.sh` 被执行时，THE Idempotency_Checker SHALL 验证重复运行不会产生重复 package.json scripts 条目
3. WHEN `tests/assert-idempotent.sh` 被执行时，THE Idempotency_Checker SHALL 验证重复运行不会产生重复 docs section
4. WHEN 第二次执行 Harness_Init 后文件内容与第一次执行后完全相同时，THE Idempotency_Checker SHALL 输出 pass

### Requirement 3: 自测试基础设施 - Root Navigation 清洁断言

**User Story:** 作为 Harness_Init 维护者，我希望自动检测 root navigation 文件是否被项目级命令污染。

#### Acceptance Criteria

1. WHEN `tests/assert-root-nav-clean.sh` 被执行时，THE Root_Nav_Checker SHALL 检测 root navigation 文件中是否包含 `cd apps/` 或 `cd packages/` 模式
2. WHEN root navigation 文件包含项目特定环境变量或数据库配置时，THE Root_Nav_Checker SHALL 输出 fail 并标明具体行号
3. WHEN root navigation 文件仅包含全局规则、仓库布局和项目索引时，THE Root_Nav_Checker SHALL 输出 pass

### Requirement 4: 自测试基础设施 - Placeholder 门禁断言

**User Story:** 作为 Harness_Init 维护者，我希望确保生成的目标文件中不包含 `<...>` 格式的占位符。

#### Acceptance Criteria

1. WHEN `tests/assert-placeholder-gate.sh` 被执行时，THE Placeholder_Checker SHALL 扫描所有生成文件中的 `<...>` 模式
2. WHEN 生成文件中存在 `<...>` 格式占位符时，THE Placeholder_Checker SHALL 输出 fail
3. WHEN 值无法确定时，THE Harness_Init SHALL 使用 `TODO: 待补充` 替代 `<...>` 占位符
4. THE Placeholder_Checker SHALL 将 `TODO`、`FIXME`、`TBD`、`待补充` 标记为 warn 而非 fail

### Requirement 5: Agent-Readable Runtime - Worktree Sandbox

**User Story:** 作为使用 Harness_Init 的智能体，我希望能在隔离的 worktree 中执行任务，以避免影响主工作区。

#### Acceptance Criteria

1. WHEN `scripts/harness/worktree-create.sh <task-id> <branch>` 被执行时，THE Worktree_Manager SHALL 在 `.worktrees/harness-<task-id>` 路径创建 git worktree
2. WHEN 目标 worktree 路径已存在时，THE Worktree_Manager SHALL 输出 warn 并提供清理命令，不自动覆盖
3. WHEN `scripts/harness/worktree-clean.sh` 被执行时，THE Worktree_Manager SHALL 仅清理 `.worktrees/harness-*` 路径下的目录
4. WHEN worktree 中存在未提交改动时，THE Worktree_Manager SHALL 默认拒绝清理，除非提供 `--force` 参数
5. IF 清理路径不在 `.worktrees/` 目录下，THEN THE Worktree_Manager SHALL 拒绝执行并输出错误信息
6. WHEN `scripts/harness/worktree-run.sh <task-id> <command>` 被执行时，THE Worktree_Manager SHALL 在对应 worktree 中执行命令并将 stdout/stderr 捕获到 `.harness/runs/<task-id>/`
7. THE Worktree_Manager SHALL 在 worktree 脚本中禁止删除主工作区的任何操作

### Requirement 6: Agent-Readable Runtime - UI Verification

**User Story:** 作为使用 Harness_Init 的智能体，我希望能验证 UI 的正确性，包括 DOM 状态、截图和 console 错误。

#### Acceptance Criteria

1. WHEN `scripts/harness/capture-dom.sh` 被执行且 `.harness/runtime.yml` 中 `ui.provider` 为 `playwright` 时，THE UI_Verifier SHALL 使用 Playwright 捕获 DOM snapshot 并保存到 `.harness/artifacts/dom/<timestamp>.html`
2. WHEN `scripts/harness/capture-screenshot.sh` 被执行时，THE UI_Verifier SHALL 捕获页面截图并保存到 `.harness/artifacts/screenshots/<timestamp>.png`
3. WHEN `scripts/harness/check-console.sh` 被执行且发现 console error 时，THE UI_Verifier SHALL 输出 fail，除非该 error 在 allowlist 中
4. IF `.harness/runtime.yml` 中 `ui.provider` 为 `not-configured`，THEN THE UI_Verifier SHALL 输出 `not-run: UI verification backend is not configured.`
5. WHEN `scripts/harness/verify-user-journey.sh <journey-name>` 被执行时，THE UI_Verifier SHALL 根据 `.harness/user-journeys/<journey-name>.yml` 执行关键路径并生成 DOM、截图、console、network 报告

### Requirement 7: 深度可观测性

**User Story:** 作为使用 Harness_Init 的智能体，我希望能程序化查询 logs、metrics 和 traces，以便诊断问题。

#### Acceptance Criteria

1. WHEN `scripts/harness/query-logs.sh --since <duration> --level <level> --keyword <keyword>` 被执行时，THE Observability_Engine SHALL 根据 `.harness/observability.yml` 中配置的 provider 查询日志
2. WHEN logs provider 为 `file` 时，THE Observability_Engine SHALL 使用 grep/rg 搜索本地日志文件
3. IF logs provider endpoint 未配置，THEN THE Observability_Engine SHALL 输出 `not-run` 并说明原因
4. WHEN `scripts/harness/query-metrics.sh` 被执行时，THE Observability_Engine SHALL 支持 Prometheus 和 VictoriaMetrics 的 PromQL 查询
5. WHEN `scripts/harness/query-traces.sh` 被执行时，THE Observability_Engine SHALL 支持按 trace id 或 service name 查询
6. THE Harness_Init SHALL 生成 `.harness/observability.yml` 配置文件，包含 logs、metrics、traces 的 provider 和 endpoint 配置

### Requirement 8: 质量评分系统

**User Story:** 作为项目管理者，我希望能量化评估项目 harness 的质量，以便数据驱动地决定自治等级升降级。

#### Acceptance Criteria

1. THE Scorecard SHALL 基于 7 个维度评分：context_readability(20)、plan_discipline(15)、architecture_enforcement(20)、test_confidence(15)、observability_surface(15)、entropy_control(10)、autonomy_readiness(5)，满分 100
2. WHEN `scripts/harness/score-quality.sh` 被执行时，THE Quality_Scorer SHALL 读取 `.harness/scorecard.yml` 并输出当前分数、模式建议和自治等级建议
3. WHEN 某个维度存在 blocking issue 时，THE Quality_Scorer SHALL 在输出中列出具体问题和修复建议
4. THE Quality_Scorer SHALL 使用以下阈值判断模式建议：bootstrap_min=60、enforced_min=80、autonomy_l3_min=85、autonomy_l4_min=92
5. IF 某个检查项未配置导致无法评估，THEN THE Quality_Scorer SHALL 对该项扣分，不得因未配置而给予 pass 分数

### Requirement 9: 上下文快照

**User Story:** 作为在新会话中工作的智能体，我希望能快速恢复项目当前状态，而无需重新扫描所有文档。

#### Acceptance Criteria

1. THE Context_Snapshot SHALL 生成 `docs/harness/context-snapshot.md`，包含 CI Mode、Autonomy Level、Quality Score、Active Plans、Recently Completed Plans、Open Tech Debts、Failing Gates、Active ADR Exceptions、Recent Incidents、Integration Status 和 Next Recommended Actions
2. WHEN `scripts/harness/update-context-snapshot.sh` 被执行时，THE Snapshot_Updater SHALL 扫描 active plans、completed plans、tech-debt-tracker、ADR exceptions、scorecard 和 autonomy 配置并更新快照
3. THE Context_Snapshot SHALL 包含 `Last Updated` 时间戳
4. THE Context_Snapshot SHALL 作为索引文档存在，不替代源文档中的详细信息

### Requirement 10: 子智能体工作流系统

**User Story:** 作为使用多智能体协作的团队，我希望有明确的路由规则和工作流定义，以便自动分配任务和验收。

#### Acceptance Criteria

1. THE Harness_Init SHALL 生成 `subagents/routing-rules.yml`，定义基于 changed_paths 和 labels 的角色路由规则
2. WHEN 变更路径匹配 routing rule 时，THE Workflow_Router SHALL 要求对应角色参与审查
3. WHEN routing rule 标记为 `blocking: true` 时，THE Workflow_Router SHALL 阻断合并直到所有必需角色完成审查
4. THE Harness_Init SHALL 为每个 workflow（feature-delivery、bug-fix、architecture-change、schema-migration、release）生成包含 Trigger、Required Roles、Required Input/Output Artifacts、Required Gates、Skip Conditions 和 Completion Criteria 的定义文件
5. WHEN feature-delivery workflow 被触发时，THE Workflow_Engine SHALL 检查是否需要 ExecPlan 并验证 lint/test/typecheck/build 通过
6. WHEN bug-fix workflow 中同类问题第二次出现时，THE Workflow_Engine SHALL 要求将修复固化为 gate/test/rule/ADR 之一

### Requirement 11: 外部集成（GitLab/YouTrack/MCP）

**User Story:** 作为使用 GitLab 和 YouTrack 的团队，我希望 Harness_Init 能生成集成配置模板，以便智能体能与研发系统交互。

#### Acceptance Criteria

1. THE Harness_Init SHALL 生成 `.harness/integrations.yml`，包含 code_host、issue_tracker 和 mcp 的配置模板
2. THE Harness_Init SHALL 在所有集成配置中仅使用环境变量占位（如 `GITLAB_TOKEN`、`YOUTRACK_TOKEN`），不写入真实 token
3. IF `GITLAB_TOKEN` 或 GitLab base_url 未配置，THEN THE Integration_Scripts SHALL 输出 `not-run: GITLAB_TOKEN or GitLab base_url is not configured.`
4. THE Harness_Init SHALL 定义 MCP 危险操作列表（delete、force-push、production-deploy、permission-change、database-migration、secret-rotation），并要求人工审批
5. WHEN MCP 危险操作被请求时，THE Permission_Boundary SHALL 阻断执行直到获得人工审批

### Requirement 12: 安全边界

**User Story:** 作为安全负责人，我希望 Harness_Init 能生成安全威胁模型和检查脚本，以防止密钥泄露和未授权操作。

#### Acceptance Criteria

1. THE Harness_Init SHALL 生成 `docs/security-threat-model.md`，包含 Assets、Trust Boundaries、Secrets Handling、MCP Tool Boundaries、Dangerous Operations、Required Human Approval、Audit Trail 和 Incident Response 章节
2. WHEN `scripts/harness/check-secrets.sh` 被执行时，THE Secret_Checker SHALL 检测 `.env` 是否被 git 跟踪、常见 token pattern、private key pattern 和 CI 配置中的硬编码 token
3. WHEN 发现密钥泄露风险时，THE Secret_Checker SHALL 输出 fail 并提供具体文件和行号
4. WHEN `scripts/harness/check-permissions.sh` 被执行时，THE Permission_Checker SHALL 验证 `.harness/integrations.yml` 中危险操作是否配置了 approval policy
5. THE Harness_Init SHALL 在任何模式下（bootstrap 或 enforced）对密钥泄露、未授权 auth 改动和无 rollback 的 data migration 进行阻断

### Requirement 13: 增强型门禁输出

**User Story:** 作为使用 Harness_Init 的智能体，我希望门禁失败时能获得可操作的修复信息，而非仅仅一个 fail 状态。

#### Acceptance Criteria

1. WHEN 任何 Gate 检查失败时，THE Gate SHALL 输出包含 Reason、Evidence、Fix、Docs 和 Bypass 五个字段的结构化信息
2. THE Gate SHALL 禁止仅输出 `FAIL`、`error` 或 `not valid` 等不含修复信息的失败消息
3. WHEN Gate 检查结果为 not-run 时，THE Gate SHALL 说明未执行的命令、原因和残余风险
4. WHILE 处于 enforced 模式时，THE Gate SHALL 将关键 gate 的 not-run 状态视为 fail，除非存在有效的 ADR exception
5. WHILE 处于 bootstrap 模式时，THE Gate SHALL 允许非关键检查的 warn/not-run 通过，但安全相关检查仍必须阻断

### Requirement 14: CI 模板

**User Story:** 作为 DevOps 工程师，我希望 Harness_Init 能生成 GitHub Actions 和 GitLab CI 模板，以便在 CI 中执行 harness 检查。

#### Acceptance Criteria

1. THE Harness_Init SHALL 生成 `templates/.github/workflows/harness.yml`，包含 harness-critical、harness-docs、harness-score、harness-security 和 harness-self-test 五个 jobs
2. THE Harness_Init SHALL 生成 `templates/gitlab-ci/harness.gitlab-ci.yml`，包含 harness-preflight、harness-gates、harness-score 和 harness-security 四个 stages
3. WHEN 环境变量 `HARNESS_CI_MODE` 为 `bootstrap` 时，THE CI_Pipeline SHALL 允许非关键检查的 warn/not-run 通过，但 critical security 检查仍阻断
4. WHEN 环境变量 `HARNESS_CI_MODE` 为 `enforced` 时，THE CI_Pipeline SHALL 对关键 gate 的 warn/not-run 也执行阻断

### Requirement 15: 版本升级与兼容性

**User Story:** 作为 Harness_Init 用户，我希望从 v3 升级到 v4 时保持向后兼容，不丢失已有配置。

#### Acceptance Criteria

1. THE Harness_Init SHALL 将 SKILL.md metadata 中的 version 从 3.0.0 升级为 4.0.0
2. THE Harness_Init SHALL 将 Contract Version 从 v2 升级为 v3，所有新生成 marker 包含 `Harness Init Contract Version: v3`、`Generated/Updated by: harness-init` 和 `Scope: <root|project|nested-project>`
3. THE Harness_Init SHALL 保留对 v2 生成块的识别能力，不重复生成 v2 已有内容
4. WHEN 处于 repair mode 时，THE Harness_Init SHALL 能识别 v2 到 v3 的迁移建议，但不自动删除 v2 旧块
5. THE Harness_Init SHALL 保留所有现有 canonical docs 路径和 legacy alias 策略不变

### Requirement 16: 幂等性与增量修改

**User Story:** 作为 Harness_Init 用户，我希望重复执行初始化不会产生重复内容或覆盖已有用户文件。

#### Acceptance Criteria

1. THE Harness_Init SHALL 对所有修改采用 read → compare → patch/append 策略
2. THE Harness_Init SHALL 在同一命令重复执行两次后不产生重复 marker 或重复内容
3. THE Harness_Init SHALL 对已有配置文件仅追加带 marker 的 harness section，不覆盖用户已有内容
4. WHEN package.json 已存在时，THE Harness_Init SHALL 仅 merge 缺失的 scripts 条目
5. WHEN Makefile 已存在时，THE Harness_Init SHALL 仅 append 缺失的 targets
6. WHEN CI/hook 文件已存在时，THE Harness_Init SHALL 保留已有 jobs 并添加标记的 harness section

### Requirement 17: Monorepo/Nested-Project 隔离

**User Story:** 作为 monorepo 项目的维护者，我希望 Harness_Init 不会将项目级命令污染到 root navigation 文件。

#### Acceptance Criteria

1. THE Harness_Init SHALL 在 multi-project 模式下将 root navigation 文件仅用作全局索引和规则入口
2. THE Harness_Init SHALL 将项目级命令写入最近的 project-level navigation 文件
3. THE Harness_Init SHALL 禁止在 root navigation 中出现 `cd apps/xxx` 类项目级命令
4. WHEN 处于 nested-project 模式时，THE Harness_Init SHALL 仅更新当前项目作用域，不修改父级 root navigation 文件（除非用户明确要求）
5. THE Harness_Init SHALL 在所有生成块中包含 scope 信息（root/project/nested-project）

### Requirement 18: 状态语义一致性

**User Story:** 作为使用 Harness_Init 的智能体，我希望所有检查结果使用统一的状态语义，以便程序化处理。

#### Acceptance Criteria

1. THE Harness_Init SHALL 仅使用 pass、fail、warn、not-run 四种状态标识检查结果
2. THE Harness_Init SHALL 禁止将 not-run 伪装为 pass
3. WHEN 依赖未安装、后端未配置或命令未找到时，THE Harness_Init SHALL 输出 not-run 或 warn，不输出 pass
4. WHEN 检查结果为 not-run 时，THE Harness_Init SHALL 记录未执行的命令、原因和残余风险
5. WHILE 处于 enforced 模式时，THE Harness_Init SHALL 将关键 gate 的 not-run 默认视为 fail，除非 ADR exception 明确允许

### Requirement 19: Runtime Surface 定义

**User Story:** 作为使用 Harness_Init 的智能体，我希望能读取目标项目的运行面定义，以便自动执行开发、测试和验证操作。

#### Acceptance Criteria

1. THE Harness_Init SHALL 生成 `.harness/runtime.yml`，包含 dev server 启动命令、health check URL、lint/test/typecheck/build 命令、本地日志路径和 UI provider 配置
2. WHEN runtime.yml 中某个值无法确定时，THE Harness_Init SHALL 使用 `TODO: 待补充` 作为占位值
3. THE Harness_Init SHALL 生成 `docs/runtime-surface.md`，文档化项目运行面的完整定义
4. THE Harness_Init SHALL 在 runtime.yml 中支持 `not-configured` 作为 UI provider 的默认值

### Requirement 20: 初始化流程更新

**User Story:** 作为 Harness_Init 维护者，我希望将执行流程更新为 v4 版本，涵盖所有新增能力。

#### Acceptance Criteria

1. THE Harness_Init SHALL 将 Execution Flow 更新为 10 步：Step 0(Runtime Preflight + Dry-run Plan)、Step 1(Inventory + Scope Detection)、Step 2(Navigation Initialization)、Step 2.5(Context Snapshot Initialization)、Step 3(Docs Scaffold)、Step 4(Runtime Surface + Observability + UI Verification)、Step 5(Structure Tests + Critical Gates)、Step 5.5(Quality Score + CI Governance)、Step 6(Feedback Loops + Integrations)、Step 7(Entropy GC + Doc Gardening)、Step 8(Self-Test + Regression Fixtures)、Step 9(Init Report + Next Actions)
2. THE Harness_Init SHALL 在每一步支持 dry-run、apply、repair 和 degraded mode 四种执行模式
3. WHEN 每一步执行完成时，THE Harness_Init SHALL 保证该步骤的幂等性

### Requirement 21: 目录结构新增

**User Story:** 作为 Harness_Init 维护者，我希望在 Skill 项目中新增 fixtures、tests、templates 目录结构，以支持自测试和模板管理。

#### Acceptance Criteria

1. THE Harness_Init SHALL 新增 `fixtures/` 目录，包含至少 8 个场景的 fixture 子目录
2. THE Harness_Init SHALL 新增 `tests/` 目录，包含 run-fixtures.sh 和各类 assert 脚本
3. THE Harness_Init SHALL 新增 `templates/` 目录，包含 scripts/harness/、scripts/harness-pwsh/、.harness/、.github/workflows/ 和 gitlab-ci/ 子目录
4. THE Harness_Init SHALL 保留现有 `references/` 和 `subagents/` 目录不变
5. THE Harness_Init SHALL 新增 `references/runtime-surface.md`、`references/worktree-sandbox.md`、`references/ui-verification.md`、`references/observability-runtime.md`、`references/scorecard-templates.md`、`references/context-snapshot.md`、`references/mcp-integrations.md`、`references/subagent-workflows.md`、`references/security-templates.md` 和 `references/permission-boundaries.md`

### Requirement 22: Init Report 输出

**User Story:** 作为 Harness_Init 用户，我希望初始化完成后能获得一份完整的变更报告，了解生成了什么、修改了什么、跳过了什么。

#### Acceptance Criteria

1. WHEN Step 9 执行完成时，THE Harness_Init SHALL 输出包含 Summary、Generated Files、Modified Files、Skipped Files、Degraded Mode Items、Gate Results、Quality Score、Integration Status 和 Next Actions 的 Init Report
2. THE Init Report SHALL 对每个 Degraded Mode Item 说明原因和残余风险
3. THE Init Report SHALL 列出所有 Gate 的检查结果（pass/fail/warn/not-run）

### Requirement 23: PowerShell 降级脚本

**User Story:** 作为在 Windows 环境下工作的智能体，我希望在 bash 不可用时能通过 PowerShell 脚本执行核心 harness 检查，以保证降级模式下的基本功能。

#### Acceptance Criteria

1. THE Harness_Init SHALL 在 `templates/scripts/harness-pwsh/` 目录中提供 PowerShell 版本的核心脚本，至少包含 self-test.ps1、score-quality.ps1、update-context-snapshot.ps1、check-secrets.ps1 和 check-permissions.ps1
2. WHEN bash 运行时不可用时，THE Harness_Init SHALL 在 runtime preflight 中检测并建议使用 PowerShell 脚本作为 fallback
3. THE PowerShell_Scripts SHALL 与对应的 bash 脚本保持相同的输出格式（pass/fail/warn/not-run）和结构化失败信息（Reason/Evidence/Fix/Docs/Bypass）
4. THE PowerShell_Scripts SHALL 不要求覆盖全部 bash 脚本功能，但必须支持 degraded mode 下的核心检查能力
5. WHEN PowerShell 脚本执行的检查项少于 bash 版本时，THE PowerShell_Scripts SHALL 对未覆盖的检查项输出 not-run 并说明原因

### Requirement 24: Golden Test 基准比对

**User Story:** 作为 Harness_Init 维护者，我希望能将生成输出与预期基准文件进行比对，以检测模板回归。

#### Acceptance Criteria

1. THE Harness_Init SHALL 在 `tests/golden/` 目录中维护每个 fixture 场景的预期输出基准文件
2. WHEN `tests/assert-golden.sh` 被执行时，THE Golden_Tester SHALL 将当前 Harness_Init 生成的输出与 `tests/golden/` 中的基准文件进行 diff 比对
3. WHEN 生成输出与基准文件存在差异时，THE Golden_Tester SHALL 输出 fail 并显示具体 diff 内容、涉及的文件路径和行号
4. THE Golden_Tester SHALL 支持 `--update` 参数，用于在确认变更正确后更新基准文件
5. THE Golden_Tester SHALL 忽略时间戳、动态生成的 ID 等非确定性内容的差异

### Requirement 25: 子智能体审查标准

**User Story:** 作为参与代码审查的子智能体，我希望有明确的审查标准文档，以便按照统一的质量要求进行审查。

#### Acceptance Criteria

1. THE Harness_Init SHALL 为每个子智能体角色生成审查标准文件：`subagents/review-rubrics/architect.md`、`subagents/review-rubrics/editor-component.md`、`subagents/review-rubrics/runtime-dataflow.md`、`subagents/review-rubrics/quality-gate.md` 和 `subagents/review-rubrics/governance-context.md`
2. THE Review_Rubric SHALL 包含该角色的审查范围、必须检查的条目、通过标准和拒绝标准
3. WHEN 审查标准与 routing-rules.yml 中的角色定义不一致时，THE Harness_Init SHALL 以 routing-rules.yml 为准并在审查标准中标注引用
4. THE Review_Rubric SHALL 与 `subagents/roles.json` 中定义的 core_responsibilities 和 boundaries 保持语义一致

### Requirement 26: 集成操作脚本

**User Story:** 作为使用 GitLab/YouTrack 的智能体，我希望有可执行的集成脚本来完成 issue 同步、plan 关联、review 上下文获取和 MR 创建等操作。

#### Acceptance Criteria

1. THE Harness_Init SHALL 生成 `scripts/harness/sync-issues.sh`，用于从 issue tracker 同步 issue 状态到本地 plan 文件
2. THE Harness_Init SHALL 生成 `scripts/harness/link-plan-to-issue.sh`，用于将 ExecPlan 与 issue tracker 中的 issue 建立双向链接
3. THE Harness_Init SHALL 生成 `scripts/harness/fetch-review-context.sh`，用于从 code host 获取 MR/PR 的审查上下文（评论、变更文件列表、CI 状态）
4. THE Harness_Init SHALL 生成 `scripts/harness/create-merge-request.sh`，用于创建包含 plan 链接和标准描述模板的 MR
5. IF 对应集成的 token 环境变量或 base_url 未配置，THEN THE Integration_Scripts SHALL 输出 `not-run` 并说明缺失的配置项
6. THE Integration_Scripts SHALL 在 MR 描述中自动包含关联的 ExecPlan 路径

### Requirement 27: v2 到 v3 Repair Mode 迁移

**User Story:** 作为从 v3 升级到 v4 的用户，我希望 repair mode 能识别旧版本生成块并提供具体的迁移建议，而非静默忽略或破坏已有内容。

#### Acceptance Criteria

1. WHEN 处于 repair mode 时，THE Harness_Init SHALL 扫描所有文件中包含 `Harness Init Contract Version: v2` 的生成块
2. WHEN 发现 v2 生成块时，THE Harness_Init SHALL 输出迁移建议，包含：旧块位置、建议的 v3 替换内容、迁移步骤和风险说明
3. THE Harness_Init SHALL 在 repair mode 中不自动删除 v2 旧块，仅在用户执行 `repair apply` 时才执行实际迁移
4. WHEN v2 块与 v3 新生成内容存在功能重叠时，THE Harness_Init SHALL 标记冲突并要求用户决定保留策略
5. THE Harness_Init SHALL 在 repair mode 输出中为每个 v2 块提供 `keep`（保留不变）、`migrate`（迁移到 v3）和 `remove`（删除）三种选项
