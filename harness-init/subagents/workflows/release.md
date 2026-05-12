# Workflow: Release

> 零代码小程序设计平台 — 发布工作流

## Trigger

- Release milestone reached (planned release date)
- Sprint end with deliverables ready
- Hotfix deployment required (production-critical fix)
- Version bump scheduled

## Required Roles

| Role | Condition | Responsibility |
|------|-----------|----------------|
| `quality_gate_reviewer` | Always | 发布质量验证、门禁状态确认 |
| `governance_context_sync_lead` | Always | 发布文档、计划归档、上下文快照 |
| `architect` | If major release | 架构完整性确认、版本兼容性审查 |

**Role selection logic:** Standard releases require `quality_gate_reviewer` and `governance_context_sync_lead`. Major releases (breaking changes, new architecture) additionally require `architect` sign-off.

## Required Input Artifacts

- **Context snapshot** (current) — up-to-date project state summary
- **Active plans status** — all active ExecPlans with completion status
- **Failing gates list** — any currently failing quality gates with severity
- Release scope definition (features, fixes included)
- Dependency audit results (if applicable)

## Required Output Artifacts

- **Release readiness report** — comprehensive assessment including:
  - Gate status summary (all pass / exceptions noted)
  - Active plan completion status
  - Known issues and workarounds
  - Risk assessment
- **Changelog** — user-facing and developer-facing change documentation
- **Deployment artifacts** — built, tested, ready-to-deploy packages

## Required Gates

| Gate | Type | Blocking |
|------|------|----------|
| All critical gates pass | Automated | Yes |
| No blocking active plans | Review | Yes |
| No unresolved ADR exceptions expired | Review | Yes |
| Quality score >= `enforced_min` | Automated | Yes |
| `lint` | Automated | Yes |
| `test` | Automated | Yes |
| `typecheck` | Automated | Yes |
| `build` | Automated | Yes |

## Required Docs Updates

- `context-snapshot` updated to reflect release state
- Completed plans archived (moved from active to completed)
- Release notes generated and published
- Version references updated across documentation
- `tech-debt-tracker.md` reviewed and updated if debt was addressed

## Skip Conditions

**Hotfix releases** may skip non-critical gates with the following conditions:

- An **ADR exception** must be filed documenting:
  - Which gates are being skipped
  - Why the hotfix cannot wait for full gate compliance
  - Timeline for retroactive compliance
- Critical gates (test, build) may **never** be skipped
- The exception must be reviewed and closed within the next sprint

> Standard releases have no skip conditions — all gates must pass.

## Completion Criteria

- [ ] Release readiness report generated and reviewed
- [ ] All blocking issues resolved:
  - Critical gates passing ✓
  - No blocking active plans ✓
  - No expired ADR exceptions ✓
  - Quality score meets minimum threshold ✓
- [ ] Changelog complete and accurate
- [ ] Deployment successful (verified in target environment)
- [ ] Context snapshot updated to post-release state
- [ ] Completed plans archived
- [ ] Release notes published
- [ ] Post-deployment monitoring confirmed (no immediate regressions)
