---
name: harness-init
version: 4.0.0
description: 初始化并持续维护 agent-readable engineering harness：包括导航、文档、计划、门禁、回归夹具、worktree sandbox、UI verification、observability、quality score、context snapshot、MCP/GitLab/YouTrack integrations 和 subagent workflows。支持 Node/TypeScript、Python、Go、Rust、Java、Kotlin 及 Monorepo 项目。Use when the request mentions harness init, setup harness, initialize agent infrastructure, bootstrap AGENTS.md, create docs scaffold, establish agent-ready engineering constraints, score quality, update context, repair drift, or when the user wants to set up or maintain agent tooling for a project.
---

# Harness Init

为项目建立可持续演化的 agent harness。目标不是堆叠 prompt，而是把上下文、约束、验证和治理写回仓库。

## Core Principles

1. 先盘点现状，再初始化。不覆盖已有文件。
2. 入口文件是目录，不是百科全书。导航文件控制在 100-200 行。
3. 知识放进仓库，约束做成可检查规则，反馈做成固定闭环。
4. 优先建立最小可运行 harness，再补充深度治理。
5. 多套规则冲突时显式记录并请求用户决定。
6. 所有修改使用 Read → compare → patch/append 策略。重复运行不产生重复内容（幂等性）。
7. Harness 是 AI 工程协作的控制系统：导航与计划提供前馈，门禁与可观测性提供反馈，scorecard 与自治等级调节控制强度，熵治理与 repair mode 维持稳定。该模型只解释现有机制，不新增第二套流程或目录。

## Key Policies

**Canonical Path Policy**: 唯一事实源在 `docs/` 和 `scripts/harness/`。Legacy path 只能是 alias/wrapper。详见 `references/quality-gates.md`。

**Strong Gate Policy**: plan-required、architecture-boundary、alias-integrity、wrapper-integrity、placeholder-angle 默认强制。`security/auth/data-migration` 在两轨都阻断。

**Navigation Scope Isolation**: Root navigation 只做全局索引。项目命令写入最近的 project-level navigation。禁止 `cd apps/xxx` 出现在 root。

**Contract Version**: v3。所有生成块包含 `Harness Init Contract Version: v3`、`Generated/Updated by: harness-init`、`Scope: <root|project|nested-project>`。保留 v2 识别能力，repair mode 提供迁移建议。

**Status Semantics**: 仅使用 `pass` / `fail` / `warn` / `not-run`。禁止 not-run 伪装为 pass。

**Gate Output**: 所有失败必须输出 Reason / Evidence / Fix / Docs / Bypass。

**Unknown Stack**: 未知值用 `TODO: 待补充`，不用 `<...>`。

**Degraded Mode**: preflight 失败不阻塞骨架落地，但必须标注 not-run 及原因。

## Reference Files

按需加载，不要一次性全部读入：

| 文件 | 内容 | 何时加载 |
|------|------|----------|
| `references/workflow-steps.md` | Step 0-7 详细执行逻辑 | 执行初始化时 |
| `references/validation-scripts.md` | Step 8 验证脚本和检查清单 | 验证阶段 |
| `references/stack-detection.md` | 项目类型识别与命令映射 | Step 1 |
| `references/nav-templates.md` | 导航文件完整模板 | Step 2 |
| `references/docs-templates.md` | docs/ 各文件模板 | Step 3 |
| `references/tooling-templates.md` | lint/test/type-check 配置 | Step 4-5 |
| `references/structure-tests.md` | 结构测试与循环依赖检测 | Step 5 |
| `references/exec-plan-templates.md` | 执行计划模板与 plan-required 规则 | Step 3/5 |
| `references/ci-governance.md` | 双轨 CI 与升级/降级策略 | Step 5.5 |
| `references/quality-gates.md` | 强门禁矩阵与脚本规范 | Step 5/8 |
| `references/agent-autonomy.md` | L1-L4 自治策略 | Step 3/5.5 |
| `references/observability-templates.md` | 可观测性运行面模板 | Step 4 |
| `references/gc-templates.md` | 熵管理、漂移检测、GC 配置 | Step 7 |
| `references/runtime-preflight.md` | 运行时预检查与跨 shell 兼容 | Step 0/1/4/8 |
| `references/report-templates.md` | 初始化报告模板 | Step 0/9 |
| `references/repair-mode.md` | repair / drift-fix 规范 | Repair Mode |
| `references/regression-fixtures.md` | 回归夹具矩阵 | 回归验证 |
| `references/runtime-surface.md` | 目标项目运行面定义 | Step 4 |
| `references/worktree-sandbox.md` | Worktree sandbox 规范 | Step 4 |
| `references/ui-verification.md` | UI verification 规范 | Step 4 |
| `references/observability-runtime.md` | Logs/metrics/traces 查询 | Step 4 |
| `references/scorecard-templates.md` | 质量评分模板 | Step 5.5 |
| `references/context-snapshot.md` | 上下文快照模板 | Step 2.5/7 |
| `references/mcp-integrations.md` | MCP/GitLab/YouTrack 集成 | Step 6 |
| `references/subagent-workflows.md` | 子智能体工作流规范 | Step 6 |
| `references/security-templates.md` | 安全威胁模型模板 | Step 5 |
| `references/permission-boundaries.md` | 权限边界与审批策略 | Step 5 |
| `references/artifact-schema.md` | 结构化 artifact schema 与 completion authority 边界 | Step 2.5/6/8 |
| `references/trigger-health.md` | skill 触发诊断、fast path cheapness 与 re-entry 检查 | 调整触发规则或排查误触发时 |

## Execution Flow

```
- [ ] Step 0: Runtime Preflight + Dry-run Plan
- [ ] Step 1: Inventory + Scope Detection
- [ ] Step 2: Navigation Initialization
- [ ] Step 2.5: Context Snapshot Initialization
- [ ] Step 3: Docs Scaffold
- [ ] Step 4: Runtime Surface + Observability + UI Verification
- [ ] Step 5: Structure Tests + Critical Gates
- [ ] Step 5.5: Quality Score + CI Governance
- [ ] Step 6: Feedback Loops + Integrations
- [ ] Step 7: Entropy GC + Doc Gardening
- [ ] Step 8: Self-Test + Regression Fixtures
- [ ] Step 9: Init Report + Next Actions
```

Each step supports: dry-run, apply, repair, degraded mode, idempotency.

详细执行逻辑见 `references/workflow-steps.md`。
验证脚本和检查清单见 `references/validation-scripts.md`。

## Mode Detection

1. Detect repository root and project boundaries.
2. Count project roots → decide mode:
   - **Mode A (single-project)**: Root navigation file for the project.
   - **Mode B (multi-project)**: Root as index only; project-level navigation per project.
   - **Mode C (nested-project)**: Local navigation only; don't modify parent root.

## Selective Init

```bash
harness-init scope=apps/editor
```

Only initializes the specified scope. Does not modify sibling projects.

## Acceptance Criteria (Summary)

- Correctly detects single/multi/nested-project repos
- Root navigation remains global-only in multi-project
- Project-specific commands never enter root navigation
- Architecture rules are executable and CI-enforced
- Dual-track CI (bootstrap + enforced) with promotion criteria
- Feedback-to-hardening loop codified
- Generated sections are marker-based and idempotent
- `<...>` placeholders fail; TODO placeholders warn
- `not-run` never counted as pass
- All gate failures include Reason/Evidence/Fix/Docs/Bypass

Full acceptance criteria: `references/validation-scripts.md`
