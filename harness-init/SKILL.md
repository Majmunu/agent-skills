---
name: harness-init
version: 4.0.0
description: 初始化项目 harness 基础设施，包括 AGENTS.md 或 CLAUDE.md 导航文件、.harness/docs 目录骨架、架构约束、lint 和测试门禁、反馈循环、熵管理与 GC 模板。支持 Node/TypeScript、Python、Go、Rust、Java、Kotlin 及 Monorepo 项目。Use when the request mentions harness init, setup harness, initialize agent infrastructure, bootstrap AGENTS.md, create docs scaffold, establish agent-ready engineering constraints, or when the user wants to set up Codex / agent tooling for a new or existing project.
---

# Harness Init

为项目建立可持续演化的 agent harness。目标不是堆叠 prompt，而是把上下文、约束、验证和治理写回仓库。

## Core Principles

1. 先盘点现状，再初始化。不覆盖已有 AGENTS.md、AGENTS.md、`.harness/`、业务 `docs/`、hooks 或 CI 配置。
2. 把入口文件写成目录，不写成百科全书。导航文件控制在 100-200 行。
3. 把知识放进仓库，把约束做成可检查规则，把反馈做成固定闭环。
4. 优先建立最小可运行 harness，再补充深度治理。
5. 如果发现多套规则冲突，显式记录冲突并请求用户决定，不要静默合并。
6. 绝不覆盖已有文件。所有修改使用 Read → compare → patch/append 策略：package.json 只 merge 缺失 scripts；Makefile 只 append 缺失 targets；CI/hook 文件保留已有 jobs 并添加标记的 harness section。重复运行不产生重复内容（幂等性）。

## Canonical Path and Compatibility Alias Policy

Canonical path 是唯一事实源。Legacy path 只能作为 alias/wrapper，禁止承载独立治理事实。

Canonical docs:
- `.harness/docs/architecture-boundaries.md`
- `.harness/docs/ci-governance.md`
- `.harness/docs/agent-autonomy.md`
- `.harness/docs/observability.md`
- `.harness/docs/feedback-loops.md`
- `.harness/docs/entropy-gc.md`
- `.harness/docs/exec-plans/active/`
- `.harness/docs/exec-plans/completed/`
- `.harness/docs/exec-plans/tech-debt-tracker.md`

Canonical script root:
- `.harness/scripts/`

Legacy compatibility rules:
- fresh init must not generate legacy markdown aliases by default
- fresh init must not generate legacy root wrappers by default
- repair / migration mode may create temporary alias or wrapper files only when the repository already depends on old paths
- any temporary compatibility file must point to `.harness/*`, carry removal intent, and contain no independent governance logic

## Strong Gate Policy

关键门禁默认强制（可配置但默认 fail-fast）：
- plan-required gate
- architecture boundary gate
- alias integrity gate
- wrapper integrity gate
- placeholder angle-bracket gate

优先级规则：
- `security/auth/data-migration` checks are blocking in both tracks when corresponding scope/PR labels are touched.
- 仅允许 ADR 例外：`.harness/docs/decisions/ADR-exceptions/*.md`（必须包含 `owner`、`expires_on`、`scope`）。

## Navigation Scope Isolation Rule

`harness-init` must avoid polluting the root navigation file (`AGENTS.md` or `AGENTS.md`).

Before creating or modifying any navigation file, detect whether the repository is:

1. single-project repository
2. monorepo / multi-project repository
3. nested project inside a larger repository

Rules:

- Root navigation file only contains global rules and navigation.
- Project-specific commands must live in the nearest project-level navigation file (`AGENTS.md` or `AGENTS.md`).
- Do not mix frontend/backend/package/service commands into one global file.
- Do not duplicate the same generated block multiple times.
- Always prefer scoped project files over root files when a project boundary exists.

## Root Pollution Prevention Contract

In multi-project mode, the root navigation file is an index, not a project guide.

Root navigation file may contain:
- repository layout
- scope resolution rules
- shared security/compliance rules
- repo-wide commands
- project index
- harness-engineering handoff

Root navigation file must not contain:
- commands that require `cd <project>`
- app/service/package-specific environment variables
- local database setup
- local framework assumptions
- project-specific architecture
- project-specific testing strategy
- project-specific deployment instructions

If content applies to only one project, write it to that project's nearest navigation file (`AGENTS.md` or `AGENTS.md`).

## Harness Init Contract Version

- Current contract version: `v2`
- All generated marker blocks must carry version metadata.
- Generated sections should include:
  - `Harness Init Contract Version: v2`
  - `Generated/Updated by: harness-init`

## Unknown Stack Consistency Contract

unknown stack 三件套必须一致：

1. 模板写法：使用纯文本 TODO（例如 `Install: TODO: 待补充`），不要使用 HTML comment。
2. Step 8 检查器：`<...>` 失败，`TODO/FIXME/TBD/待补充` 仅 warning。
3. ADR 例外：若 `.harness/docs/decisions/ADR-0001-harness-init.md` 记录“未知技术栈”，TODO 保持 warning-only。
4. 模板中的 `<...>` 仅作为 generation hint，不允许原样写入目标仓库；若无法确定值，改写为 `TODO: 待补充` 并在 ADR 记录原因。

## Runtime Preflight & Degraded Mode

在任何写操作前，必须做运行时预检查（preflight），并把结果带入 dry-run：

- command runtime 可用性：`git`、`bash/sh`、`pwsh`、`python3/python`、`node`、`rg/find/grep`
- shell 可用性：优先 `bash/sh`，否则降级 `PowerShell`
- CI 上下文可用性：PR body、base/head refs、labels

执行规则：
- preflight 失败不应阻塞初始化文档与骨架落地，但必须进入 degraded mode。
- degraded mode 下所有验证结果必须显式标注：`pass` / `fail` / `warn` / `not-run`。
- `not-run` 必须写明：未执行的命令、原因、残余风险。
- 禁止将 `not-run` 伪装为 `pass`。

## Reference Files

本 skill 的详细模板和技术栈配置拆分在 `references/` 目录，按需加载：

| 文件 | 内容 | 何时加载 |
|------|------|----------|
| `references/stack-detection.md` | 项目类型识别逻辑与工具命令映射 | Step 1 盘点时 |
| `references/nav-templates.md` | AGENTS.md / AGENTS.md 完整模板 | Step 2 创建导航文件时 |
| `references/docs-templates.md` | `.harness/docs/` 各文件内容模板 | Step 3 创建文档时 |
| `references/tooling-templates.md` | 各技术栈 lint/test/type-check 配置模板 | Step 4-5 配置门禁时 |
| `references/structure-tests.md` | 各技术栈结构测试与循环依赖检测模板 | Step 5 添加结构测试时 |
| `references/exec-plan-templates.md` | 执行计划模板与 plan-required 规则 | Step 3/5 |
| `references/ci-governance.md` | 双轨 CI 与升级/降级策略模板 | Step 5.5 |
| `references/quality-gates.md` | 强门禁矩阵与脚本入口规范 | Step 5/8 |
| `references/agent-autonomy.md` | L1-L4 自治策略与升降级模板 | Step 3/5.5 |
| `references/observability-templates.md` | 可观测性最小运行面模板 | Step 4 |
| `references/gc-templates.md` | 熵管理、漂移检测、GC 配置模板 | Step 7 配置熵管理时 |
| `references/runtime-preflight.md` | 运行时预检查、降级模式与跨 shell 兼容策略 | Step 0/1/4/8 |
| `references/report-templates.md` | 初始化报告模板（dry-run + init report） | Step 0 与 Step 9 |
| `references/repair-mode.md` | repair / drift-fix 执行规范 | Repair Mode |
| `references/regression-fixtures.md` | skill 回归夹具矩阵与检查项 | 回归验证阶段 |

