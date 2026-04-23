# Agent Autonomy Template

加载时机：**Step 3 文档骨架 + Step 5.5 CI 策略 + Step 9 报告**。

---

## Required Document

canonical 文件：`.harness/docs/agent-autonomy.md`

---

## Levels

### L1: Assisted Coding

Agent may:
- modify code
- run local validation

Requires:
- human review
- human merge

### L2: Self-checking Contributor

Agent may:
- modify code
- run validation
- update tests/docs
- respond to review comments

Requires:
- CI green
- human merge

### L3: PR Owner

Agent may:
- create PR
- fix CI
- update plan
- update feedback loop entries

Requires:
- linked execution plan for medium/high risk work
- audit trail
- rollback plan

### L4: Low-risk Auto-merge

Agent may:
- auto-merge low-risk changes

Only if:
- enforced CI green
- no architecture boundary violation
- no security/auth/data migration change
- plan gate satisfied when required
- rollback path exists
- audit trail complete

---

## Promotion Requirements

每次升一级必须满足：
- `previous_level_stable_days >= 14`
- `rollback_strategy_exists == true`
- `audit_trail_complete == true`
- `enforced_ci_green_rate >= 95%`
- `critical_incidents == 0`
- `owner_approval == true`

---

## Rollback Triggers

- CI regression
- production incident
- SLO degradation
- security finding
- missing audit trail
- unauthorized scope expansion

---

## Audit Fields

建议每次自治动作记录：
- actor
- level
- scope
- plan link
- CI evidence
- reviewer/approver
- merge decision
- rollback reference
