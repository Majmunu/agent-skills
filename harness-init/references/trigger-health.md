# Trigger Health Reference

加载时机：skill 没有按预期触发、过度触发、上下文压缩后继续任务、或调整 `description`/入口规则前。

---

## Bottom Line

不要用“堆更多关键词”来修所有触发问题。先判断失败发生在哪一层，再修对应 owner。

---

## Trigger Health Layers

| Layer | Question | Evidence | Owner |
|---|---|---|---|
| L0 install/version | 当前安装的是预期版本吗 | skill path, version, README | install/update |
| L1 discovery | host 能发现 skill 吗 | skills list, discovery root | host discovery |
| L2 activation | 当前模式是否应该自动触发 | global rules, activation mode | host bootstrap |
| L3 router entry | 是否进入 harness-init 判断路径 | transcript, explicit request | entry rules |
| L4 task routing | 是否选中了正确 skill | representative prompts | skill description |
| L5 execution depth | skill 是否执行到足够深 | required output markers | skill body |
| L6 context pressure | 压缩/恢复后是否重新判断 | resume note, context snapshot | re-entry rule |
| L7 false positive | 简单任务是否被过度治理 | negative samples | trigger wording |

---

## Fast Path Cheapness

以下任务不应强制进入完整 harness 初始化流程：

- 简单事实问答
- 状态查询
- 一两行文字修改
- 已明确不需要写文件的讨论
- 用户只要求解释现有 harness 规则

这些任务可以读取最小证据后直接回答。只有当用户要求 init/repair/audit/maintain，或任务确实涉及项目 harness 结构时，才进入完整流程。

---

## Representative Samples

至少维护以下样本：

| Sample | Expected Route | Must Not Do |
|---|---|---|
| `harness init` | full harness-init | skip dry-run |
| `harness init scope=apps/editor` | scoped init | modify sibling projects |
| `harness repair` | repair mode | overwrite user content |
| `为什么需要 harness` | fast path explanation | create files |
| `看一下当前 harness 是否漂移` | audit/repair dry-run | silently patch |
| `普通 bug fix` | no harness-init unless harness files touched | force init ceremony |
| context compaction after init | compact re-entry check | assume previous route still active |

---

## Failure Report Shape

```text
TriggerHealthLayer:
ObservedPrompt:
ExpectedRoute:
ActualRoute:
FailureType: install | discovery | activation | routing | depth | context-pressure | false-positive
CanonicalOwner:
Fix:
RegressionSample:
```

---

## Change Rule

修改 skill `description`、入口规则或 global rules 前，必须：

1. 先记录失败层级。
2. 增加或更新代表性样本。
3. 确认不会让 simple tasks 进入完整治理流程。
4. 保持 `SKILL.md` compact，详细规则放在 reference。
