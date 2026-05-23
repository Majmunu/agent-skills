# agent-skills

集中维护自研 AI agent skills。

## 当前技能

| Skill | 用途 | 来源 |
| --- | --- | --- |
| `harness-init` | 初始化和维护项目 harness、导航、计划、质量门禁、repair mode、熵治理、反馈闭环和 CI 治理 | `E:\mini_lang\.claude\skills\harness-init` |
| `add-component` | 为 `mini_workspace` 新增组件，覆盖运行时组件、配置、事件/动作契约和验证清单 | `E:\mini_lang\mini_workspace\.codex\skills\add-component` |
| `add-property-config` | 为 `mini_workspace` 组件维护属性面板配置、setter、变量绑定和配置验证规则 | `E:\mini_lang\mini_workspace\.codex\skills\add-property-config` |
| `react-code-standards` | React 代码规范与质量约束 | `E:\mini_lang\mini_workspace\skills\react-code-standards` |

## 维护规则

- 本仓库只收敛我们自己维护的项目/工程技能。
- `cron`、`office-cli`、`skill-creator`、`aionui-skills` 等外部或内置技能副本不纳入本仓库维护。
- 项目仓库内可以保留轻量引用或本地安装副本，但技能本体以这里为集中维护位置。
- 更新技能时同步完整技能目录，包括 `SKILL.md`、`references/`、`scripts/`、`templates/`、`tests/` 等资源。
- Shell 脚本和 Markdown 使用 LF 换行，避免 Windows checkout 后破坏可执行脚本。
