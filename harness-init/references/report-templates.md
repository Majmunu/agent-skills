# Harness Init Report Templates

加载时机：
- **Step 0 Dry-run Plan**（执行前计划）
- **Step 9 Init Report**（执行后报告）
- **Repair Mode**（遗留仓库修复后报告）

---

## Dry-run / Plan Output

初始化前先输出以下结构：

```md
# Harness Init Dry-run Plan

## Repo Mode

<single-project / multi-project / nested-project>

## Canonical Policy

- Canonical docs root: `.harness/docs/`
- Canonical script root: `.harness/scripts/`
- Legacy policy: compatibility alias / wrapper only

## Detected Project Roots

- <path> (<reason>)

## Files to Create

- <path>

## Files to Update

- <path>

## Files to Keep as Alias/Wrapper

- <legacy path> -> <canonical path>

## Root-level Writes

- <path + marker block id>

## Project-level Writes

- <path + marker block id>

## Strong Gates

- Plan gate: <enabled/disabled>
- Architecture gate: <enabled/disabled>
- Alias integrity gate: <enabled/disabled>
- Placeholder gate: <enabled/disabled>

## Runtime Capability Matrix

| Capability | Status | Check Command | Notes |
|---|---|---|---|
| git | <available/unavailable> | `<command>` | <note> |
| bash/sh | <available/unavailable> | `<command>` | <note> |
| pwsh | <available/unavailable> | `<command>` | <note> |
| node | <available/unavailable> | `<command>` | <note> |
| python | <available/unavailable> | `<command>` | <note> |
| rg/find/grep | <available/unavailable> | `<command>` | <note> |

## Risks / Warnings

- <warning>
```

执行规则：
- If the agent can safely edit files, proceed after producing the plan.
- If the environment is ambiguous, output plan only and ask for explicit confirmation.

---

## Init Report Output

默认输出路径：
- `single-project` / `nested-project`：`.harness/docs/init-report.md`
- `multi-project`：`.harness/docs/init-report.md`

模板：

```md
# Harness Init Report

## Mode

<single-project / multi-project / nested-project>

## Detected Projects

| Path | Type | Reason |
|---|---|---|
| <path> | <app/service/package/lib> | <strong signal/source dirs/workspace declared/user scope> |

## Canonical Documents

- `.harness/docs/architecture-boundaries.md`
- `.harness/docs/ci-governance.md`
- `.harness/docs/agent-autonomy.md`
- `.harness/docs/observability.md`
- `.harness/docs/feedback-loops.md`
- `.harness/docs/entropy-gc.md`
- `.harness/docs/exec-plans/active/`
- `.harness/docs/exec-plans/completed/`
- `.harness/docs/exec-plans/tech-debt-tracker.md`

## Created Files

- <path>

## Updated Files

- <path>

## Skipped Files

- <path> (<reason>)

## Compatibility Mapping Applied

- <legacy path> -> <canonical path> (<alias/wrapper>)

## CI Track

- Current mode: <bootstrap / enforced>
- Promotion criteria: <stable_days / failure_rate / critical_path_coverage / false_positive_count>
- Demotion policy: <ADR exception + expiry required>

## Autonomy Level

- Current level: <L1/L2/L3/L4>
- Promotion requirements: <summary or link>
- Rollback policy: <link or summary>
- Audit policy: <link or summary>

## Strong Gate Results

- Plan gate: <pass/fail/warn/not-run>
- Architecture gate: <pass/fail/warn/not-run>
- Alias integrity gate: <pass/fail/warn/not-run>
- Placeholder gate: <pass/fail/warn/not-run>

## Runtime Capability Matrix

| Capability | Status | Check Command | Notes |
|---|---|---|---|
| git | <available/unavailable> | `<command>` | <note> |
| bash/sh | <available/unavailable> | `<command>` | <note> |
| pwsh | <available/unavailable> | `<command>` | <note> |
| node | <available/unavailable> | `<command>` | <note> |
| python | <available/unavailable> | `<command>` | <note> |
| rg/find/grep | <available/unavailable> | `<command>` | <note> |

## Validation Not Run

| Command | Reason | Residual Risk |
|---|---|---|
| `<command>` | <why not run> | <risk> |

## Warnings

- <warning>

## Next Step

Use `harness-engineering` for implementation work.
```

---

## Repair / Migration Report Output

用于 legacy-only 或 mixed 仓库：

```md
# Harness Repair Report

## Repo Mode

<single-project / multi-project / nested-project>

## Migration Summary

- Legacy-only docs found: <n>
- Mixed canonical/legacy docs found: <n>
- Alias files created/updated: <n>
- Wrapper scripts created/updated: <n>
- Duplicate fact sources resolved: <n>

## Drift Findings

- <legacy file contains governance facts>
- <wrapper drift>
- <missing canonical doc>

## Actions

- <action>

## Remaining Manual Work

- <item>
```
