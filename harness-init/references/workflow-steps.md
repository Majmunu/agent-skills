# Workflow Steps (Step 0–8 Detailed Execution Logic)

> Extracted from SKILL.md v4.0.0. This file contains the detailed implementation logic for each initialization step.
> Load this file when executing harness-init. For validation scripts and checklists, see `validation-scripts.md`.

---

## Step 0: Dry-run Plan

**Tools**: `Read + Shell`（不写文件）

读取 `references/report-templates.md` 与 `references/runtime-preflight.md`，先执行 preflight，再输出 dry-run 计划：

- Repo mode:
- Detected project roots:
- Files to create:
- Files to update:
- Root-level writes:
- Project-level writes:
- Runtime capability matrix:
- Warnings:

规则：
- If the agent can safely edit files, proceed after producing the plan.
- If the environment is ambiguous, only produce the plan and ask for explicit confirmation.

## Step 1: Inventory Existing Harness

**Tools**: `Shell` + `Read`

读取 `references/stack-detection.md`，执行项目类型识别和现状盘点。
若用户提供 `scope=<path>`，先设置 `HARNESS_TARGET_SCOPE=<path>`，仅盘点该作用域并限制后续写入范围。
若 preflight 显示 `bash`/`git` 不可用，按 `references/runtime-preflight.md` 使用 PowerShell 等效命令并标注 degraded mode。

```bash
# 一键盘点脚本（直接执行）
echo "=== Navigation Files ===" && \
  for f in AGENTS.md CLAUDE.md; do [ -f "$f" ] && echo "EXISTS: $f" || echo "MISSING: $f"; done

echo "=== Docs ===" && \
  for d in docs/ doc/; do [ -d "$d" ] && echo "EXISTS: $d" || echo "MISSING: $d"; done

echo "=== CI & Hooks ===" && \
  for f in .github/workflows/ .husky/ .git/hooks/pre-commit pre-commit lefthook.yml .pre-commit-config.yaml; do
    [ -e "$f" ] && echo "EXISTS: $f" || echo "MISSING: $f"
  done

echo "=== Project Manifest ===" && \
  for f in package.json pyproject.toml setup.py go.mod Cargo.toml pom.xml build.gradle build.gradle.kts Makefile; do
    [ -f "$f" ] && echo "EXISTS: $f"
  done

echo "=== Existing Scripts ===" && \
  (cat package.json 2>/dev/null | python3 -c "import sys,json; s=json.load(sys.stdin).get('scripts',{}); [print(f'  {k}: {v}') for k,v in s.items()]" 2>/dev/null || true) && \
  (cat Makefile 2>/dev/null | grep "^[a-z].*:" | head -20 || true)
```

若 `bash` 或 `python3` 不可用：
- 使用 `references/runtime-preflight.md` 的 PowerShell 等效盘点命令。
- 输出必须保持同样三栏结论与 boundary report 字段，禁止因工具缺失跳过盘点结论。

根据检测结果，输出三栏清单：
- **已存在并应复用**的文件/命令
- **缺失且需要创建**的内容
- **互相冲突**的规则源（需请求用户决定主事实源）

同时输出 boundary report：
- `repository_root`: 当前执行根路径
- `project_roots`: 检测到的项目根列表
- `repo_mode`: `single-project` / `multi-project` / `nested-project`
- `workspace_candidates`: `apps/*`、`packages/*` 等候选目录及其升级理由（strong signal / source dirs / workspace 声明 / 用户指定）
- `scope`: `HARNESS_TARGET_SCOPE`（若提供）
- `ignore_rules`: `.harnessignore` + 内置忽略目录

**条件分支**：
- 若已有完整 AGENTS.md/CLAUDE.md → 不覆盖，仅按 marker 局部补充缺失区块
- 若存在 `doc/` 且已被广泛引用 → 保留 `doc/`，不强制重命名
- 若检测到 multi-project → 根导航文件仅保留全局索引；项目级命令必须写入最近项目导航文件
- 若检测到 multi-project → 根 `Shared Commands` 禁止出现项目特定命令（如 `build:editor`、`cd apps/...`）
- 若检测到 nested-project → 只更新当前项目作用域，不修改父级根导航文件（除非用户明确要求）
- 若 `.harnessignore` 不存在 → 创建默认忽略规则文件（`node_modules/`、`dist/`、`build/`、`examples/`、`fixtures/`、`vendor/`、`third_party/`）
- 若项目类型无法自动识别（罕见技术栈）→ 使用 generic harness 继续初始化，不阻塞流程；在 Commands 区块标注"待补充"，并在 ADR 记录未知技术栈

