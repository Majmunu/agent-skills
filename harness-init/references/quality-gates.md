# Quality Gates Reference

加载时机：**Step 5 结构检查 + Step 5.5 CI 门禁**。

---

## Canonical Script Root

唯一实现入口：`.harness/scripts/`

必备脚本：
- `check-all.sh`
- `check-critical.sh`
- `check-placeholders.sh`
- `check-boundaries.sh`
- `check-plan-required.sh`
- `check-file-size.sh`
- `check-naming.sh`
- `check-logging.sh`
- `check-alias-integrity.sh`
- `check-wrapper-integrity.sh`
- `reproduce.sh`
- `validate.sh`
- `regression.sh`
- `pre-release.sh`
- `query-logs.sh`
- `query-metrics.sh`
- `doc-gardening.sh`

legacy 根脚本仅允许 wrapper。

---

## Gate Matrix

| Gate | Bootstrap | Enforced | Failure Meaning |
|---|---|---|---|
| plan-required | fail in `critical-gates` | fail | cross-module PR missing valid plan link |
| architecture-boundary | warning/fail by config | fail | forbidden dependency direction/import |
| custom-lint | warning/fail by config | fail | naming/file-size/logging/boundary convention broken |
| alias-integrity | fail in `critical-gates` | fail | legacy doc contains governance facts |
| wrapper-integrity | fail in `critical-gates` | fail | legacy script contains implementation logic |
| placeholder-angle | fail | fail | unresolved `<...>` placeholder found |
| placeholder-todo | warn | warn/fail by policy | unresolved TODO remained |
| expired-adr-exception | fail | fail | expired exception still suppressing gates |

---

## Verification Result States

所有门禁结果必须使用以下状态之一：

- `pass`: gate 执行并通过
- `fail`: gate 执行并失败
- `warn`: gate 执行但非阻断异常（仅在策略允许时）
- `not-run`: gate 未执行（工具缺失/环境不支持/上下文不足）

规则：
- `not-run` 必须在 init report 记录命令、原因、残余风险。
- `not-run` 绝不能计入 `pass`。
- bootstrap 允许 `not-run` 但必须可审计；enforced 不允许 blocking gates 为 `not-run`。

---

## Plan Scope Isolation

- single-project / nested-project: plan path under `.harness/docs/exec-plans/*`
- multi-project:
  - root `.harness/docs/exec-plans/*` for cross-project/repository plans
  - `<project>/.harness/docs/exec-plans/*` for project-scoped plans

plan-required gate must validate both path forms and enforce scope matching.

---

## Architecture Gate Minimums

CI 至少可判定：
- forbidden layer imports
- forbidden cross-project imports
- internal module access from sibling projects
- package boundary violations
- public API bypass
- generated file drift

---

## Custom Lint Minimums

CI 至少可判定：
- naming convention
- file size
- logging structure
- boundary validation
- error handling convention
- test placement convention

---

## Wrapper Integrity Rule

wrapper 必须满足：
- call canonical script under `.harness/scripts/`
- no duplicated logic
- argument passthrough (`"$@"`)
- exit code passthrough (`exec`)
- optional deprecation warning allowed

wrapper 创建规则：
- if legacy script exists, wrapper is required
- if legacy script path is referenced by docs/CI, wrapper is required
- if never existed and not referenced, wrapper is optional

---

## Alias Integrity Rule

legacy 文档必须是 alias 模板，不得包含治理正文。出现以下情况直接 fail：
- legacy 与 canonical 文件均包含规则条款
- legacy 文件新增约束阈值/门禁语义
- legacy 文件比 canonical 更新但未反映 canonical

---

## Minimal Gate Aggregator

`.harness/scripts/check-all.sh` 应串行汇总 gate 结果并输出 PASS/FAIL 汇总，至少包含：
- structure acceptance
- plan gate acceptance
- CI track config acceptance
- compatibility acceptance
- idempotency acceptance

要求：
- 读取 `HARNESS_TRACK=bootstrap|enforced`（默认可取 `enforced`）
- 支持读取 `.harness/gate-severity.yml` 决定 bootstrap/enforced 下的 blocking gates
- `HARNESS_STRICT_MODE=false` 仅可放宽非 blocking 的 `exit 2`
- blocking gate 在两轨都必须失败即阻断；security/auth/data-migration 在命中对应范围/label 时必须按 blocking 处理

---

## Governance Config Files

建议与门禁脚本一起维护：
- `.harness/plan-required-rules.yml`
- `.harness/gate-severity.yml`
- `.harness/canonical-paths.yml`（可选，用于 alias/canonical 映射）

缺失配置时：
- 可回落到默认规则
- 但必须输出明确 warning，且不得伪装成功

---

## Bootstrap Job Split

为避免 bootstrap 放水关键门禁：
- `bootstrap-observe`: 运行非关键检查，可设为 non-blocking
- `critical-gates`: 仅运行 `.harness/scripts/check-critical.sh`，覆盖 placeholder-angle/expired-ADR + 必需 plan/alias/wrapper integrity，必须 blocking
- `security/auth/data-migration`：当改动范围或 PR label 命中对应域时，必须启用对应 gate；未命中时脚本缺失可 warning
