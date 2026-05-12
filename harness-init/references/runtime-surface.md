# Runtime Surface

加载时机：**Step 4 Runtime Surface + Observability + UI Verification**。

---

## Purpose

定义目标项目的 agent-readable 运行面，使智能体能够：
- 自动启动开发服务器并验证健康状态
- 执行 lint、test、typecheck、build 等标准检查
- 定位本地日志进行问题诊断
- 判断 UI 验证能力是否可用

---

## Configuration File

canonical 配置：`.harness/runtime.yml`

---

## Schema Definition

```yaml
version: 1
runtime:
  dev:
    command: string       # dev server 启动命令
    url: string           # dev server 访问 URL
    health_check: string  # 健康检查命令（返回 0 表示健康）
  checks:
    lint: string          # lint 命令
    test: string          # 测试命令
    typecheck: string     # 类型检查命令
    build: string         # 构建命令
  logs:
    local_path: string    # 本地日志目录路径
  ui:
    provider: string      # UI 验证 provider: playwright | chrome-devtools-mcp | not-configured
    base_url: string      # UI 基础访问 URL
```

---

## Field Rules

| Field | Required | Default | Notes |
|---|---|---|---|
| `runtime.dev.command` | yes | `TODO: 待补充` | 必须可在项目根目录执行 |
| `runtime.dev.url` | yes | `TODO: 待补充` | 含协议和端口 |
| `runtime.dev.health_check` | yes | `TODO: 待补充` | 返回 exit 0 表示服务就绪 |
| `runtime.checks.lint` | yes | `TODO: 待补充` | 返回 exit 0 表示通过 |
| `runtime.checks.test` | yes | `TODO: 待补充` | 返回 exit 0 表示通过 |
| `runtime.checks.typecheck` | yes | `TODO: 待补充` | 返回 exit 0 表示通过 |
| `runtime.checks.build` | yes | `TODO: 待补充` | 返回 exit 0 表示通过 |
| `runtime.logs.local_path` | yes | `TODO: 待补充` | 相对于项目根目录 |
| `runtime.ui.provider` | yes | `not-configured` | 未配置时 UI 验证脚本输出 not-run |
| `runtime.ui.base_url` | no | `TODO: 待补充` | 仅当 provider 非 not-configured 时需要 |

---

## Placeholder Convention

- 无法确定的值使用 `TODO: 待补充`
- 禁止使用 `<...>` 格式占位符（会触发 placeholder gate 失败）
- `not-configured` 是 `ui.provider` 的合法默认值，不视为占位符

---

## UI Provider Behavior

| Provider | Behavior |
|---|---|
| `not-configured` | 所有 UI 验证脚本输出 `not-run: UI verification backend is not configured.` |
| `playwright` | 使用 Playwright 执行 DOM capture、screenshot、console check、user journey |
| `chrome-devtools-mcp` | 通过 Chrome DevTools MCP server 执行 UI 验证 |

---

## Integration with Other Components

### Gate Scripts

`scripts/harness/check-runtime-surface.sh` 验证 runtime.yml 的完整性：
- 检查文件是否存在
- 检查必填字段是否仍为 `TODO: 待补充`
- 在 enforced mode 下，未配置的必填字段导致 warn
- 在 bootstrap mode 下，允许 `TODO: 待补充` 但输出 warn

### Scorecard

`context_readability` 维度中 `runtime-surface documented` 检查项（4 分）：
- runtime.yml 存在且 version 字段正确：1 分
- dev.command 已配置（非 TODO）：1 分
- checks 至少有一项已配置：1 分
- docs/runtime-surface.md 存在：1 分

### UI Verification Scripts

以下脚本读取 `runtime.yml` 中的 `ui.provider` 决定行为：
- `scripts/harness/capture-dom.sh`
- `scripts/harness/capture-screenshot.sh`
- `scripts/harness/check-console.sh`
- `scripts/harness/verify-user-journey.sh`

### Context Snapshot

`update-context-snapshot.sh` 从 runtime.yml 读取当前配置状态，写入 context-snapshot.md 的 Integration Status 部分。

---

## Stack Detection Hints

harness-init 在 Step 1 (Inventory) 阶段检测项目技术栈后，可自动填充部分 runtime.yml 值：

| Stack | dev.command | checks.lint | checks.test | checks.typecheck | checks.build |
|---|---|---|---|---|---|
| Node.js (npm) | `npm run dev` | `npm run lint` | `npm test` | `npx tsc --noEmit` | `npm run build` |
| Node.js (pnpm) | `pnpm dev` | `pnpm lint` | `pnpm test` | `pnpm tsc --noEmit` | `pnpm build` |
| Python | `python manage.py runserver` | `ruff check .` | `pytest` | `mypy .` | `python -m build` |
| Rust | `cargo run` | `cargo clippy` | `cargo test` | N/A | `cargo build` |
| Go | `go run .` | `golangci-lint run` | `go test ./...` | N/A | `go build ./...` |

注意：自动检测值仍需用户确认，harness-init 在 dry-run 中展示检测结果供审核。

---

## Example: Configured runtime.yml

```yaml
version: 1
runtime:
  dev:
    command: "pnpm dev"
    url: "http://localhost:5173"
    health_check: "curl -sf http://localhost:5173"
  checks:
    lint: "pnpm lint"
    test: "pnpm test"
    typecheck: "pnpm tsc --noEmit"
    build: "pnpm build"
  logs:
    local_path: "logs/"
  ui:
    provider: "playwright"
    base_url: "http://localhost:5173"
```

---

## Related References

- `references/runtime-preflight.md` — 运行时能力检测与降级模式
- `references/observability-templates.md` — 可观测性配置模板
- `references/quality-gates.md` — 门禁检查规则
