# Worktree Sandbox Reference

本文档定义 agent worktree sandbox 的完整规范。

## 概述

Worktree sandbox 允许智能体在隔离的 git worktree 中执行任务，避免影响主工作区。

## 命名规范

```
.worktrees/harness-<task-id>
```

示例：
- `.worktrees/harness-feat-123`
- `.worktrees/harness-bugfix-456`

## 脚本清单

| 脚本 | 用途 |
|------|------|
| `scripts/harness/worktree-create.sh` | 创建隔离 worktree |
| `scripts/harness/worktree-run.sh` | 在 worktree 中执行命令 |
| `scripts/harness/worktree-clean.sh` | 清理 worktree |
| `scripts/harness/worktree-status.sh` | 查看 worktree 状态 |
| `scripts/harness/start-worktree.sh` | 启动 worktree 中的 dev server |
| `scripts/harness/stop-worktree.sh` | 停止 worktree 中的 dev server |

## 创建流程

```bash
bash scripts/harness/worktree-create.sh <task-id> <branch>
```

行为：
1. 校验路径必须在 `.worktrees/` 下
2. 创建 `.worktrees/harness-<task-id>`
3. 如果已存在，输出 warn 并给出清理命令
4. 不删除未提交内容

## 执行流程

```bash
HARNESS_TARGET_SCOPE=apps/editor bash scripts/harness/worktree-run.sh <task-id> <command>
```

行为：
1. 进入对应 worktree
2. 根据 `.harness/runtime.yml` 执行命令
3. 捕获 stdout/stderr 到 `.harness/runs/<task-id>/`
4. 输出 pass/fail/not-run

## 清理流程

```bash
bash scripts/harness/worktree-clean.sh [--force] [<task-id>]
```

行为：
1. 只允许清理 `.worktrees/harness-*`
2. 清理前检查是否存在未提交改动
3. 有未提交改动时默认拒绝清理
4. 支持 `--force` 强制清理

## 禁止事项

- ❌ 禁止在 worktree 脚本中删除主工作区
- ❌ 禁止默认清理未提交改动
- ❌ 清理前必须检查路径是否在 `.worktrees/` 下
- ❌ 禁止清理非 `harness-*` 前缀的 worktree

## 降级模式

当 git worktree 不可用时（例如 git 版本过低）：
- 输出 `not-run: git worktree is not available`
- 建议使用手动目录复制作为替代
- 不伪装为 pass

## 输出格式

所有 worktree 脚本使用统一状态：
- `pass`: 操作成功
- `fail`: 操作失败（含 Reason/Evidence/Fix/Docs/Bypass）
- `warn`: 存在风险但不阻断
- `not-run`: 未执行（含原因和残余风险）