---

## Execution Flow

Use the available task tracker if present; otherwise maintain a visible checklist for Steps 0–9.

```
- [ ] Step 0: Dry-run Plan (输出初始化计划)
- [ ] Step 1: Inventory (盘点现状)
- [ ] Step 2: Navigation (创建导航文件)
- [ ] Step 2.5: Dynamic Context (配置动态上下文，可选)
- [ ] Step 3: Docs Scaffold (创建 docs/ 骨架)
- [ ] Step 4: Guides + Sensors + Observability
- [ ] Step 5: Structure Tests
- [ ] Step 6: Feedback Loops
- [ ] Step 7: Entropy & GC
- [ ] Step 8: Validation Checklist
- [ ] Step 9: Init Report (输出初始化变更报告)
```

## Initialization Decision Flow

1. Detect repository root.
2. Detect project boundaries.
3. Count detected project roots.
4. Decide mode.

### Mode A: Single Project

Use a root-level navigation file (`AGENTS.md` or `AGENTS.md`).

### Mode B: Multi Project

Use the root navigation file as index only.
Create a project-level navigation file (`AGENTS.md` or `AGENTS.md`) for each detected project.

### Mode C: Nested Project

If harness-init runs inside a subdirectory that is itself a project:

- Create or update local navigation file (`AGENTS.md` or `AGENTS.md`).
- Do not modify parent root navigation file unless explicitly requested.
- Record parent relationship if detectable.

## Nearest Navigation File Rule

For any file path, the applicable guide is the nearest navigation file (`AGENTS.md` or `AGENTS.md`) in its ancestor chain.

Example:

```txt
repo/
├── AGENTS.md
├── apps/editor/AGENTS.md
└── apps/editor/src/App.tsx
```

For `apps/editor/src/App.tsx`, apply:

1. `apps/editor/AGENTS.md`
2. root `AGENTS.md`

Local rules override root rules.

## Agent Runtime Compatibility

Do not assume a specific agent runtime.

- If task tracking tool exists, use it.
- Otherwise maintain a visible checklist.
- If patch/edit tool exists, patch existing files.
- If only write is available, read file first and rewrite with user content preserved.

## Selective Project Init

支持只初始化指定作用域：

```bash
harness-init scope=apps/editor
```

规则：
- When scope is provided, initialize only that scope.
- Do not modify sibling projects.
- Modify the root navigation file (`AGENTS.md` or `AGENTS.md`) only to add/update project index when safe.
- 推荐将 scope 映射到环境变量：`HARNESS_TARGET_SCOPE=<path>`，供 boundary detection 复用。

## .harnessignore

支持仓库级忽略规则文件 `.harnessignore`，避免误扫样例、依赖和第三方目录。

示例：

```txt
node_modules/
dist/
build/
examples/
fixtures/
vendor/
third_party/
```

---

## Workflow

### Step 0: Dry-run Plan

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

### Step 1: Inventory Existing Harness

**Tools**: `Shell` + `Read`

读取 `references/stack-detection.md`，执行项目类型识别和现状盘点。
若用户提供 `scope=<path>`，先设置 `HARNESS_TARGET_SCOPE=<path>`，仅盘点该作用域并限制后续写入范围。
若 preflight 显示 `bash`/`git` 不可用，按 `references/runtime-preflight.md` 使用 PowerShell 等效命令并标注 degraded mode。

```bash
# 一键盘点脚本（直接执行）
echo "=== Navigation Files ===" && \
  for f in AGENTS.md AGENTS.md; do [ -f "$f" ] && echo "EXISTS: $f" || echo "MISSING: $f"; done

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
- 若已有完整 AGENTS.md/AGENTS.md → 不覆盖，仅按 marker 局部补充缺失区块
- 若存在 `doc/` 且已被广泛引用 → 保留 `doc/`，不强制重命名
- 若检测到 multi-project → 根导航文件仅保留全局索引；项目级命令必须写入最近项目导航文件
- 若检测到 multi-project → 根 `Shared Commands` 禁止出现项目特定命令（如 `build:editor`、`cd apps/...`）
- 若检测到 nested-project → 只更新当前项目作用域，不修改父级根导航文件（除非用户明确要求）
- 若 `.harnessignore` 不存在 → 创建默认忽略规则文件（`node_modules/`、`dist/`、`build/`、`examples/`、`fixtures/`、`vendor/`、`third_party/`）
- 若项目类型无法自动识别（罕见技术栈）→ 使用 generic harness 继续初始化，不阻塞流程；在 Commands 区块标注“待补充”，并在 ADR 记录未知技术栈

### Step 2: Create the Navigation Entry

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

读取 `references/nav-templates.md` 获取完整模板。
若目标文件已存在，除非用户明确批准，否则禁止整文件覆盖（full-file replacement）。
所有新增 marker 必须带 `version=2`，并在生成区块写入 contract 元信息。

选择策略：
- Mode A（single-project）：
  - 根目录创建/更新主导航文件（`AGENTS.md` 或 `AGENTS.md`）
  - 默认同步创建/更新另一个导航文件，并保持语义等价（strict parity）
- Mode B（multi-project）：
  - 根目录创建/更新索引型导航文件（只含全局规则、仓库布局、项目索引、共享约束）
  - 为每个检测到的项目根创建/更新项目级导航文件（`AGENTS.md` 或 `AGENTS.md`）
  - 项目命令、项目约束、项目验证只写在项目级导航文件
  - 若同时生成 `AGENTS.md` 与 `AGENTS.md`，两者必须保持同作用域语义等价，禁止仅保留“跳转指针”导致信息不对称
- Mode C（nested-project）：
  - 仅在当前子项目作用域创建/更新本地导航文件（`AGENTS.md` 或 `AGENTS.md`）
  - 不修改父仓库根导航文件（除非用户明确要求）

导航文件只包含：项目概览、关键目录导航、运行命令、硬约束、深层文档入口。控制在 100-200 行。

### Step 2.5: Configure Dynamic Context (Optional)

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

在导航文件中补充动态上下文入口：

规则：
- single-project：可直接写入根 `AGENTS.md` / `AGENTS.md`。
- multi-project：`Runtime Context` 必须写入项目级导航文件（`AGENTS.md` 或 `AGENTS.md`），除非该状态/命令明确适用于全仓库。
- nested-project：只写当前项目作用域，不写父级根文件。

```md
## Runtime Context