## Step 2: Create the Navigation Entry

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

读取 `references/nav-templates.md` 获取完整模板。
若目标文件已存在，除非用户明确批准，否则禁止整文件覆盖（full-file replacement）。
所有新增 marker 必须带 `version=2`，并在生成区块写入 contract 元信息。

选择策略：
- Mode A（single-project）：
  - 根目录创建/更新主导航文件（`AGENTS.md` 或 `CLAUDE.md`）
  - 默认同步创建/更新另一个导航文件，并保持语义等价（strict parity）
- Mode B（multi-project）：
  - 根目录创建/更新索引型导航文件（只含全局规则、仓库布局、项目索引、共享约束）
  - 为每个检测到的项目根创建/更新项目级导航文件（`AGENTS.md` 或 `CLAUDE.md`）
  - 项目命令、项目约束、项目验证只写在项目级导航文件
  - 若同时生成 `AGENTS.md` 与 `CLAUDE.md`，两者必须保持同作用域语义等价，禁止仅保留"跳转指针"导致信息不对称
- Mode C（nested-project）：
  - 仅在当前子项目作用域创建/更新本地导航文件（`AGENTS.md` 或 `CLAUDE.md`）
  - 不修改父仓库根导航文件（除非用户明确要求）

导航文件只包含：项目概览、关键目录导航、运行命令、硬约束、深层文档入口。控制在 100-200 行。

## Step 2.5: Configure Dynamic Context (Optional)

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

在导航文件中补充动态上下文入口：

规则：
- single-project：可直接写入根 `AGENTS.md` / `CLAUDE.md`。
- multi-project：`Runtime Context` 必须写入项目级导航文件（`AGENTS.md` 或 `CLAUDE.md`），除非该状态/命令明确适用于全仓库。
- nested-project：只写当前项目作用域，不写父级根文件。

```md
## Runtime Context

- Health: `<health check command or URL>`
- CI status: `<CI provider link>`
- Logs: `logs/` or `<log command>`
- Outdated deps: `<outdated check command>`  ← 见 references/stack-detection.md 各栈命令
```

## Step 3: Scaffold the Documentation System of Record

**Tools**: `Read + Edit/Patch + Write`（逐文件写入；仅新文件使用 Write）

读取 `references/docs-templates.md` 获取各文件模板内容。

创建以下结构（没有价值的空文件不要创建）：

```
docs/
├── architecture-boundaries.md
├── constraints.md
├── testing.md
├── ci-governance.md
├── agent-autonomy.md
├── observability.md
├── feedback-loops.md
├── entropy-gc.md
├── exec-plans/
│   ├── active/
│   ├── completed/
│   └── tech-debt-tracker.md
├── harness/
│   └── doc-gardening-report.md  ← 由自动任务生成，可延后创建
├── modules/
│   └── README.md       ← 模块文档索引
└── decisions/
    └── ADR-0001-harness-init.md
```

若为 multi-project，docs 必须分层隔离：

```txt
repo/
├── AGENTS.md
├── docs/                       # 仓库级事实（仅全局）
│   ├── architecture-boundaries.md
│   ├── ci-governance.md
│   ├── agent-autonomy.md
│   ├── observability.md
│   ├── feedback-loops.md
│   ├── entropy-gc.md
│   ├── exec-plans/
│   │   ├── active/
│   │   ├── completed/
│   │   └── tech-debt-tracker.md
│   ├── harness/
│   │   └── doc-gardening-report.md  # 由自动任务生成，可延后创建
│   └── decisions/
├── apps/<name>/
│   ├── AGENTS.md
│   └── docs/                   # 项目级事实（仅本项目）
│       ├── architecture-boundaries.md
│       ├── constraints.md
│       ├── testing.md
│       ├── observability.md
│       ├── feedback-loops.md
│       ├── entropy-gc.md
│       └── exec-plans/
│           ├── active/
│           ├── completed/
│           └── tech-debt-tracker.md
├── packages/<name>/
│   ├── AGENTS.md
│   └── docs/                   # 同上结构
└── services/<name>/
    ├── AGENTS.md
    └── docs/                   # 同上结构
```

