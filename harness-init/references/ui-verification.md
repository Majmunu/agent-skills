# UI Verification Reference

本文档定义 UI verification 的完整规范。

## 概述

UI verification 允许智能体验证目标项目的 UI 正确性，包括 DOM 状态、截图、console 错误和关键用户路径。

## 支持的 Provider

| Provider | 配置值 | 能力 |
|----------|--------|------|
| Playwright | `playwright` | DOM snapshot, screenshot, console, network |
| Chrome DevTools MCP | `chrome-devtools-mcp` | DOM snapshot, console (通过 MCP 调用) |
| 未配置 | `not-configured` | 输出 not-run |

## 配置

在 `.harness/runtime.yml` 中配置：

```yaml
runtime:
  ui:
    provider: "not-configured"  # playwright | chrome-devtools-mcp | not-configured
    base_url: "TODO: 待补充"
```

## 脚本清单

| 脚本 | 用途 | 输出路径 |
|------|------|---------|
| `capture-dom.sh` | 捕获 DOM snapshot | `.harness/artifacts/dom/<timestamp>.html` |
| `capture-screenshot.sh` | 捕获页面截图 | `.harness/artifacts/screenshots/<timestamp>.png` |
| `check-console.sh` | 检查 console error | stdout |
| `verify-user-journey.sh` | 执行关键用户路径 | `.harness/artifacts/journeys/<name>/` |

## DOM Snapshot

```bash
bash scripts/harness/capture-dom.sh [--url <url>]
```

- provider 为 `playwright` 时：使用 Playwright 捕获完整 DOM
- provider 为 `chrome-devtools-mcp` 时：输出 MCP 调用说明
- 未配置时：输出 `not-run: UI verification backend is not configured.`

## Screenshot

```bash
bash scripts/harness/capture-screenshot.sh [--url <url>] [--viewport <width>x<height>]
```

输出路径：`.harness/artifacts/screenshots/<timestamp>.png`

## Console Error Check

```bash
bash scripts/harness/check-console.sh [--allowlist <path>]
```

- 检查 console error
- 可忽略 allowlist 中的已知噪音
- 默认 console error 应该 fail，除非 ADR exception

Allowlist 格式（`.harness/console-allowlist.txt`）：
```
# 已知噪音，不视为错误
DevTools failed to load source map
[HMR] Waiting for update signal
```

## User Journey

```bash
bash scripts/harness/verify-user-journey.sh <journey-name>
```

Journey 定义文件：`.harness/user-journeys/<journey-name>.yml`

```yaml
name: editor-basic-flow
steps:
  - action: navigate
    url: /editor
  - action: wait
    selector: ".canvas-container"
  - action: click
    selector: ".component-panel .add-button"
  - action: assert
    selector: ".canvas-container .component"
    exists: true
```

## 降级模式

未配置时必须输出：
```
not-run: UI verification backend is not configured.
Reason: .harness/runtime.yml ui.provider is 'not-configured'
Fix: Set ui.provider to 'playwright' or 'chrome-devtools-mcp' and configure base_url
Docs: references/ui-verification.md
```

## 建议内置 Journey 模板

针对零代码小程序平台：
- `editor-basic-flow.yml` — 编辑器基本操作
- `component-register-flow.yml` — 组件注册流程
- `schema-save-flow.yml` — Schema 保存流程
- `runtime-preview-flow.yml` — 运行时预览流程

这些模板可以是占位配置，但不能伪装执行成功。