- Health: `<health check command or URL>`
- CI status: `<CI provider link>`
- Logs: `logs/` or `<log command>`
- Outdated deps: `<outdated check command>`  ← 见 references/stack-detection.md 各栈命令
```

### Step 3: Scaffold the Documentation System of Record

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
│       └── .harness/
│           └── docs/
│               ├── testing.md
│               ├── observability.md
│               ├── feedback-loops.md
│               ├── entropy-gc.md
│               └── exec-plans/
│                   ├── active/
│                   ├── completed/
│                   └── tech-debt-tracker.md
├── packages/<name>/
│   ├── AGENTS.md
│   └── .harness/docs/          # 同上结构
└── services/<name>/
    ├── AGENTS.md
    └── .harness/docs/          # 同上结构
```

规则：
- Root docs are for repository-wide facts only.
- Project docs are for project-specific facts only.
- Do not put one app's architecture into root docs unless it affects the whole repository.
- Canonical docs are source of truth; legacy docs are compatibility alias only.
- Plan Scope Policy:
  - single-project / nested-project：计划默认写入 `.harness/docs/exec-plans/*`
  - multi-project：root `.harness/docs/exec-plans/*` 仅用于跨项目/仓库级计划；项目级计划写入 `<project>/.harness/docs/exec-plans/*`
- 中大型任务（跨模块、跨项目、架构重构）必须先建计划文件再开工。
- 涉及跨模块改动的 PR 必须关联 plan 文件（支持 root 与 project scope 路径）。

### Step 4: Install Guides, Sensors and Observability

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write） + `Shell`（验证命令可执行性）

读取 `references/tooling-templates.md` 与 `references/observability-templates.md`，根据 Step 1 识别的技术栈选择对应模板。

**Guides**（前馈控制）:
- `AGENTS.md` / `AGENTS.md`
- `.harness/docs/architecture-boundaries.md`、`.harness/docs/constraints.md`、`.harness/docs/ci-governance.md`

**Sensors**（反馈控制）:
- lint、type-check、tests、structure checks、reviewer

**Observability**（可观测运行环境）:
- 确保 `dev` 命令可用且能快速启动
- 配置日志可访问路径
- 配置基本健康检查命令
- 补齐最小可观测脚本：`.harness/scripts/query-logs.sh`、`.harness/scripts/query-metrics.sh`（至少支持关键 SLO 程序化验证）
- 补齐统一运行面脚本：`.harness/scripts/reproduce.sh`、`.harness/scripts/validate.sh`、`.harness/scripts/regression.sh`、`.harness/scripts/pre-release.sh`
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

### Step 5: Add Structure Tests and Constraint Enforcement

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
- 若改动涉及多个模块/作用域，CI 必须校验 PR 关联 plan 文件（支持 `.harness/docs/exec-plans/*` 与 `<project>/.harness/docs/exec-plans/*`）。
- 无关联 plan 时失败（fail-fast）。
- plan 路径必须指向真实存在的文件。
- PR gate 默认仅接受 `active|completed`（生命周期可保留 `blocked|superseded`，但不授权合并）。
- 若为 `active` 或 `completed`，计划文件前 60 行必须包含 `Status:` 字段。
- multi-project 计划作用域校验：
  - 单项目作用域变更优先要求 `<project>/.harness/docs/exec-plans/*`
  - 跨项目/仓库级变更要求 `.harness/docs/exec-plans/*`
- 该门禁应仅在 PR 事件中执行；`push` 等非 PR 事件应自动跳过。
- 在 GitHub Actions 中，先写入 `github.event.pull_request.body` 到 `.harness/pr-body.txt`，再运行 `.harness/scripts/check-plan-required.sh`。
- plan 路径示例：
  - `.harness/docs/exec-plans/active/<plan>.md`
  - `apps/<name>/.harness/docs/exec-plans/active/<plan>.md`
  - `services/<name>/.harness/docs/exec-plans/active/<plan>.md`

建议同步生成：
- `.harness/plan-required-rules.yml`（可机器判定触发条件）
- `.harness/scripts/check-placeholders.sh`（placeholder 检查，过滤 harness marker 与注释）
- `.harness/scripts/check-alias-integrity.sh`（legacy 文档事实漂移检测）
- `.harness/scripts/check-wrapper-integrity.sh`（legacy 根脚本残留检测）
- `.harness/scripts/check-plan-required.sh` 必须读取并应用 `.harness/plan-required-rules.yml`（布尔开关/阈值/labels/allowed_plan_statuses）

### Step 5.5: Configure CI Tracks and Promotion Policy

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

为 CI 明确配置双轨模式：
- bootstrap：观察期，仅收集失败模式
- enforced：强门禁，必须全绿
- bootstrap 需拆分为两个 job：
  - `bootstrap-observe`：非关键检查，允许失败
  - `critical-gates`：仅运行 `.harness/scripts/check-critical.sh`，覆盖 placeholder-angle/expired-ADR + 必需 plan/alias/wrapper integrity，禁止失败
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

建议在 `.harness/docs/ci-governance.md` 记录：
- 当前轨道状态
- 切换日期
- 负责人
- 回滚策略

并新增门禁优先级配置：
- `.harness/gate-severity.yml`
- `security/auth/data-migration` 类检查在命中对应变更范围/PR labels 时，在 bootstrap 与 enforced 都必须阻断
- 仅允许 ADR 例外：`.harness/docs/decisions/ADR-exceptions/*.md`（包含 `owner`、`expires_on`、`scope`；过期自动失效）

### Step 6: Configure Feedback Loops

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

在 `.harness/docs/feedback-loops.md` 中写清 Guides → Sensors → Closed Loop 三段式流程。

每次初始化补齐：
- `.harness/docs/testing.md` 中的验收命令与测试层次
- `.harness/docs/decisions/ADR-0001-harness-init.md` 记录本次初始化决策

闭环强制规则：
- 同类失败第二次出现，必须固化为 `test` / `constraint` / `convention` / `ADR` / `lint rule` / `CI check` / `monitoring check` / `plan checklist` 至少一项。
- `feedback-loops.md` 与 `entropy-gc.md` 必须持续更新，禁止静态不维护。
- 增加 doc-gardening 定时任务（每日或每周），扫描过期文档与规则漂移并自动提交 PR（或生成待审补丁）。
- 建议输出 `.harness/docs/doc-gardening-report.md` 作为自动 PR 的变更载体。

ADR 模板：
```md
# ADR-0001: Harness Init

## Context
<描述仓库初始状态和接入 harness 的原因>

## Decision
<记录选择 AGENTS.md/AGENTS.md、技术栈门禁、结构测试工具的决定>

## Consequences
<说明对开发流程的影响>
```

### Step 7: Configure Entropy Management and GC

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write） + `Shell`

读取 `references/gc-templates.md` 获取熵管理模板。