规则：
- Root docs are for repository-wide facts only.
- Project docs are for project-specific facts only.
- Do not put one app's architecture into root docs unless it affects the whole repository.
- Canonical docs are source of truth; legacy docs are compatibility alias only.
- Plan Scope Policy:
  - single-project / nested-project：计划默认写入 `docs/exec-plans/*`
  - multi-project：root `docs/exec-plans/*` 仅用于跨项目/仓库级计划；项目级计划写入 `<project>/docs/exec-plans/*`
- 中大型任务（跨模块、跨项目、架构重构）必须先建计划文件再开工。
- 涉及跨模块改动的 PR 必须关联 plan 文件（支持 root 与 project scope 路径）。

## Step 4: Install Guides, Sensors and Observability

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write） + `Shell`（验证命令可执行性）

读取 `references/tooling-templates.md` 与 `references/observability-templates.md`，根据 Step 1 识别的技术栈选择对应模板。

**Guides**（前馈控制）:
- `AGENTS.md` / `CLAUDE.md`
- `docs/architecture-boundaries.md`、`docs/constraints.md`、`docs/ci-governance.md`

**Sensors**（反馈控制）:
- lint、type-check、tests、structure checks、reviewer

**Observability**（可观测运行环境）:
- 确保 `dev` 命令可用且能快速启动
- 配置日志可访问路径
- 配置基本健康检查命令
- 补齐最小可观测脚本：`scripts/harness/query-logs.sh`、`scripts/harness/query-metrics.sh`（至少支持关键 SLO 程序化验证）
- 补齐统一运行面脚本：`scripts/harness/reproduce.sh`、`scripts/harness/validate.sh`、`scripts/harness/regression.sh`、`scripts/harness/pre-release.sh`
- multi-project 项目级执行规则：统一从 repo root 执行，并通过 `HARNESS_TARGET_SCOPE=<project-path>` 限定作用域

写入配置后，执行以下验证：
```bash
# 验证命令语法合法（不真正运行）
# 检查 pre-commit 配置文件格式
[ -f ".pre-commit-config.yaml" ] && python3 -c "import yaml; yaml.safe_load(open('.pre-commit-config.yaml'))" && echo "pre-commit config OK"
```

若 `python3` 不可用：
- 使用 `python` 或 PowerShell YAML 解析替代；
- 若仍无法验证，结果标记 `not-run`，并在 init report 的 `Validation Not Run` 记录原因与风险。

## Step 5: Add Structure Tests and Constraint Enforcement

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write） + `Shell`

读取 `references/structure-tests.md`、`references/quality-gates.md` 与 `references/exec-plan-templates.md` 获取结构测试与门禁模板。

至少把一个架构约束变成机械检查。优先级：
1. 循环依赖检测
2. 反向依赖检测
3. 目录落位检查
4. 未授权依赖检测
5. 多项目时：根导航文件污染检测（禁止项目级命令泄漏到根文件）
6. 跨项目隐式耦合检测（禁止未授权跨作用域导入）
7. 自定义 lint（命名约定、文件大小、日志结构、边界校验）

写入结构测试后，尝试验证工具可用性：
```bash
# 示例：验证检测工具是否已安装
command -v madge >/dev/null 2>&1 && echo "madge: available" || echo "madge: not installed (run: npm i -g madge)"
```

若 `command -v` 不可用（例如纯 PowerShell 会话），使用 `Get-Command madge -ErrorAction SilentlyContinue` 等效检查。

若为 multi-project，额外集成 `references/structure-tests.md` 中的 root navigation pollution check 到 `arch-check` 或独立 CI job。
若存在明确的 repo-wide 例外命令，写入 `.harness/agents-root-allowlist.txt`，避免误报。

跨模块计划门禁：
- 若改动涉及多个模块/作用域，CI 必须校验 PR 关联 plan 文件（支持 `docs/exec-plans/*` 与 `<project>/docs/exec-plans/*`）。
- 无关联 plan 时失败（fail-fast）。
- plan 路径必须指向真实存在的文件。
- PR gate 默认仅接受 `active|completed`（生命周期可保留 `blocked|superseded`，但不授权合并）。
- 若为 `active` 或 `completed`，计划文件前 60 行必须包含 `Status:` 字段。
- multi-project 计划作用域校验：
  - 单项目作用域变更优先要求 `<project>/docs/exec-plans/*`
  - 跨项目/仓库级变更要求 `docs/exec-plans/*`
