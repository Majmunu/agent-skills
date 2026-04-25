# Regression Fixture Matrix

用于 `harness-init` 自身回归验证的夹具矩阵。

---

## Fixture Layout

```txt
fixtures/
├── canonical-only/
├── legacy-only/
├── mixed-canonical-legacy/
├── single-node/
├── single-python/
├── single-go/
├── frontend-backend/
├── pnpm-monorepo/
├── nested-project/
├── empty-repo/
├── existing-agents/
├── partial-init/
└── mixed-docker-infra/
```

---

## Required Assertions

每个 fixture 至少验证：
- `SKILL.md` 通过 skill 校验，且正文保持精简（建议不超过 500 行）
- root navigation file 不污染
- project navigation file 生成正确
- canonical docs 生成为事实源
- legacy docs 被处理为 alias（不承载正文）
- `.harness/scripts/*` 为主入口
- legacy scripts 为 wrapper（无业务逻辑）
- 重复运行不重复
- 占位符检查符合预期（`<...>` fail, TODO warn）
- handoff contract 存在（root + project）
- repo-mode 判定符合预期（single/multi/nested）

---

## Strong Gate Fixtures

必须包含以下场景：
- `plan-gate-fail`: 跨模块 PR 无 plan 引用，预期 fail
- `plan-gate-pass`: 跨模块 PR 有有效 plan 且状态合法，预期 pass
- `plan-scope-project-pass`: multi-project 单项目作用域改动，使用 `<project>/.harness/docs/exec-plans/*`，预期 pass
- `plan-scope-root-pass`: multi-project 跨项目改动，使用 root `.harness/docs/exec-plans/*`，预期 pass
- `alias-drift-fail`: legacy 文档含治理正文，预期 fail
- `wrapper-drift-fail`: legacy 脚本非纯 wrapper，预期 fail
- `adr-expiry-fail`: ADR 例外过期仍尝试降级门禁，预期 fail
- `bootstrap-critical-fail`: bootstrap 轨道中 critical-gates 失败，预期阻断
- `degraded-no-git`: `git` 不可用时仍可完成初始化，验证结果包含 `not-run` 与风险说明
- `degraded-no-bash`: `bash` 不可用时使用 PowerShell fallback，项目导航包含双 shell 命令
- `placeholder-scope-scan`: 仓库含 `.agents/.claude/.qoder` 大量文档时，placeholder 检查仅扫描 harness 管理范围

---

## Suggested Test Record

```md
# Fixture Result: <name>

- Repo mode: <detected>
- Expected mode: <expected>
- Canonical docs: pass/fail
- Legacy alias integrity: pass/fail
- Wrapper integrity: pass/fail
- Root clean: pass/fail
- Project guides: pass/fail
- Plan gate: pass/fail
- Placeholder severity: pass/fail
- Runtime capability matrix: present/absent
- Validation not-run records: present/absent
- Idempotency: pass/fail
- Handoff coverage: pass/fail
- Notes: <details>
```