在 `.harness/docs/entropy-gc.md` 定义漂移类型、健康度指标、GC 周期、合规分层、技术债流程。

repo mode 规则：
- single-project / nested-project：维护当前作用域 `.harness/docs/entropy-gc.md`。
- multi-project：为每个确认项目根维护 `<project>/.harness/docs/entropy-gc.md`；如有跨项目统一熵治理，可额外维护 root 级文档。

可选但强烈建议：
- `.harness/docs/health/baseline.md`：当前健康基线快照
- `.harness/scripts/doc-gardening.sh`：可执行漂移/过期扫描脚本
- `.harness/scripts/check-alias-integrity.sh`：legacy/canonical 双事实源检查
- CI 中的定期 doc-gardening 与 drift-check job

### Step 8: Finish with a Concrete Checklist

**Tools**: `Shell`（执行自验脚本）

验证结果必须使用统一状态：
- `pass`：命令执行且通过
- `fail`：命令执行且失败
- `warn`：非阻断异常或降级提醒
- `not-run`：命令未执行（必须记录原因与残余风险）

## Validation by Repo Mode

### Single-project

Check:
- `AGENTS.md` or `AGENTS.md`
- `.harness/docs/architecture-boundaries.md`
- `.harness/docs/constraints.md`
- `.harness/docs/testing.md`
- `.harness/docs/ci-governance.md`
- `.harness/docs/agent-autonomy.md`
- `.harness/docs/observability.md`
- `.harness/docs/feedback-loops.md`
- `.harness/docs/entropy-gc.md`
- `.harness/docs/exec-plans/active/`
- `.harness/docs/exec-plans/completed/`
- `.harness/docs/exec-plans/tech-debt-tracker.md`

### Multi-project

Check:
- root `AGENTS.md` or `AGENTS.md`
- root `.harness/docs/architecture-boundaries.md`
- root `.harness/docs/ci-governance.md`
- root `.harness/docs/agent-autonomy.md`
- root `.harness/docs/observability.md`
- root `.harness/docs/feedback-loops.md`
- root `.harness/docs/entropy-gc.md`
- root `.harness/docs/exec-plans/active/`
- root `.harness/docs/exec-plans/completed/`
- root `.harness/docs/exec-plans/tech-debt-tracker.md`
- root `.harness/docs/decisions/`
- each detected project root has:
  - `AGENTS.md` or `AGENTS.md`
  - `.harness/docs/architecture-boundaries.md`
  - `.harness/docs/constraints.md`
  - `.harness/docs/testing.md`
  - `.harness/docs/observability.md`
  - `.harness/docs/feedback-loops.md`
  - `.harness/docs/entropy-gc.md`
  - `.harness/docs/exec-plans/active/`
  - `.harness/docs/exec-plans/completed/`
  - `.harness/docs/exec-plans/tech-debt-tracker.md`

### Nested-project

Check current scope only:
- local `AGENTS.md` (or `AGENTS.md`)
- local `.harness/docs/architecture-boundaries.md`
- local `.harness/docs/constraints.md`
- local `.harness/docs/testing.md`
- local `.harness/docs/observability.md`
- local `.harness/docs/feedback-loops.md`
- local `.harness/docs/entropy-gc.md`
- local/root `.harness/docs/agent-autonomy.md`
- local/root `.harness/docs/ci-governance.md`
- local/root `.harness/docs/exec-plans/active/`
- local/root `.harness/docs/exec-plans/completed/`
- local/root `.harness/docs/exec-plans/tech-debt-tracker.md`

运行以下验证脚本，按 repo mode 检查 harness 完整性：
（边界检测函数需与 `references/stack-detection.md` 保持一致，避免初始化与验证判定漂移）

canonical 入口建议：
- `.harness/scripts/check-all.sh`（聚合全部检查）
- `.harness/scripts/check-critical.sh`（bootstrap critical 最小阻断面）