- 该门禁应仅在 PR 事件中执行；`push` 等非 PR 事件应自动跳过。
- 在 GitHub Actions 中，先写入 `github.event.pull_request.body` 到 `.harness/pr-body.txt`，再运行 `scripts/harness/check-plan-required.sh`。
- plan 路径示例：
  - `docs/exec-plans/active/<plan>.md`
  - `apps/<name>/docs/exec-plans/active/<plan>.md`
  - `services/<name>/docs/exec-plans/active/<plan>.md`

建议同步生成：
- `.harness/plan-required-rules.yml`（可机器判定触发条件）
- `scripts/harness/check-placeholders.sh`（placeholder 检查，过滤 harness marker 与注释）
- `scripts/harness/check-alias-integrity.sh`（legacy 文档事实漂移检测）
- `scripts/harness/check-wrapper-integrity.sh`（legacy 根脚本 wrapper 漂移检测）
- `scripts/harness/check-plan-required.sh` 必须读取并应用 `.harness/plan-required-rules.yml`（布尔开关/阈值/labels/allowed_plan_statuses）

## Step 5.5: Configure CI Tracks and Promotion Policy

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

为 CI 明确配置双轨模式：
- bootstrap：观察期，仅收集失败模式
- enforced：强门禁，必须全绿
- bootstrap 需拆分为两个 job：
  - `bootstrap-observe`：非关键检查，允许失败
  - `critical-gates`：仅运行 `scripts/harness/check-critical.sh`，覆盖 placeholder-angle/expired-ADR + 必需 plan/alias/wrapper integrity，禁止失败
  - `security/auth/data-migration`：当改动范围或 PR label 命中对应域时，必须存在并通过对应 gate 脚本
  - `critical-gates` 必须传递 PR 上下文给 plan gate：`GITHUB_EVENT_NAME`、`PR_BODY_FILE`，并在 PR 事件前写入 `.harness/pr-body.txt`
- strict 策略：
  - `bootstrap-observe` 设置 `HARNESS_STRICT_MODE=false`
  - `critical-gates` 不跑 `check-all.sh`
  - `enforced` 设置 `HARNESS_STRICT_MODE=true`

必须写死升级条件（Promotion Criteria）：
- 连续 N 天（建议 7-14）核心流水线稳定
- 失败率低于阈值（建议 < 5%）
- 关键路径用例覆盖率达到阈值（按项目约定）

建议在 `docs/ci-governance.md` 记录：
- 当前轨道状态
- 切换日期
- 负责人
- 回滚策略

并新增门禁优先级配置：
- `.harness/gate-severity.yml`
- `security/auth/data-migration` 类检查在命中对应变更范围/PR labels 时，在 bootstrap 与 enforced 都必须阻断
- 仅允许 ADR 例外：`docs/decisions/ADR-exceptions/*.md`（包含 `owner`、`expires_on`、`scope`；过期自动失效）

## Step 6: Configure Feedback Loops

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

在 `docs/feedback-loops.md` 中写清 Guides → Sensors → Closed Loop 三段式流程。

每次初始化补齐：
- `docs/testing.md` 中的验收命令与测试层次
- `docs/decisions/ADR-0001-harness-init.md` 记录本次初始化决策

闭环强制规则：
- 同类失败第二次出现，必须固化为 `test` / `constraint` / `convention` / `ADR` / `lint rule` / `CI check` / `monitoring check` / `plan checklist` 至少一项。
- `feedback-loops.md` 与 `entropy-gc.md` 必须持续更新，禁止静态不维护。
- 增加 doc-gardening 定时任务（每日或每周），扫描过期文档与规则漂移并自动提交 PR（或生成待审补丁）。
- 建议输出 `docs/harness/doc-gardening-report.md` 作为自动 PR 的变更载体。

ADR 模板：
```md
# ADR-0001: Harness Init

## Context
<描述仓库初始状态和接入 harness 的原因>

## Decision
<记录选择 AGENTS.md/CLAUDE.md、技术栈门禁、结构测试工具的决定>

## Consequences
<说明对开发流程的影响>
```

## Step 7: Configure Entropy Management and GC

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write） + `Shell`

读取 `references/gc-templates.md` 获取熵管理模板。

在 `docs/entropy-gc.md` 定义漂移类型、健康度指标、GC 周期、合规分层、技术债流程。

