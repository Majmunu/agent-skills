# Repair Mode Guide

加载时机：检测到仓库已有 harness 文件，且用户要求“修复/收敛/去漂移”时。

---

## Repair Mode Goals

Repair mode should:
- detect duplicated harness-init blocks
- detect project-specific content in root navigation file (`AGENTS.md` or `CLAUDE.md`)
- move local content to nearest project navigation file
- restore missing handoff sections
- update old marker versions
- regenerate missing canonical docs
- convert legacy governance docs into compatibility alias files
- migrate legacy root scripts into `.harness/scripts/*` or remove them when compatibility is no longer needed
- preserve user-authored content

---

## Repo Classification

进入修复前先判定仓库类型：

- `canonical-only`: canonical docs/scripts 已完整，主要做 drift 修复
- `legacy-only`: 仅旧命名存在，需要补 canonical 并生成 alias/wrapper
- `mixed`: canonical 与 legacy 同时存在，需要清理双事实源

---

## Repair Workflow

1. 盘点并定位问题：
- duplicate markers
- missing markers
- marker version drift
- root pollution
- docs missing by repo mode
- duplicate fact source (`legacy` + `canonical` 都有治理正文)
- wrapper drift（legacy 脚本不是纯 `exec` wrapper）

2. 产出修复计划（先 dry-run）：
- polluted line
- suggested target
- canonical target
- alias/wrapper patch strategy

3. 执行修复（仅 marker 区块 + alias/wrapper）：
- replace duplicated generated blocks
- patch missing handoff section
- upgrade marker version
- create canonical docs if missing
- rewrite legacy docs to alias template
- rewrite legacy scripts to wrappers
- if legacy script is referenced by docs/CI, wrapper must be created even when file is missing

4. 回归验证：
- root pollution check
- placeholder severity check
- repo-mode docs check
- alias integrity check
- wrapper integrity check
- plan gate script presence check

---

## Pollution Suggestion Format

```text
Found possible pollution in root navigation file:

- "cd apps/editor"
  Suggested target: apps/editor/AGENTS.md (or apps/editor/CLAUDE.md)

- "DATABASE_URL"
  Suggested target: services/api/AGENTS.md (or services/api/CLAUDE.md)
```

---

## Alias Repair Rule

legacy 文档仅允许保留以下结构：

```md
# Compatibility Alias

This file is kept for backward compatibility.

Canonical source of truth:

- `docs/<canonical-file>.md`

Do not update this file with new rules.
Update the canonical file instead.
```

如果 legacy 文件包含治理正文（规则、门禁、阈值等），必须迁移到 canonical 文件并将 legacy 文件重写为 alias 模板。

---

## Wrapper Repair Rule

legacy 脚本只允许 wrapper 语义：

```bash
#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/harness/<script>.sh" "$@"
```

禁止在 wrapper 中实现业务逻辑。

---

## ADR Exception Handling

若门禁临时降级，必须存在 `.harness/docs/decisions/ADR-exceptions/*.md`，并包含：
- `owner`
- `expires_on`
- `scope`

过期例外必须被 repair/doc-gardening 检出并恢复强门禁。

---

## Safety Rules

- Never rewrite user-authored content outside harness markers.
- Keep migrations reversible (patch-level, not full replacement).
- For ambiguous mapping, produce suggestion only and require confirmation.