```bash
#!/usr/bin/env bash
errors=0
warn=0

check_file() {
  if [ ! -f "$1" ]; then
    echo "❌ MISSING file: $1"; errors=$((errors+1))
  elif [ ! -s "$1" ]; then
    echo "⚠️  EMPTY file: $1"; warn=$((warn+1))
  else
    echo "✅ OK: $1"
  fi
}

check_dir() {
  [ -d "$1" ] && echo "✅ OK: $1/" || { echo "❌ MISSING dir: $1/"; errors=$((errors+1)); }
}

check_navigation_file() {
  local base="${1%/}"
  local agents_path
  local claude_path
  if [ "$base" = "." ]; then
    agents_path="AGENTS.md"
    claude_path="AGENTS.md"
  else
    agents_path="$base/AGENTS.md"
    claude_path="$base/AGENTS.md"
  fi

  if [ -f "$agents_path" ] || [ -f "$claude_path" ]; then
    echo "✅ OK: navigation file ($base)"
  else
    echo "❌ MISSING navigation file in $base: AGENTS.md or AGENTS.md"
    errors=$((errors+1))
  fi
}

has_strong_root_signal() {
  local dir="$1"
  [ -f "$dir/package.json" ] || [ -f "$dir/go.mod" ] || [ -f "$dir/pyproject.toml" ] || \
  [ -f "$dir/Cargo.toml" ] || [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] || \
  [ -f "$dir/composer.json" ] || ls "$dir"/*.csproj >/dev/null 2>&1
}

load_harnessignore_patterns() {
  [ -f ".harnessignore" ] || return 0
  grep -Ev '^[[:space:]]*(#|$)' .harnessignore 2>/dev/null || true
}

is_ignored_path() {
  local path="$1"
  local rule

  case "$path" in
    node_modules/*|dist/*|build/*|vendor/*|third_party/*|examples/*|fixtures/*) return 0 ;;
  esac

  while IFS= read -r rule; do
    rule="${rule%/}"
    [ -z "$rule" ] && continue
    case "$path" in
      "$rule"|"$rule"/*) return 0 ;;
    esac
  done < <(load_harnessignore_patterns)

  return 1
}

has_weak_root_signal() {
  local dir="$1"
  [ -f "$dir/Makefile" ] || [ -f "$dir/Dockerfile" ] || [ -f "$dir/docker-compose.yml" ]
}

is_workspace_scope_path() {
  local dir="$1"
  case "$dir" in
    apps/*|packages/*|services/*|frontend|backend|libs/*|modules/*) return 0 ;;
    *) return 1 ;;
  esac
}

workspace_declares_dir() {
  local dir="$1"
  local parent wildcard
  parent="${dir%%/*}"
  wildcard="$parent/*"

  if [ -f "pnpm-workspace.yaml" ] && grep -Eq "^[[:space:]]*-[[:space:]]*[\"']?($dir|$wildcard)[\"']?[[:space:]]*$" pnpm-workspace.yaml; then
    return 0
  fi
  if [ -f "lerna.json" ] && grep -Eq "\"($dir|$wildcard)\"" lerna.json; then
    return 0
  fi
  if [ -f "package.json" ] && grep -Eq "\"($dir|$wildcard)\"" package.json; then
    return 0
  fi
  if [ -f "nx.json" ] && grep -Eq "\"$dir\"" nx.json; then return 0; fi
  if [ -f "workspace.json" ] && grep -Eq "\"$dir\"" workspace.json; then return 0; fi
  if [ -f "turbo.json" ] && grep -Eq "\"$dir\"" turbo.json; then return 0; fi

  return 1
}

has_project_source_dirs() {
  local dir="$1"
  [ -d "$dir/src" ] || [ -d "$dir/cmd" ] || [ -d "$dir/internal" ] || [ -d "$dir/app" ]
}

should_promote_weak_signal_dir() {
  local dir="$1"
  is_workspace_scope_path "$dir" && return 0
  has_project_source_dirs "$dir" && return 0
  [ -n "${HARNESS_TARGET_SCOPE:-}" ] && [ "${HARNESS_TARGET_SCOPE}" = "$dir" ] && return 0
  return 1
}

should_promote_workspace_candidate() {
  local dir="$1"
  has_strong_root_signal "$dir" && return 0
  has_project_source_dirs "$dir" && return 0
  workspace_declares_dir "$dir" && return 0
  [ -n "${HARNESS_TARGET_SCOPE:-}" ] && [ "${HARNESS_TARGET_SCOPE}" = "$dir" ] && return 0
  return 1
}

has_explicit_workspace_config() {
  [ -f "pnpm-workspace.yaml" ] || [ -f "turbo.json" ] || [ -f "nx.json" ] || \
  [ -f "lerna.json" ] || [ -f "rush.json" ] || [ -f "workspace.json" ] || \
  ([ -f "package.json" ] && python3 -c "import json; d=json.load(open('package.json')); exit(0 if 'workspaces' in d else 1)" 2>/dev/null)
}

detect_workspace_dir_candidates() {
  for d in apps/* packages/* services/* frontend backend libs/* modules/*; do
    if [ -d "$d" ] && ! is_ignored_path "$d"; then
      echo "$d"
    fi
  done
}

detect_workspace_dirs() {
  detect_workspace_dir_candidates | while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue
    if should_promote_workspace_candidate "$candidate"; then
      echo "$candidate"
    fi
  done
}

detect_strong_project_roots() {
  local signal_pattern='\( -name package.json -o -name go.mod -o -name pyproject.toml -o -name Cargo.toml -o -name pom.xml -o -name build.gradle -o -name build.gradle.kts -o -name composer.json -o -name "*.csproj" \)'
  if has_strong_root_signal "."; then
    echo "."
  fi
  eval "find . -mindepth 2 -maxdepth 4 $signal_pattern -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/target/*' -not -path '*/dist/*' -not -path '*/build/*'" \
    | xargs -r -I {} dirname {} \
    | sed 's#^\./##' \
    | while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if ! is_ignored_path "$candidate"; then
          echo "$candidate"
        fi
      done
}

detect_weak_project_roots() {
  local weak_pattern='\( -name Makefile -o -name Dockerfile -o -name docker-compose.yml \)'
  if has_weak_root_signal "." && should_promote_weak_signal_dir "."; then
    echo "."
  fi
  eval "find . -mindepth 2 -maxdepth 4 $weak_pattern -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/target/*' -not -path '*/dist/*' -not -path '*/build/*'" \
    | xargs -r -I {} dirname {} \
    | sed 's#^\./##' \
    | while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if ! is_ignored_path "$candidate" && should_promote_weak_signal_dir "$candidate"; then
          echo "$candidate"
        fi
      done
}

detect_project_roots() {
  {
    detect_strong_project_roots
    detect_weak_project_roots
    detect_workspace_dirs
  } | sed '/^$/d' | sort -u | while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if ! is_ignored_path "$candidate"; then
          echo "$candidate"
        fi
      done
}

detect_nested_project() {
  local git_top
  git_top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$git_top" ] && [ "$(pwd -P)" != "$(cd "$git_top" && pwd -P)" ] && has_strong_root_signal "."; then
    echo "nested-project"
    return
  fi
  echo "not-nested"
}

detect_repo_mode() {
  local roots_count
  if [ "$(detect_nested_project)" = "nested-project" ]; then
    echo "nested-project"
    return
  fi
  roots_count=$(detect_project_roots | wc -l | tr -d ' ')
  if [ "$roots_count" -gt 1 ]; then
    echo "multi-project"
    return
  fi
  if has_explicit_workspace_config && [ "$roots_count" -ge 1 ]; then
    echo "multi-project"
    return
  fi
  echo "single-project"
}

mode=$(detect_repo_mode)
echo "Detected repo mode: $mode"

if [ "$mode" = "single-project" ]; then
  echo "── Validation: Single-project ──"
  check_navigation_file "."
  for f in .harness/docs/architecture-boundaries.md .harness/docs/constraints.md .harness/docs/testing.md .harness/docs/ci-governance.md .harness/docs/agent-autonomy.md .harness/docs/observability.md .harness/docs/feedback-loops.md .harness/docs/entropy-gc.md; do
    check_file "$f"
  done
  check_dir ".harness/docs/exec-plans/active"
  check_dir ".harness/docs/exec-plans/completed"
  check_file ".harness/docs/exec-plans/tech-debt-tracker.md"
  check_dir ".harness/docs/decisions"
elif [ "$mode" = "nested-project" ]; then
  echo "── Validation: Nested-project ─"
  check_navigation_file "."
  for f in .harness/docs/architecture-boundaries.md .harness/docs/constraints.md .harness/docs/testing.md .harness/docs/observability.md .harness/docs/feedback-loops.md .harness/docs/entropy-gc.md; do
    check_file "$f"
  done
  [ -f ".harness/docs/agent-autonomy.md" ] && check_file ".harness/docs/agent-autonomy.md" || check_file "../.harness/docs/agent-autonomy.md"
  [ -f ".harness/docs/ci-governance.md" ] && check_file ".harness/docs/ci-governance.md" || check_file "../.harness/docs/ci-governance.md"
  [ -d ".harness/docs/exec-plans/active" ] && check_dir ".harness/docs/exec-plans/active" || check_dir "../.harness/docs/exec-plans/active"
  [ -d ".harness/docs/exec-plans/completed" ] && check_dir ".harness/docs/exec-plans/completed" || check_dir "../.harness/docs/exec-plans/completed"
  [ -f ".harness/docs/exec-plans/tech-debt-tracker.md" ] && check_file ".harness/docs/exec-plans/tech-debt-tracker.md" || check_file "../.harness/docs/exec-plans/tech-debt-tracker.md"
  check_dir ".harness/docs/decisions"
else
  echo "── Validation: Multi-project ───"
  check_navigation_file "."
  check_file ".harness/docs/architecture-boundaries.md"
  check_file ".harness/docs/ci-governance.md"
  check_file ".harness/docs/agent-autonomy.md"
  check_file ".harness/docs/observability.md"
  check_file ".harness/docs/feedback-loops.md"
  check_file ".harness/docs/entropy-gc.md"
  check_dir ".harness/docs/exec-plans/active"
  check_dir ".harness/docs/exec-plans/completed"
  check_file ".harness/docs/exec-plans/tech-debt-tracker.md"
  check_dir ".harness/docs/decisions"

  while IFS= read -r project_root; do
    [ -z "$project_root" ] && continue
    [ "$project_root" = "." ] && continue
    echo "Checking project scope: $project_root"
    check_navigation_file "$project_root"
    check_file "$project_root/.harness/docs/architecture-boundaries.md"
    check_file "$project_root/.harness/docs/constraints.md"
    check_file "$project_root/.harness/docs/testing.md"
    check_file "$project_root/.harness/docs/observability.md"
    check_file "$project_root/.harness/docs/feedback-loops.md"
    check_file "$project_root/.harness/docs/entropy-gc.md"
    check_dir "$project_root/.harness/docs/exec-plans/active"
    check_dir "$project_root/.harness/docs/exec-plans/completed"
    check_file "$project_root/.harness/docs/exec-plans/tech-debt-tracker.md"
  done < <(detect_project_roots)
fi

echo "── Hooks / CI ──────────────────"
([ -f ".pre-commit-config.yaml" ] || [ -d ".husky" ] || [ -f "lefthook.yml" ]) \
  && echo "✅ OK: local hooks" || echo "⚠️  WARNING: no local hooks configured"

echo ""
echo "Result: $errors error(s), $warn warning(s)"
[ $errors -eq 0 ] && echo "🎉 Harness validation PASSED" || { echo "💥 Harness validation FAILED"; exit 1; }
```