repo mode 规则：
- single-project / nested-project：维护当前作用域 `docs/entropy-gc.md`。
- multi-project：为每个确认项目根维护 `<project>/docs/entropy-gc.md`；如有跨项目统一熵治理，可额外维护 root 级文档。

可选但强烈建议：
- `docs/health/baseline.md`：当前健康基线快照
- `scripts/harness/doc-gardening.sh`：可执行漂移/过期扫描脚本
- `scripts/harness/check-alias-integrity.sh`：legacy/canonical 双事实源检查
- CI 中的定期 doc-gardening 与 drift-check job

## Step 8: Finish with a Concrete Checklist

**Tools**: `Shell`（执行自验脚本）

验证结果必须使用统一状态：
- `pass`：命令执行且通过
- `fail`：命令执行且失败
- `warn`：非阻断异常或降级提醒
- `not-run`：命令未执行（必须记录原因与残余风险）

### Validation by Repo Mode

#### Single-project

Check:
- `AGENTS.md` or `CLAUDE.md`
- `docs/architecture-boundaries.md`
- `docs/constraints.md`
- `docs/testing.md`
- `docs/ci-governance.md`
- `docs/agent-autonomy.md`
- `docs/observability.md`
- `docs/feedback-loops.md`
- `docs/entropy-gc.md`
- `docs/exec-plans/active/`
- `docs/exec-plans/completed/`
- `docs/exec-plans/tech-debt-tracker.md`

#### Multi-project

Check:
- root `AGENTS.md` or `CLAUDE.md`
- root `docs/architecture-boundaries.md`
- root `docs/ci-governance.md`
- root `docs/agent-autonomy.md`
- root `docs/observability.md`
- root `docs/feedback-loops.md`
- root `docs/entropy-gc.md`
- root `docs/exec-plans/active/`
- root `docs/exec-plans/completed/`
- root `docs/exec-plans/tech-debt-tracker.md`
- root `docs/decisions/`
- each detected project root has:
  - `AGENTS.md` or `CLAUDE.md`
  - `docs/architecture-boundaries.md`
  - `docs/constraints.md`
  - `docs/testing.md`
  - `docs/observability.md`
  - `docs/feedback-loops.md`
  - `docs/entropy-gc.md`
  - `docs/exec-plans/active/`
  - `docs/exec-plans/completed/`
  - `docs/exec-plans/tech-debt-tracker.md`

#### Nested-project

Check current scope only:
- local `AGENTS.md` (or `CLAUDE.md`)
- local `docs/architecture-boundaries.md`
- local `docs/constraints.md`
- local `docs/testing.md`
- local `docs/observability.md`
- local `docs/feedback-loops.md`
- local `docs/entropy-gc.md`
- local/root `docs/agent-autonomy.md`
- local/root `docs/ci-governance.md`
- local/root `docs/exec-plans/active/`
- local/root `docs/exec-plans/completed/`
- local/root `docs/exec-plans/tech-debt-tracker.md`

运行验证脚本，按 repo mode 检查 harness 完整性。

详细验证脚本和检查清单见 `references/validation-scripts.md`。

canonical 入口：
- `scripts/harness/check-all.sh`（聚合全部检查）
- `scripts/harness/check-critical.sh`（bootstrap critical 最小阻断面）

**逐项确认 Checklist**:

- [ ] 已盘点现有 harness 文件并记录冲突
- [ ] 已创建主导航文件 `AGENTS.md` 或 `CLAUDE.md`
- [ ] 已按 repo mode 建立 `docs/` 结构
- [ ] 已配置 lint / format / type-check / test 命令
- [ ] 已配置结构测试或 architecture check
- [ ] 已配置 pre-commit 或等效本地门禁
- [ ] 已配置至少一个 drift / GC 执行入口
- [ ] 已记录 ADR-0001 初始化决策
- [ ] 已建立 `docs/exec-plans/{active,completed,tech-debt-tracker.md}`
- [ ] 已建立 canonical docs
- [ ] legacy docs 已转 alias
- [ ] 已定义跨模块 PR 的 plan 关联门禁
- [ ] 已定义 bootstrap → enforced 升级条件
- [ ] 已配置 `.harness/runtime.yml`、`.harness/scorecard.yml`、`.harness/integrations.yml`
- [ ] 已配置 context snapshot
- [ ] 已配置 subagent routing-rules
- [ ] bootstrap 已拆分 `bootstrap-observe` 与 `critical-gates`
- [ ] 所有未执行验证已记录为 `not-run`
