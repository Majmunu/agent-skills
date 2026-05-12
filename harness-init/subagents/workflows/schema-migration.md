# Workflow: Schema Migration

> 零代码小程序设计平台 — Schema 迁移工作流

## Trigger

- Schema structure change (adding/removing/modifying fields)
- Data model evolution (new entities, relationship changes)
- Database migration required
- DSL version upgrade affecting data format
- Backward-incompatible change to component/page/action schema

## Required Roles

| Role | Condition | Responsibility |
|------|-----------|----------------|
| `architect` | Always (**blocking**) | Schema 规范审查、兼容性决策 |
| `runtime_dataflow_engineer` | Always | 迁移实现、运行时兼容性保障 |
| `quality_gate_reviewer` | Always | 兼容性测试、回滚验证 |
| `governance_context_sync_lead` | Always | 版本文档、计划管理、ADR 记录 |

**Note:** `architect` role is **blocking** — schema migrations have high blast radius and require explicit architectural approval.

## Required Input Artifacts

- **ExecPlan** (mandatory) — migration phases, timeline, rollback windows
- **Backward compatibility analysis** — documenting:
  - Which existing data/schemas are affected
  - Whether migration is additive (safe) or breaking (requires migration)
  - Impact on existing deployed mini-programs
- **Migration script** — code to transform data from old schema to new
- **Rollback script** — code to revert migration if issues are detected
- Schema version diff (old vs. new)

## Required Output Artifacts

- **Migration code** — tested, idempotent migration implementation
- **Rollback code** — verified rollback that restores previous state
- **Compatibility test** — tests verifying:
  - Old data works with new code (forward compatibility)
  - New data can be rolled back (backward compatibility)
  - Edge cases (empty data, partial migration, large datasets)
- **Updated Schema documentation** — version history, field descriptions, constraints

## Required Gates

| Gate | Type | Blocking |
|------|------|----------|
| Schema compatibility check | Automated | Yes |
| Migration dry-run | Automated | Yes |
| Rollback verification | Automated | Yes |
| Human approval for production | Manual | Yes (**blocking**) |
| `lint` | Automated | Yes |
| `test` | Automated | Yes |
| `typecheck` | Automated | Yes |
| `build` | Automated | Yes |

## Required Docs Updates

- Schema version documentation — updated with new version, changelog, migration notes
- `architecture-boundaries.md` — updated if schema change affects module boundaries
- Active ExecPlan — updated with migration status and phase completion
- ADR — if the migration represents a significant design decision
- `context-snapshot` — updated to reflect current schema version

## Skip Conditions

**None** — schema migrations always require the full workflow with human approval.

> Schema changes affect all deployed mini-programs and stored data. There is no "trivial" schema migration. Even adding an optional field requires compatibility verification and rollback planning.

## Completion Criteria

- [ ] Migration tested successfully in non-production environment
- [ ] Rollback verified — can restore previous schema state cleanly
- [ ] **Human approval obtained** for production deployment
- [ ] All automated gates pass:
  - Schema compatibility check ✓
  - Migration dry-run ✓
  - Rollback verification ✓
  - lint/test/typecheck/build ✓
- [ ] Compatibility tests pass (forward and backward)
- [ ] Schema version documentation updated
- [ ] ExecPlan status updated
- [ ] No data loss or corruption in test environments
- [ ] Monitoring/alerting configured for post-migration observation