占位符残留检查（仅扫描 harness 管理范围，避免全仓镜像文档误报与超时）：
注：unknown stack 场景下，若 `TODO/待补充` 已记录在 `.harness/docs/decisions/ADR-0001-harness-init.md`，该类结果按 warning 处理，不视为初始化失败。

```bash
echo "── Placeholder Check ─────────────"
placeholder_errors=0
scan_warn=0

SCAN_ROOTS=()
[ -f "AGENTS.md" ] && SCAN_ROOTS+=("AGENTS.md")
[ -f "AGENTS.md" ] && SCAN_ROOTS+=("AGENTS.md")
[ -d ".harness/docs" ] && SCAN_ROOTS+=(".harness/docs")
for p in apps/* packages/* services/*; do
  [ -d "$p/.harness/docs" ] && SCAN_ROOTS+=("$p/.harness/docs")
done

if [ "${#SCAN_ROOTS[@]}" -eq 0 ]; then
  echo "WARNING: no harness markdown targets found, skip placeholder scan"
  scan_warn=1
fi

load_harnessignore_patterns() {
  [ -f ".harnessignore" ] || return 0
  grep -Ev '^[[:space:]]*(#|$)' .harnessignore 2>/dev/null || true
}

is_ignored_path() {
  local path="$1"
  local rule

  case "$path" in
    node_modules/*|dist/*|build/*|vendor/*|third_party/*|examples/*|fixtures/*|.git/*|.agents/*|.Codex/*|.qoder/*|.workflow/*|.idea/*|.vscode/*|.turbo/*|.yarn/*) return 0 ;;
  esac

  while IFS= read -r rule; do
    rule="${rule%/}"
    [ -z "$rule" ] && continue
    case "$path" in
      "$rule"|"$rule"/*) return 0 ;;
    esac
  done < <(load_harnessignore_patterns)

  return 1
}

filter_ignored_results() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file_path="${line%%:*}"
    file_path="${file_path#./}"
    if ! is_ignored_path "$file_path"; then
      echo "$line"
    fi
  done
}

ANGLE_PLACEHOLDERS=""
TODO_PLACEHOLDERS=""

if [ "${#SCAN_ROOTS[@]}" -gt 0 ]; then
  ANGLE_PLACEHOLDERS=$(
    find "${SCAN_ROOTS[@]}" -type f -name "*.md" -print0 \
    | xargs -0 -r grep -nE "<[^>]+>" 2>/dev/null \
    | grep -v "harness-init:start" \
    | grep -v "harness-init:end" \
    | grep -v "://" \
    | filter_ignored_results \
    || true
  )

  TODO_PLACEHOLDERS=$(
    find "${SCAN_ROOTS[@]}" -type f -name "*.md" -print0 \
    | xargs -0 -r grep -nE "TODO|FIXME|TBD|待补充" 2>/dev/null \
    | grep -v "harness-init:start" \
    | grep -v "harness-init:end" \
    | filter_ignored_results \
    || true
  )
fi

if [ -n "$ANGLE_PLACEHOLDERS" ]; then
  echo "$ANGLE_PLACEHOLDERS"
  echo "ERROR: unresolved angle-bracket placeholders found"
  placeholder_errors=$((placeholder_errors+1))
else
  echo "OK: no unresolved angle-bracket placeholders"
fi

if [ -n "$TODO_PLACEHOLDERS" ]; then
  echo "$TODO_PLACEHOLDERS"
  if [ -f ".harness/docs/decisions/ADR-0001-harness-init.md" ] && \
     grep -q "未知技术栈" ".harness/docs/decisions/ADR-0001-harness-init.md"; then
    echo "WARNING: TODO placeholders found (unknown-stack ADR recorded)"
  else
    echo "WARNING: TODO placeholders found"
  fi
else
  echo "OK: no TODO placeholders"
fi

[ "$scan_warn" -eq 1 ] && echo "WARNING: placeholder scan executed in degraded target mode"

echo "── Root Scope Pollution Check ───"
if [ -f ".harness/scripts/check-agents-scope.mjs" ]; then
  node .harness/scripts/check-agents-scope.mjs
elif [ -f ".harness/scripts/check-agents-scope.sh" ]; then
  bash .harness/scripts/check-agents-scope.sh
elif [ -f ".harness/scripts/check-agents-scope.ps1" ]; then
  pwsh -File .harness/scripts/check-agents-scope.ps1
else
  echo "SKIP: .harness/scripts/check-agents-scope.sh/.ps1/.mjs not found"
fi

echo "── Harness Command Surface Check ─"
for cmd in scope-check docs-check arch-check validate:harness; do
  if grep -q "\"$cmd\"" package.json 2>/dev/null; then
    echo "✅ OK: package.json script '$cmd'"
  else
    echo "⚠️  WARNING: missing package.json script '$cmd'"
  fi
done

echo "── Automation Surface Check ──────"
if [ -f ".harness/scripts/check-plan-required.sh" ] || [ -f ".harness/scripts/check-plan-required.ps1" ] || [ -f ".harness/scripts/check-plan-required.mjs" ] || [ -f ".harness/scripts/check-plan-required.py" ]; then
  echo "✅ OK: cross-module plan gate script"
else
  echo "❌ MISSING: .harness/scripts/check-plan-required.*"
  errors=$((errors+1))
fi
if [ -f ".harness/scripts/doc-gardening.sh" ] || [ -f ".harness/scripts/doc-gardening.ps1" ] || [ -f ".harness/scripts/doc-gardening.mjs" ] || [ -f ".harness/scripts/doc-gardening.py" ]; then
  echo "✅ OK: doc-gardening automation script"
else
  echo "❌ MISSING: .harness/scripts/doc-gardening.*"
  errors=$((errors+1))
fi
if [ -f ".harness/scripts/check-alias-integrity.sh" ] || [ -f ".harness/scripts/check-alias-integrity.ps1" ] || [ -f ".harness/scripts/check-alias-integrity.mjs" ] || [ -f ".harness/scripts/check-alias-integrity.py" ]; then
  echo "✅ OK: alias integrity script"
else
  echo "❌ MISSING: .harness/scripts/check-alias-integrity.*"
  errors=$((errors+1))
fi
if [ -f ".harness/scripts/check-critical.sh" ] || [ -f ".harness/scripts/check-critical.ps1" ] || [ -f ".harness/scripts/check-critical.mjs" ] || [ -f ".harness/scripts/check-critical.py" ]; then
  echo "✅ OK: critical gates script"
else
  echo "❌ MISSING: .harness/scripts/check-critical.*"
  errors=$((errors+1))
fi

echo "── Canonical Script Surface Check ─"
for f in .harness/scripts/check-all .harness/scripts/check-critical .harness/scripts/check-placeholders .harness/scripts/check-boundaries .harness/scripts/check-file-size .harness/scripts/check-naming .harness/scripts/check-logging .harness/scripts/check-alias-integrity .harness/scripts/check-wrapper-integrity .harness/scripts/reproduce .harness/scripts/validate .harness/scripts/regression .harness/scripts/pre-release .harness/scripts/query-logs .harness/scripts/query-metrics; do
  if [ -f "$f.sh" ] || [ -f "$f.ps1" ]; then
    echo "✅ OK: $f.(sh|ps1)"
  else
    echo "❌ MISSING: $f.(sh|ps1)"
    errors=$((errors+1))
  fi
done

echo "── Legacy Wrapper Absence Check ───"
for base in scripts/check-all scripts/validate scripts/regression; do
  sh_wrapper="${base}.sh"
  ps_wrapper="${base}.ps1"
  if [ -f "$sh_wrapper" ] || [ -f "$ps_wrapper" ]; then
    echo "❌ FAIL: legacy wrapper must not exist: ${base}.(sh|ps1)"
    errors=$((errors+1))
  fi
done

if [ "$placeholder_errors" -gt 0 ]; then
  echo "💥 Placeholder validation FAILED"
  exit 1
fi
```

