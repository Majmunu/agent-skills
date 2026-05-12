# Context Snapshot Reference

加载时机：**Step 2.5 Context Snapshot Initialization**。

本文档说明 `docs/harness/context-snapshot.md` 的用途、生成逻辑、数据源和维护策略。

---

## Overview

Context Snapshot 是一个**索引文档**，为新会话中的智能体提供项目当前状态的快速概览。它聚合来自多个源文档的状态信息，但不替代这些源文档中的详细内容。

**核心原则：**
- 索引优先：snapshot 仅包含摘要和指向源文档的链接
- 不重复：详细信息保留在源文档中，snapshot 只引用
- 自动生成：通过 `scripts/harness/update-context-snapshot.sh` 生成
- 时效性：包含 `Last Updated` 时间戳，便于判断信息新鲜度

---

## Generated File

路径：`docs/harness/context-snapshot.md`

该文件由 `scripts/harness/update-context-snapshot.sh` 生成，包含以下章节：

| Section | Description | Source |
|---|---|---|
| Project Status Summary | CI Mode, Autonomy Level, Quality Score | `.harness/gates.yml`, `.harness/autonomy.yml`, scorecard |
| Active Plans | 当前进行中的执行计划列表 | `docs/exec-plans/active/` |
| Recently Completed Plans | 最近完成的执行计划（最多 5 个） | `docs/exec-plans/completed/` |
| Open Tech Debts | 未解决的技术债务条目 | `docs/exec-plans/tech-debt-tracker.md` |
| Failing Gates | 当前失败或 not-run 的门禁 | `scripts/harness/check-all.sh` output |
| Active ADR Exceptions | 有效的架构决策例外 | `docs/decisions/ADR-exceptions/` |
| Recent Incidents | 最近的事故记录 | `docs/incidents/` |
| Integration Status | 外部集成配置状态 | `.harness/integrations.yml` |
| Next Recommended Actions | 基于当前状态的建议操作 | Computed from gaps |

---

## Script Interface

### `scripts/harness/update-context-snapshot.sh`

| Parameter | Description | Required |
|---|---|---|
| `--dry-run` | 输出 snapshot 到 stdout，不写入文件 | No |
| `--help`, `-h` | 显示帮助信息 | No |

**Exit codes:**
- `0` — Snapshot 生成成功
- `1` — 生成失败
- `2` — Not-run（关键源文件缺失）

**Output (success):**
```
pass: Context snapshot updated at docs/harness/context-snapshot.md
Last Updated: 2024-01-15T10:30:00Z
```

**Output (dry-run):**
```
# Context Snapshot
...
<full snapshot content>
...
pass: Context snapshot generated (dry-run, not written to file)
```

---

## Data Sources

### 1. CI Mode

检测顺序：
1. 环境变量 `HARNESS_CI_MODE`（优先）
2. `.harness/gates.yml` 中的 `mode` 字段
3. 默认值：`bootstrap`

### 2. Autonomy Level

检测顺序：
1. `.harness/autonomy.yml` 中的 `level` 字段
2. 默认值：`L1`

### 3. Quality Score

检测方式：
1. 执行 `scripts/harness/score-quality.sh`
2. 解析输出中的 `Total:` 行
3. 若脚本不可用或执行失败，显示 `N/A`

### 4. Active Plans

扫描 `docs/exec-plans/active/` 目录中的 `.md` 文件，提取：
- 文件名（作为计划名称）
- `Status:` 字段值
- 相对路径

### 5. Recently Completed Plans

扫描 `docs/exec-plans/completed/` 目录，按修改时间倒序排列，取最近 5 个。

### 6. Open Tech Debts

解析 `docs/exec-plans/tech-debt-tracker.md` 中未完成的 checkbox 条目（`- [ ]` 格式），最多显示 10 条。

### 7. Failing Gates

执行 `scripts/harness/check-all.sh` 并提取：
- `FAIL:` 开头的行（失败门禁）
- `not-run:` 开头的行（未执行门禁）

### 8. Active ADR Exceptions

扫描 `docs/decisions/ADR-exceptions/` 目录中的 `.md` 文件，提取：
- 文件名
- 过期时间（如有 `Expires`/`Expiry`/`Valid Until` 字段）

### 9. Recent Incidents

扫描 `docs/incidents/` 目录，按修改时间倒序排列，取最近 5 个。

### 10. Integration Status

读取 `.harness/integrations.yml`，提取：
- `code_host.provider`
- `issue_tracker.provider`
- `mcp.enabled`

### 11. Next Recommended Actions

基于以下条件生成建议：
- 缺失的关键目录/文件
- 质量分数与阈值的差距
- 未配置的集成

---

## Index-Only Contract

Context Snapshot 严格遵循索引文档原则：

1. **不包含详细内容** — 仅包含名称、状态和路径引用
2. **不替代源文档** — 每个 section 都标注了数据来源
3. **可重新生成** — 任何时候运行脚本都能从源文档重建 snapshot
4. **时效标记** — `Last Updated` 时间戳表明信息的新鲜度

如果 snapshot 与源文档不一致，以源文档为准。

---

## Integration with Quality Score

`score-quality.sh` 的 `context_readability` 维度中，`context_snapshot_exists` 检查项（权重 5）验证：

1. `docs/harness/context-snapshot.md` 文件存在
2. 文件包含 `Last Updated` 时间戳
3. 时间戳在合理范围内（建议不超过 7 天）

未生成 snapshot 将导致该检查项扣分。

---

## When to Update

建议在以下时机运行 `update-context-snapshot.sh`：

- 新会话开始前（确保 agent 获取最新状态）
- 执行计划状态变更后
- 门禁修复后
- 集成配置变更后
- CI pipeline 中作为信息性步骤

---

## Marker Block

生成的 snapshot 包含标准 v3 marker：

```html
<!-- Harness Init Contract Version: v3 -->
<!-- Generated/Updated by: harness-init -->
<!-- Scope: root -->
```

这确保 harness-init 的幂等性检测能识别该文件为自动生成内容。

---

## Related Files

- `scripts/harness/update-context-snapshot.sh` — 生成脚本
- `docs/harness/context-snapshot.md` — 生成的 snapshot 文件
- `.harness/scorecard.yml` — 质量评分配置
- `.harness/autonomy.yml` — 自治等级配置
- `.harness/gates.yml` — 门禁模式配置
- `.harness/integrations.yml` — 集成配置
- `references/scorecard-templates.md` — 评分系统参考
- `references/agent-autonomy.md` — 自治等级参考
