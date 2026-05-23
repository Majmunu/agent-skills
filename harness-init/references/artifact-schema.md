# Artifact Schema Reference

加载时机：中高风险任务、长任务恢复、多 agent 分工、证据打包或 gate 输入组装时。

---

## Authority Boundary

Harness artifact 只允许作为：

- draft
- hint
- evidence bundle
- gate input
- handoff packet

Harness artifact 不允许声称自己是：

- authoritative gate decision
- final completion authority
- human approval replacement
- CI verdict replacement

项目事实源、CI 输出、人工审批和当前验证命令结果始终高于 artifact 摘要。

---

## Schema Version

当前最小 schema version：

```text
harness.schema.v1
```

所有 JSON sidecar artifact 必须包含：

- `schemaVersion`
- `artifactKind`
- `createdAt`
- `source`

---

## Artifact Kinds

### TaskIntentDraft

用途：明确任务目标、范围、成功证据和停止条件。

必填字段：

- `schemaVersion`
- `artifactKind`
- `requestedOutcome`
- `scope`
- `changeKinds`
- `riskHints`

可选字段：

- `goal`
- `successEvidence`
- `stopCondition`
- `nonGoals`

### BaselineReadSetHint

用途：提示本任务应该优先读取哪些基线文档。

必填字段：

- `schemaVersion`
- `artifactKind`
- `candidateDocs`
- `whyRelevant`
- `missingAuthority`

### ImpactStatementDraft

用途：描述影响面、owner、兼容边界和不做事项。

必填字段：

- `schemaVersion`
- `artifactKind`
- `affectedLayers`
- `owners`
- `invariants`
- `compatBoundary`
- `nonGoals`

### EvidenceBundleDraft

用途：把验证证据结构化，避免“完成了”但没有证据。

必填字段：

- `schemaVersion`
- `artifactKind`
- `artifactKey`
- `type`
- `source`
- `summary`
- `verifier`

### GateInputPack

用途：把 gate 所需输入打包给 CI、reviewer 或未来 runtime 使用。

必填字段：

- `schemaVersion`
- `artifactKind`
- `baselineRefs`
- `impactStatement`
- `compatPlan`
- `retirementPlan`
- `evidenceBundle`

### TodoCheckpointDraft

用途：长任务阶段检查点。

必填字段：

- `schemaVersion`
- `artifactKind`
- `taskId`
- `currentTodo`
- `completedTodos`
- `activeSlice`
- `evidenceRefs`
- `blockedOn`
- `nextStep`
- `updatedAt`

### ResumeStateHint

用途：压缩上下文、换 session 或 agent handoff 后恢复任务。

必填字段：

- `schemaVersion`
- `artifactKind`
- `taskId`
- `lastCheckpointRef`
- `resumeInstruction`
- `knownPartialWork`
- `mustReadBeforeContinuing`
- `unsafeToAssume`

### DriftCheckDraft

用途：检查任务执行期间目标、基线、兼容边界和退役计划是否漂移。

必填字段：

- `schemaVersion`
- `artifactKind`
- `taskId`
- `taskIntentRef`
- `baselineRefs`
- `scopeStatus`
- `compatStatus`
- `retirementStatus`
- `newRiskSignals`
- `decision`

允许的 `decision`：

- `continue`
- `pause-for-user`
- `needs-baseline-readback`
- `needs-verification`
- `blocked`

### SubagentContextPacket

用途：给子智能体最小上下文包，避免继承整段对话。

必填字段：

- `schemaVersion`
- `artifactKind`
- `task`
- `goal`
- `stopCondition`
- `relevantBaselineRefs`
- `relevantFiles`
- `knownFacts`
- `unknowns`
- `nonGoals`
- `expectedOutput`
- `verificationExpected`
- `mustReadExcerpts`
- `unsafeAssumptions`

---

## Storage Policy

优先使用现有 harness 结构，不创建第二套事实源：

- execution plan 相关：`docs/exec-plans/active/`
- 长任务工作记录：`docs/harness/work/YYYY-MM-DD-<slug>/`
- 证据包：`.harness/artifacts/`
- context snapshot：`docs/harness/context-snapshot.md`

所有 artifact 都是索引或证据包，不替代 canonical docs。