**逐项确认 Checklist**:

- [ ] 已盘点现有 harness 文件并记录冲突
- [ ] 已创建主导航文件 `AGENTS.md` 或 `AGENTS.md`
- [ ] 已按 repo mode 建立 `.harness/docs/` 结构（single 或 multi-project 分层）
- [ ] 已配置 lint / format 命令
- [ ] 已配置 type-check 或等效静态检查
- [ ] 已配置 test 命令
- [ ] 已配置结构测试或 architecture check
- [ ] 已配置 pre-commit 或等效本地门禁
- [ ] 已配置至少一个 drift / GC 执行入口
- [ ] 已输出健康基线或待办清单
- [ ] 已记录 ADR-0001 初始化决策
- [ ] 已建立 `.harness/docs/exec-plans/{active,completed,tech-debt-tracker.md}`
- [ ] multi-project 已建立 project-level `.harness/docs/exec-plans/*`（每个项目作用域）
- [ ] 已建立 canonical docs（`architecture-boundaries/ci-governance/agent-autonomy/observability`）
- [ ] legacy docs 已转 alias（无并行事实源）
- [ ] 已定义跨模块 PR 的 plan 关联门禁
- [ ] 已定义 bootstrap → enforced 升级条件（N 天稳定、失败率阈值、关键路径覆盖率）
- [ ] 已配置 `.harness/plan-required-rules.yml` 与 `.harness/gate-severity.yml`
- [ ] 已定义自治等级（L1-L4）与回滚/审计策略
- [ ] 已定义 ADR 例外到期回收策略
- [ ] 已配置 doc-gardening 定时任务或等效自动化入口
- [ ] bootstrap 已拆分 `bootstrap-observe` 与 `critical-gates`，并确保关键门禁不可放水
- [ ] `critical-gates` 仅运行 `.harness/scripts/check-critical.sh`（不直接运行 `check-all.sh`）
- [ ] `critical-gates` 已注入 PR 上下文（`GITHUB_EVENT_NAME`、`PR_BODY_FILE`、`.harness/pr-body.txt`）
- [ ] 已输出 runtime capability matrix（git/bash/pwsh/node/python/rg）
- [ ] 所有未执行验证已记录为 `not-run`（包含 command/reason/risk）

## Acceptance Criteria

After initialization:

- [ ] Correctly detects single-project, multi-project, and nested-project repos.
- [ ] Treats workspace directories as candidates before confirming project roots.
- [ ] Root navigation file (`AGENTS.md` or `AGENTS.md`) remains global-only in multi-project repos.
- [ ] Every confirmed project root has nearest navigation file (`AGENTS.md` or `AGENTS.md`).
- [ ] Project-specific commands never enter root navigation file.
- [ ] Root docs and project docs are separated.
- [ ] `harness-engineering` handoff exists at root and project level.
- [ ] Execution plans are first-class artifacts (`.harness/docs/exec-plans/*` and `<project>/.harness/docs/exec-plans/*`) and referenced by cross-module changes.
- [ ] In multi-project mode, root execution plans are repo/cross-project only; project plans live in `<project>/.harness/docs/exec-plans/*`.
- [ ] Architecture and custom lint rules are executable and CI-enforced (pass/fail).
- [ ] Dual-track CI (bootstrap + enforced) exists with explicit promotion criteria.
- [ ] Bootstrap track is split into `bootstrap-observe` (non-critical) and `critical-gates` (always blocking).
- [ ] `critical-gates` runs `.harness/scripts/check-critical.sh` instead of full `check-all.sh`.
- [ ] `critical-gates` passes PR event/body context (`GITHUB_EVENT_NAME`, `PR_BODY_FILE`) so plan gate cannot be skipped.
- [ ] `security/auth/data-migration` checks are blocking in both tracks when scope/labels match, unless valid ADR exception exists.
- [ ] Feedback-to-hardening loop is codified with doc-gardening cadence.
- [ ] Cross-module PR gate fails on missing/non-existent/invalid-status plan links.
- [ ] Agent runtime surface is script-based for repro/validate/regression/pre-release and observability checks.
- [ ] Project-level navigation files run harness scripts from repo root with `HARNESS_TARGET_SCOPE=<project-path>`.
- [ ] Autonomy levels (L1-L4) include promotion requirements, rollback and audit policy.
- [ ] Legacy docs are compatibility aliases only (no duplicated governance facts).
- [ ] Fresh init leaves no legacy root wrappers outside `.harness/scripts/`.
- [ ] Generated sections are marker-based and idempotent.
- [ ] Running harness-init twice produces no duplicate blocks.
- [ ] `<...>` placeholders fail validation.
- [ ] TODO placeholders warn unless allowed by unknown-stack ADR.
- [ ] Preflight matrix is recorded in dry-run and init report.
- [ ] `not-run` validations are explicit and never counted as pass.
- [ ] Dry-run plan shows all intended changes.
- [ ] Init report records mode, detected roots, created files, updated files, and warnings.
- [ ] Repair mode can detect and suggest fixes for polluted root navigation files (`AGENTS.md` or `AGENTS.md`).
- [ ] Contract version is recorded in generated sections.

