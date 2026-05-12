# Runtime Surface

<!-- Harness Init Contract Version: v3 -->
<!-- Generated/Updated by: harness-init -->
<!-- Scope: root -->

本文档描述项目的运行面定义，供智能体和开发者了解如何启动、测试和验证项目。

配置源：`.harness/runtime.yml`

---

## Dev Server

| Item | Value |
|---|---|
| 启动命令 | `TODO: 待补充` |
| 访问地址 | `TODO: 待补充` |
| 健康检查 | `TODO: 待补充` |

启动方式：

```bash
# 启动 dev server
TODO: 待补充

# 验证服务健康
TODO: 待补充
```

---

## Check Commands

| Check | Command | Description |
|---|---|---|
| Lint | `TODO: 待补充` | 代码风格和静态分析检查 |
| Test | `TODO: 待补充` | 单元测试和集成测试 |
| Typecheck | `TODO: 待补充` | 类型系统检查 |
| Build | `TODO: 待补充` | 生产构建 |

一键执行所有检查：

```bash
# 依次执行 lint → typecheck → test → build
TODO: 待补充
```

---

## Logs

| Item | Value |
|---|---|
| 本地日志路径 | `TODO: 待补充` |

查看日志：

```bash
# 查看最近日志
tail -f TODO: 待补充
```

---

## UI Verification

| Item | Value |
|---|---|
| Provider | not-configured |
| Base URL | `TODO: 待补充` |

当前 UI 验证状态：**未配置**

配置 UI 验证后可使用以下脚本：
- `scripts/harness/capture-dom.sh` — 捕获 DOM 快照
- `scripts/harness/capture-screenshot.sh` — 捕获页面截图
- `scripts/harness/check-console.sh` — 检查 console 错误
- `scripts/harness/verify-user-journey.sh` — 执行用户旅程验证

---

## Configuration

完整配置位于 `.harness/runtime.yml`，修改后运行以下命令验证：

```bash
scripts/harness/check-runtime-surface.sh
```

---

## Related Docs

- `.harness/runtime.yml` — 运行面配置源文件
- `docs/observability.md` — 可观测性配置
- `docs/harness/context-snapshot.md` — 项目状态快照