## Autonomy Rollout Policy

建议在初始化阶段就声明自治等级与放权边界：
- L1：agent 只改代码（人审 + 人合）
- L2：agent 改代码 + 自检 + 回评审意见
- L3：agent 端到端提 PR 并修复 CI
- L4：低风险变更自动合并（硬约束兜底）

每个等级必须附带：
- 回滚策略（触发条件、执行路径、责任人）
- 审计策略（日志、变更记录、审批轨迹）

升级必须满足最小门槛：
- `previous_level_stable_days >= 14`
- `rollback_strategy_exists == true`
- `audit_trail_complete == true`
- `enforced_ci_green_rate >= 95%`
- `critical_incidents == 0`
- `owner_approval == true`

### Step 9: Init Report

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

读取 `references/report-templates.md`，初始化完成后输出变更报告：

- `single-project` / `nested-project`：`.harness/docs/init-report.md`
- `multi-project`：`.harness/docs/init-report.md`

报告必须包含：
- Mode
- Detected Projects（Path/Type/Reason）
- Created Files
- Updated Files
- Skipped Files
- Runtime Capability Matrix（git/bash/pwsh/node/python/rg 等）
- Compatibility Mapping Applied
- Strong Gate Results
- Validation Not Run（command / reason / residual risk）
- Warnings
- Next Step（Use `harness-engineering` for implementation work）

## Repair Mode

Use repair mode when the repository already has harness files.

Repair mode should:
- detect duplicated harness-init blocks
- detect project-specific content in root navigation file
- move local content to nearest project AGENTS.md/AGENTS.md
- restore missing handoff sections
- update old marker versions
- regenerate missing canonical docs
- convert legacy docs to compatibility alias
- migrate legacy root scripts to `.harness/scripts/*` or remove them entirely when no compatibility contract is required
- detect duplicate fact sources and wrapper drift
- preserve user-authored content

执行时读取 `references/repair-mode.md`，并在输出中附带污染项迁移建议：

- Found possible pollution in root navigation file: `<pattern>`
- Suggested target: `<nearest-project>/AGENTS.md` or `<nearest-project>/AGENTS.md`

---

## Handoff to harness-engineering

初始化完成后，仓库必须包含足够上下文供 `harness-engineering` 直接使用，无需重新发现。

**Handoff contract**:

### Single-project

- `AGENTS.md` or `AGENTS.md`
- `.harness/docs/architecture-boundaries.md`
- `.harness/docs/constraints.md`
- `.harness/docs/testing.md`
- `.harness/docs/ci-governance.md`
- `.harness/docs/agent-autonomy.md`
- `.harness/docs/observability.md`
- `.harness/docs/feedback-loops.md`
- `.harness/docs/entropy-gc.md`
- `.harness/docs/exec-plans/`

### Multi-project

Root-level facts:
- root `AGENTS.md` or `AGENTS.md`
- `.harness/docs/architecture-boundaries.md`
- `.harness/docs/ci-governance.md`
- `.harness/docs/agent-autonomy.md`
- `.harness/docs/observability.md`
- `.harness/docs/feedback-loops.md`
- `.harness/docs/entropy-gc.md`
- `.harness/docs/exec-plans/`
- `.harness/docs/decisions/`

Project-level facts:
- `<project>/AGENTS.md` or `<project>/AGENTS.md`
- `<project>/.harness/docs/architecture-boundaries.md`
- `<project>/.harness/docs/constraints.md`
- `<project>/.harness/docs/testing.md`
- `<project>/.harness/docs/observability.md`
- `<project>/.harness/docs/feedback-loops.md`
- `<project>/.harness/docs/entropy-gc.md`
- `<project>/.harness/docs/exec-plans/`

**职责边界**:
- `harness-init`: 建立项目首次的导航、文档骨架、门禁配置。只做一次。
- `harness-engineering`: 后续所有实现、重构、调试、review、feature delivery，以上述文件为项目事实源。

当 agent 从初始化模式切换到工程模式时:
1. 先读取根导航文件（`AGENTS.md`/`AGENTS.md`），再定位最近项目级导航文件
2. 使用 `harness-engineering` skill 执行具体工程任务（优先遵循最近作用域规则）
3. 每次变更后，如果失败模式重复，回写到 harness docs（遵循 feedback-loops.md）

---

## Execution Notes

- 优先小步落地：先创建文档和门禁骨架，再逐步补强自动化。
- 如果仓库当前没有测试框架，不要伪造通过；明确记录"测试 harness 待建立"。
- 如果同时维护 AGENTS.md 与 AGENTS.md，默认保持语义等价（strict parity）；仅在用户明确要求时使用指针模式。
- 如果用户只要求"设计 harness" → 停止在模板和计划；如果要求"初始化 harness" → 直接创建文件。
- 对于 **Go、Rust、Java、Kotlin** 等非 Node/Python 栈，加载 `references/tooling-templates.md` 中对应章节；如果是极罕见技术栈（如 Zig、Nim），仅创建文档骨架和导航文件，在 Commands 区块标注"待补充"。
- Monorepo 项目：根导航文件只做全局索引；每个项目根必须有项目级导航文件（`AGENTS.md` 或 `AGENTS.md`）承载本地命令、约束和验证。
- `.harness/docs` 分层：根 `.harness/docs` 仅仓库级事实；项目 `.harness/docs` 仅项目级事实，避免相互污染。
- 幂等性：重复运行 harness-init 不产生重复内容。使用带版本 marker 的区块（如 `<!-- harness-init:start root-nav version=2 -->` / `<!-- harness-init:end root-nav version=2 -->`、`<!-- harness-init:start project-nav <path> version=2 -->` / `<!-- harness-init:end project-nav <path> version=2 -->`）做局部替换。
- 工具抽象：以下提到的任务跟踪、`Read`、`Write`、`Bash`、`Edit` 等为抽象操作描述，对应当前 agent 运行时中可用的等效工具。如果当前环境没有同名工具，使用功能等效的替代。
- Shell 兼容：若目标仓库主要运行在 Windows 且 `bash` 不可用，允许生成 `.ps1` 等效脚本或同名 wrapper，并在导航/报告中同时记录 POSIX 与 PowerShell 调用方式。
