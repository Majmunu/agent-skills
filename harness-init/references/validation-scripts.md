# Step 8: Validation Scripts Reference

> This file contains the full validation bash scripts extracted from SKILL.md Step 8.
> These scripts check harness completeness by repo mode (single-project, multi-project, nested-project).

---

运行以下验证脚本，按 repo mode 检查 harness 完整性：
（边界检测函数需与 `references/stack-detection.md` 保持一致，避免初始化与验证判定漂移）

canonical 入口建议：
- `scripts/harness/check-all.sh`（聚合全部检查）
- `scripts/harness/check-critical.sh`（bootstrap critical 最小阻断面）

```bash
#!/usr/bin/env bash
errors=0
warn=0

check_file() {
  if [ ! -f "$1" ]; then
    echo "❌ MISSING file: $1"; errors=$((errors+1))
  elif [ ! -s "$1" ]; then
    echo "⚠️  EMPTY file: $1"; warn=$((warn+1))
  else
    echo "✅ OK: $1"
  fi
}

check_dir() {
  [ -d "$1" ] && echo "✅ OK: $1/" || { echo "❌ MISSING dir: $1/"; errors=$((errors+1)); }
}

check_navigation_file() {
  local base="${1%/}"
  local agents_path
  local claude_path
  if [ "$base" = "." ]; then
    agents_path="AGENTS.md"
    claude_path="CLAUDE.md"
  else
    agents_path="$base/AGENTS.md"
    claude_path="$base/CLAUDE.md"
  fi

  if [ -f "$agents_path" ] || [ -f "$claude_path" ]; then
    echo "✅ OK: navigation file ($base)"
  else
    echo "❌ MISSING navigation file in $base: AGENTS.md or CLAUDE.md"
    errors=$((errors+1))
  fi
}

has_strong_root_signal() {
  local dir="$1"
  [ -f "$dir/package.json" ] || [ -f "$dir/go.mod" ] || [ -f "$dir/pyproject.toml" ] || \
  [ -f "$dir/Cargo.toml" ] || [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] || \
  [ -f "$dir/composer.json" ] || ls "$dir"/*.csproj >/dev/null 2>&1
}

load_harnessignore_patterns() {
  [ -f ".harnessignore" ] || return 0
  grep -Ev '^[[:space:]]*(#|$)' .harnessignore 2>/dev/null || true
}

is_ignored_path() {
  local path="$1"
  local rule

  case "$path" in
    node_modules/*|dist/*|build/*|vendor/*|third_party/*|examples/*|fixtures/*) return 0 ;;
  esac

  while IFS= read -r rule; do
    rule="${rule%/}"
    [ -z "$rule" ] && continue
    case "$path" in
      "$rule"|"$rule"/*) return 0 ;;
    esac
  done < <(load_harnessignore_patterns)

  return 1
}

has_weak_root_signal() {
  local dir="$1"
  [ -f "$dir/Makefile" ] || [ -f "$dir/Dockerfile" ] || [ -f "$dir/docker-compose.yml" ]
}

is_workspace_scope_path() {
  local dir="$1"
  case "$dir" in
    apps/*|packages/*|services/*|frontend|backend|libs/*|modules/*) return 0 ;;
    *) return 1 ;;
  esac
}

workspace_declares_dir() {
  local dir="$1"
  local parent wildcard
  parent="${dir%%/*}"
  wildcard="$parent/*"

  if [ -f "pnpm-workspace.yaml" ] && grep -Eq "^[[:space:]]*-[[:space:]]*[\"']?($dir|$wildcard)[\"']?[[:space:]]*$" pnpm-workspace.yaml; then
    return 0
  fi
  if [ -f "lerna.json" ] && grep -Eq "\"($dir|$wildcard)\"" lerna.json; then
    return 0
  fi
  if [ -f "package.json" ] && grep -Eq "\"($dir|$wildcard)\"" package.json; then
    return 0
  fi
  if [ -f "nx.json" ] && grep -Eq "\"$dir\"" nx.json; then return 0; fi
  if [ -f "workspace.json" ] && grep -Eq "\"$dir\"" workspace.json; then return 0; fi
  if [ -f "turbo.json" ] && grep -Eq "\"$dir\"" turbo.json; then return 0; fi

  return 1
}

has_project_source_dirs() {
  local dir="$1"
  [ -d "$dir/src" ] || [ -d "$dir/cmd" ] || [ -d "$dir/internal" ] || [ -d "$dir/app" ]
}

should_promote_weak_signal_dir() {
  local dir="$1"
  is_workspace_scope_path "$dir" && return 0
  has_project_source_dirs "$dir" && return 0
  [ -n "${HARNESS_TARGET_SCOPE:-}" ] && [ "${HARNESS_TARGET_SCOPE}" = "$dir" ] && return 0
  return 1
}

should_promote_workspace_candidate() {
  local dir="$1"
  has_strong_root_signal "$dir" && return 0
  has_project_source_dirs "$dir" && return 0
  workspace_declares_dir "$dir" && return 0
  [ -n "${HARNESS_TARGET_SCOPE:-}" ] && [ "${HARNESS_TARGET_SCOPE}" = "$dir" ] && return 0
  return 1
}

has_explicit_workspace_config() {
  [ -f "pnpm-workspace.yaml" ] || [ -f "turbo.json" ] || [ -f "nx.json" ] || \
  [ -f "lerna.json" ] || [ -f "rush.json" ] || [ -f "workspace.json" ] || \
  ([ -f "package.json" ] && python3 -c "import json; d=json.load(open('package.json')); exit(0 if 'workspaces' in d else 1)" 2>/dev/null)
}

detect_workspace_dir_candidates() {
  for d in apps/* packages/* services/* frontend backend libs/* modules/*; do
    if [ -d "$d" ] && ! is_ignored_path "$d"; then
      echo "$d"
    fi
  done
}

detect_workspace_dirs() {
  detect_workspace_dir_candidates | while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue
    if should_promote_workspace_candidate "$candidate"; then
      echo "$candidate"
    fi
  done
}

detect_strong_project_roots() {
  local signal_pattern='\( -name package.json -o -name go.mod -o -name pyproject.toml -o -name Cargo.toml -o -name pom.xml -o -name build.gradle -o -name build.gradle.kts -o -name composer.json -o -name "*.csproj" \)'
  if has_strong_root_signal "."; then
    echo "."
  fi
  eval "find . -mindepth 2 -maxdepth 4 $signal_pattern -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/target/*' -not -path '*/dist/*' -not -path '*/build/*'" \
    | xargs -r -I {} dirname {} \
    | sed 's#^\./##' \
    | while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if ! is_ignored_path "$candidate"; then
          echo "$candidate"
        fi
      done
}

detect_weak_project_roots() {
  local weak_pattern='\( -name Makefile -o -name Dockerfile -o -name docker-compose.yml \)'
  if has_weak_root_signal "." && should_promote_weak_signal_dir "."; then
    echo "."
  fi
  eval "find . -mindepth 2 -maxdepth 4 $weak_pattern -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/target/*' -not -path '*/dist/*' -not -path '*/build/*'" \
    | xargs -r -I {} dirname {} \
    | sed 's#^\./##' \
    | while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if ! is_ignored_path "$candidate" && should_promote_weak_signal_dir "$candidate"; then
          echo "$candidate"
        fi
      done
}

detect_project_roots() {
  {
    detect_strong_project_roots
    detect_weak_project_roots
    detect_workspace_dirs
  } | sed '/^$/d' | sort -u | while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if ! is_ignored_path "$candidate"; then
          echo "$candidate"
        fi
      done
}

detect_nested_project() {
  local git_top
  git_top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$git_top" ] && [ "$(pwd -P)" != "$(cd "$git_top" && pwd -P)" ] && has_strong_root_signal "."; then
    echo "nested-project"
    return
  fi
  echo "not-nested"
}

detect_repo_mode() {
  local roots_count
  if [ "$(detect_nested_project)" = "nested-project" ]; then
    echo "nested-project"
    return
  fi
  roots_count=$(detect_project_roots | wc -l | tr -d ' ')
  if [ "$roots_count" -gt 1 ]; then
    echo "multi-project"
    return
  fi
  if has_explicit_workspace_config && [ "$roots_count" -ge 1 ]; then
    echo "multi-project"
    return
  fi
  echo "single-project"
}

mode=$(detect_repo_mode)
echo "Detected repo mode: $mode"

if [ "$mode" = "single-project" ]; then
  echo "── Validation: Single-project ──"
  check_navigation_file "."
  for f in docs/architecture-boundaries.md docs/constraints.md docs/testing.md docs/ci-governance.md docs/agent-autonomy.md docs/observability.md docs/feedback-loops.md docs/entropy-gc.md; do
    check_file "$f"
  done
  check_dir "docs/exec-plans/active"
  check_dir "docs/exec-plans/completed"
  check_file "docs/exec-plans/tech-debt-tracker.md"
  check_dir "docs/decisions"
elif [ "$mode" = "nested-project" ]; then
  echo "── Validation: Nested-project ─"
  check_navigation_file "."
  for f in docs/architecture-boundaries.md docs/constraints.md docs/testing.md docs/observability.md docs/feedback-loops.md docs/entropy-gc.md; do
    check_file "$f"
  done
  [ -f "docs/agent-autonomy.md" ] && check_file "docs/agent-autonomy.md" || check_file "../docs/agent-autonomy.md"
  [ -f "docs/ci-governance.md" ] && check_file "docs/ci-governance.md" || check_file "../docs/ci-governance.md"
  [ -d "docs/exec-plans/active" ] && check_dir "docs/exec-plans/active" || check_dir "../docs/exec-plans/active"
  [ -d "docs/exec-plans/completed" ] && check_dir "docs/exec-plans/completed" || check_dir "../docs/exec-plans/completed"
  [ -f "docs/exec-plans/tech-debt-tracker.md" ] && check_file "docs/exec-plans/tech-debt-tracker.md" || check_file "../docs/exec-plans/tech-debt-tracker.md"
  check_dir "docs/decisions"
else
  echo "── Validation: Multi-project ───"
  check_navigation_file "."
  check_file "docs/architecture-boundaries.md"
  check_file "docs/ci-governance.md"
  check_file "docs/agent-autonomy.md"
  check_file "docs/observability.md"
  check_file "docs/feedback-loops.md"
  check_file "docs/entropy-gc.md"
  check_dir "docs/exec-plans/active"
  check_dir "docs/exec-plans/completed"
  check_file "docs/exec-plans/tech-debt-tracker.md"
  check_dir "docs/decisions"

  while IFS= read -r project_root; do
    [ -z "$project_root" ] && continue
    [ "$project_root" = "." ] && continue
    echo "Checking project scope: $project_root"
    check_navigation_file "$project_root"
    check_file "$project_root/docs/architecture-boundaries.md"
    check_file "$project_root/docs/constraints.md"
    check_file "$project_root/docs/testing.md"
    check_file "$project_root/docs/observability.md"
    check_file "$project_root/docs/feedback-loops.md"
    check_file "$project_root/docs/entropy-gc.md"
    check_dir "$project_root/docs/exec-plans/active"
    check_dir "$project_root/docs/exec-plans/completed"
    check_file "$project_root/docs/exec-plans/tech-debt-tracker.md"
  done < <(detect_project_roots)
fi

echo "── Hooks / CI ──────────────────"
([ -f ".pre-commit-config.yaml" ] || [ -d ".husky" ] || [ -f "lefthook.yml" ]) \
  && echo "✅ OK: local hooks" || echo "⚠️  WARNING: no local hooks configured"

echo ""
echo "Result: $errors error(s), $warn warning(s)"
[ $errors -eq 0 ] && echo "🎉 Harness validation PASSED" || { echo "💥 Harness validation FAILED"; exit 1; }
```

占位符残留检查（仅扫描 harness 管理范围，避免全仓镜像文档误报与超时）：
注：unknown stack 场景下，若 `TODO/待补充` 已记录在 `docs/decisions/ADR-0001-harness-init.md`，该类结果按 warning 处理，不视为初始化失败。

```bash
echo "── Placeholder Check ─────────────"
placeholder_errors=0
scan_warn=0

SCAN_ROOTS=()
[ -f "AGENTS.md" ] && SCAN_ROOTS+=("AGENTS.md")
[ -f "CLAUDE.md" ] && SCAN_ROOTS+=("CLAUDE.md")
[ -d "docs" ] && SCAN_ROOTS+=("docs")
for p in apps/* packages/* services/*; do
  [ -d "$p/docs" ] && SCAN_ROOTS+=("$p/docs")
done

if [ "${#SCAN_ROOTS[@]}" -eq 0 ]; then
  echo "WARNING: no harness markdown targets found, skip placeholder scan"
  scan_warn=1
fi

load_harnessignore_patterns() {
  [ -f ".harnessignore" ] || return 0
  grep -Ev '^[[:space:]]*(#|$)' .harnessignore 2>/dev/null || true
}

is_ignored_path() {
  local path="$1"
  local rule

  case "$path" in
    node_modules/*|dist/*|build/*|vendor/*|third_party/*|examples/*|fixtures/*|.git/*|.agents/*|.claude/*|.qoder/*|.workflow/*|.idea/*|.vscode/*|.turbo/*|.yarn/*) return 0 ;;
  esac

  while IFS= read -r rule; do
    rule="${rule%/}"
    [ -z "$rule" ] && continue
    case "$path" in
      "$rule"|"$rule"/*) return 0 ;;
    esac
  done < <(load_harnessignore_patterns)

  return 1
}

filter_ignored_results() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file_path="${line%%:*}"
    file_path="${file_path#./}"
    if ! is_ignored_path "$file_path"; then
      echo "$line"
    fi
  done
}

ANGLE_PLACEHOLDERS=""
TODO_PLACEHOLDERS=""

if [ "${#SCAN_ROOTS[@]}" -gt 0 ]; then
  ANGLE_PLACEHOLDERS=$(
    find "${SCAN_ROOTS[@]}" -type f -name "*.md" -print0 \
    | xargs -0 -r grep -nE "<[^>]+>" 2>/dev/null \
    | grep -v "harness-init:start" \
    | grep -v "harness-init:end" \
    | grep -v "://" \
    | filter_ignored_results \
    || true
  )

  TODO_PLACEHOLDERS=$(
    find "${SCAN_ROOTS[@]}" -type f -name "*.md" -print0 \
    | xargs -0 -r grep -nE "TODO|FIXME|TBD|待补充" 2>/dev/null \
    | grep -v "harness-init:start" \
    | grep -v "harness-init:end" \
    | filter_ignored_results \
    || true
  )
fi

if [ -n "$ANGLE_PLACEHOLDERS" ]; then
  echo "$ANGLE_PLACEHOLDERS"
  echo "ERROR: unresolved angle-bracket placeholders found"
  placeholder_errors=$((placeholder_errors+1))
else
  echo "OK: no unresolved angle-bracket placeholders"
fi

if [ -n "$TODO_PLACEHOLDERS" ]; then
  echo "$TODO_PLACEHOLDERS"
  if [ -f "docs/decisions/ADR-0001-harness-init.md" ] && \
     grep -q "未知技术栈" "docs/decisions/ADR-0001-harness-init.md"; then
    echo "WARNING: TODO placeholders found (unknown-stack ADR recorded)"
  else
    echo "WARNING: TODO placeholders found"
  fi
else
  echo "OK: no TODO placeholders"
fi

[ "$scan_warn" -eq 1 ] && echo "WARNING: placeholder scan executed in degraded target mode"

echo "── Root Scope Pollution Check ───"
if [ -f "scripts/check-agents-scope.mjs" ]; then
  node scripts/check-agents-scope.mjs
elif [ -f "scripts/check-agents-scope.sh" ]; then
  bash scripts/check-agents-scope.sh
elif [ -f "scripts/check-agents-scope.ps1" ]; then
  pwsh -File scripts/check-agents-scope.ps1
else
  echo "SKIP: scripts/check-agents-scope.sh/.ps1/.mjs not found"
fi

echo "── Harness Command Surface Check ─"
for cmd in scope-check docs-check arch-check validate:harness; do
  if grep -q "\"$cmd\"" package.json 2>/dev/null; then
    echo "✅ OK: package.json script '$cmd'"
  else
    echo "⚠️  WARNING: missing package.json script '$cmd'"
  fi
done

echo "── Automation Surface Check ──────"
if [ -f "scripts/harness/check-plan-required.sh" ] || [ -f "scripts/harness/check-plan-required.ps1" ] || [ -f "scripts/harness/check-plan-required.mjs" ] || [ -f "scripts/harness/check-plan-required.py" ]; then
  echo "✅ OK: cross-module plan gate script"
else
  echo "❌ MISSING: scripts/harness/check-plan-required.*"
  errors=$((errors+1))
fi
if [ -f "scripts/harness/doc-gardening.sh" ] || [ -f "scripts/harness/doc-gardening.ps1" ] || [ -f "scripts/harness/doc-gardening.mjs" ] || [ -f "scripts/harness/doc-gardening.py" ]; then
  echo "✅ OK: doc-gardening automation script"
else
  echo "❌ MISSING: scripts/harness/doc-gardening.*"
  errors=$((errors+1))
fi
if [ -f "scripts/harness/check-alias-integrity.sh" ] || [ -f "scripts/harness/check-alias-integrity.ps1" ] || [ -f "scripts/harness/check-alias-integrity.mjs" ] || [ -f "scripts/harness/check-alias-integrity.py" ]; then
  echo "✅ OK: alias integrity script"
else
  echo "❌ MISSING: scripts/harness/check-alias-integrity.*"
  errors=$((errors+1))
fi
if [ -f "scripts/harness/check-critical.sh" ] || [ -f "scripts/harness/check-critical.ps1" ] || [ -f "scripts/harness/check-critical.mjs" ] || [ -f "scripts/harness/check-critical.py" ]; then
  echo "✅ OK: critical gates script"
else
  echo "❌ MISSING: scripts/harness/check-critical.*"
  errors=$((errors+1))
fi

echo "── Canonical Script Surface Check ─"
for f in scripts/harness/check-all scripts/harness/check-critical scripts/harness/check-placeholders scripts/harness/check-boundaries scripts/harness/check-file-size scripts/harness/check-naming scripts/harness/check-logging scripts/harness/check-alias-integrity scripts/harness/check-wrapper-integrity scripts/harness/reproduce scripts/harness/validate scripts/harness/regression scripts/harness/pre-release scripts/harness/query-logs scripts/harness/query-metrics; do
  if [ -f "$f.sh" ] || [ -f "$f.ps1" ]; then
    echo "✅ OK: $f.(sh|ps1)"
  else
    echo "❌ MISSING: $f.(sh|ps1)"
    errors=$((errors+1))
  fi
done

echo "── Compatibility Wrapper Check ────"
is_wrapper_required() {
  local wrapper="$1"
  [ -f "$wrapper" ] && return 0
  [ -f "AGENTS.md" ] && grep -q "$wrapper" AGENTS.md 2>/dev/null && return 0
  [ -f "CLAUDE.md" ] && grep -q "$wrapper" CLAUDE.md 2>/dev/null && return 0
  [ -f ".gitlab-ci.yml" ] && grep -q "$wrapper" .gitlab-ci.yml 2>/dev/null && return 0
  [ -d "docs" ] && grep -R --include="*.md" -n "$wrapper" docs 2>/dev/null | head -n 1 >/dev/null && return 0
  [ -d ".github/workflows" ] && grep -R --include="*.yml" --include="*.yaml" -n "$wrapper" .github/workflows 2>/dev/null | head -n 1 >/dev/null && return 0
  return 1
}

for base in scripts/check-all scripts/validate scripts/regression; do
  sh_wrapper="${base}.sh"
  ps_wrapper="${base}.ps1"
  if [ -f "$sh_wrapper" ]; then
    if grep -q '/harness/' "$sh_wrapper"; then
      echo "✅ OK: wrapper $sh_wrapper -> scripts/harness/*"
    else
      echo "❌ INVALID wrapper: $sh_wrapper (must call scripts/harness/*)"
      errors=$((errors+1))
    fi
  elif [ -f "$ps_wrapper" ]; then
    if grep -Eqi 'scripts[/\\]harness[/\\]' "$ps_wrapper"; then
      echo "✅ OK: wrapper $ps_wrapper -> scripts/harness/*"
    else
      echo "❌ INVALID wrapper: $ps_wrapper (must call scripts/harness/*)"
      errors=$((errors+1))
    fi
  else
    if is_wrapper_required "$sh_wrapper" || is_wrapper_required "$ps_wrapper"; then
      echo "❌ MISSING required compatibility wrapper ${base}.(sh|ps1) (referenced by docs/CI or legacy contract)"
      errors=$((errors+1))
    else
      echo "⚠️  WARNING: optional compatibility wrapper not present ${base}.(sh|ps1)"
    fi
  fi
done

if [ "$placeholder_errors" -gt 0 ]; then
  echo "💥 Placeholder validation FAILED"
  exit 1
fi
```

---

## Checklist (Original)

**逐项确认 Checklist**:

- [ ] 已盘点现有 harness 文件并记录冲突
- [ ] 已创建主导航文件 `AGENTS.md` 或 `CLAUDE.md`
- [ ] 已按 repo mode 建立 `docs/` 结构（single 或 multi-project 分层）
- [ ] 已配置 lint / format 命令
- [ ] 已配置 type-check 或等效静态检查
- [ ] 已配置 test 命令
- [ ] 已配置结构测试或 architecture check
- [ ] 已配置 pre-commit 或等效本地门禁
- [ ] 已配置至少一个 drift / GC 执行入口
- [ ] 已输出健康基线或待办清单
- [ ] 已记录 ADR-0001 初始化决策
- [ ] 已建立 `docs/exec-plans/{active,completed,tech-debt-tracker.md}`
- [ ] multi-project 已建立 project-level `docs/exec-plans/*`（每个项目作用域）
- [ ] 已建立 canonical docs（`architecture-boundaries/ci-governance/agent-autonomy/observability`）
- [ ] legacy docs 已转 alias（无并行事实源）
- [ ] 已定义跨模块 PR 的 plan 关联门禁
- [ ] 已定义 bootstrap → enforced 升级条件（N 天稳定、失败率阈值、关键路径覆盖率）
- [ ] 已配置 `.harness/plan-required-rules.yml` 与 `.harness/gate-severity.yml`
- [ ] 已定义自治等级（L1-L4）与回滚/审计策略
- [ ] 已定义 ADR 例外到期回收策略
- [ ] 已配置 doc-gardening 定时任务或等效自动化入口
- [ ] bootstrap 已拆分 `bootstrap-observe` 与 `critical-gates`，并确保关键门禁不可放水
- [ ] `critical-gates` 仅运行 `scripts/harness/check-critical.sh`（不直接运行 `check-all.sh`）
- [ ] `critical-gates` 已注入 PR 上下文（`GITHUB_EVENT_NAME`、`PR_BODY_FILE`、`.harness/pr-body.txt`）
- [ ] 已输出 runtime capability matrix（git/bash/pwsh/node/python/rg）
- [ ] 所有未执行验证已记录为 `not-run`（包含 command/reason/risk）

## Acceptance Criteria

After initialization:

- [ ] Correctly detects single-project, multi-project, and nested-project repos.
- [ ] Treats workspace directories as candidates before confirming project roots.
- [ ] Root navigation file (`AGENTS.md` or `CLAUDE.md`) remains global-only in multi-project repos.
- [ ] Every confirmed project root has nearest navigation file (`AGENTS.md` or `CLAUDE.md`).
- [ ] Project-specific commands never enter root navigation file.
- [ ] Root docs and project docs are separated.
- [ ] `harness-engineering` handoff exists at root and project level.
- [ ] Execution plans are first-class artifacts (`docs/exec-plans/*` and `<project>/docs/exec-plans/*`) and referenced by cross-module changes.
- [ ] In multi-project mode, root execution plans are repo/cross-project only; project plans live in `<project>/docs/exec-plans/*`.
- [ ] Architecture and custom lint rules are executable and CI-enforced (pass/fail).
- [ ] Dual-track CI (bootstrap + enforced) exists with explicit promotion criteria.
- [ ] Bootstrap track is split into `bootstrap-observe` (non-critical) and `critical-gates` (always blocking).
- [ ] `critical-gates` runs `scripts/harness/check-critical.sh` instead of full `check-all.sh`.
- [ ] `critical-gates` passes PR event/body context (`GITHUB_EVENT_NAME`, `PR_BODY_FILE`) so plan gate cannot be skipped.
- [ ] `security/auth/data-migration` checks are blocking in both tracks when scope/labels match, unless valid ADR exception exists.
- [ ] Feedback-to-hardening loop is codified with doc-gardening cadence.
- [ ] Cross-module PR gate fails on missing/non-existent/invalid-status plan links.
- [ ] Agent runtime surface is script-based for repro/validate/regression/pre-release and observability checks.
- [ ] Project-level navigation files run harness scripts from repo root with `HARNESS_TARGET_SCOPE=<project-path>`.
- [ ] Autonomy levels (L1-L4) include promotion requirements, rollback and audit policy.
- [ ] Legacy docs are compatibility aliases only (no duplicated governance facts).
- [ ] Legacy root scripts are wrappers only and call `scripts/harness/*`.
- [ ] Generated sections are marker-based and idempotent.
- [ ] Running harness-init twice produces no duplicate blocks.
- [ ] `<...>` placeholders fail validation.
- [ ] TODO placeholders warn unless allowed by unknown-stack ADR.
- [ ] Preflight matrix is recorded in dry-run and init report.
- [ ] `not-run` validations are explicit and never counted as pass.
- [ ] Dry-run plan shows all intended changes.
- [ ] Init report records mode, detected roots, created files, updated files, and warnings.
- [ ] Repair mode can detect and suggest fixes for polluted root navigation files (`AGENTS.md` or `CLAUDE.md`).
- [ ] Contract version is recorded in generated sections.

## Autonomy Rollout Policy

建议在初始化阶段就声明自治等级与放权边界：
- L1：agent 只改代码（人审 + 人合）
- L2：agent 改代码 + 自检 + 回评审意见
- L3：agent 端到端提 PR 并修复 CI
- L4：低风险变更自动合并（硬约束兜底）

每个等级必须附带：
- 回滚策略（触发条件、执行路径、责任人）
- 审计策略（日志、变更记录、审批轨迹）

升级必须满足最小门槛：
- `previous_level_stable_days >= 14`
- `rollback_strategy_exists == true`
- `audit_trail_complete == true`
- `enforced_ci_green_rate >= 95%`
- `critical_incidents == 0`
- `owner_approval == true`

### Step 9: Init Report

**Tools**: `Read + Edit/Patch + Write`（仅新文件使用 Write）

读取 `references/report-templates.md`，初始化完成后输出变更报告：

- `single-project` / `nested-project`：`docs/harness-init-report.md`
- `multi-project`：`docs/harness/init-report.md`

报告必须包含：
- Mode
- Detected Projects（Path/Type/Reason）
- Created Files
- Updated Files
- Skipped Files
- Runtime Capability Matrix（git/bash/pwsh/node/python/rg 等）
- Compatibility Mapping Applied
- Strong Gate Results
- Validation Not Run（command / reason / residual risk）
- Warnings
- Next Step（Use `harness-engineering` for implementation work）

## Repair Mode

Use repair mode when the repository already has harness files.

Repair mode should:
- detect duplicated harness-init blocks
- detect project-specific content in root navigation file
- move local content to nearest project AGENTS.md/CLAUDE.md
- restore missing handoff sections
- update old marker versions
- regenerate missing canonical docs
- convert legacy docs to compatibility alias
- convert legacy root scripts to wrappers (`scripts/* -> scripts/harness/*`)
- detect duplicate fact sources and wrapper drift
- preserve user-authored content

执行时读取 `references/repair-mode.md`，并在输出中附带污染项迁移建议：

- Found possible pollution in root navigation file: `<pattern>`
- Suggested target: `<nearest-project>/AGENTS.md` or `<nearest-project>/CLAUDE.md`

---

## Handoff to harness-engineering

初始化完成后，仓库必须包含足够上下文供 `harness-engineering` 直接使用，无需重新发现。

**Handoff contract**:

### Single-project

- `AGENTS.md` or `CLAUDE.md`
- `docs/architecture-boundaries.md`
- `docs/constraints.md`
- `docs/testing.md`
- `docs/ci-governance.md`
- `docs/agent-autonomy.md`
- `docs/observability.md`
- `docs/feedback-loops.md`
- `docs/entropy-gc.md`
- `docs/exec-plans/`

### Multi-project

Root-level facts:
- root `AGENTS.md` or `CLAUDE.md`
- `docs/architecture-boundaries.md`
- `docs/ci-governance.md`
- `docs/agent-autonomy.md`
- `docs/observability.md`
- `docs/feedback-loops.md`
- `docs/entropy-gc.md`
- `docs/exec-plans/`
- `docs/decisions/`

Project-level facts:
- `<project>/AGENTS.md` or `<project>/CLAUDE.md`
- `<project>/docs/architecture-boundaries.md`
- `<project>/docs/constraints.md`
- `<project>/docs/testing.md`
- `<project>/docs/observability.md`
- `<project>/docs/feedback-loops.md`
- `<project>/docs/entropy-gc.md`
- `<project>/docs/exec-plans/`

**职责边界**:
- `harness-init`: 建立项目首次的导航、文档骨架、门禁配置。只做一次。
- `harness-engineering`: 后续所有实现、重构、调试、review、feature delivery，以上述文件为项目事实源。

当 agent 从初始化模式切换到工程模式时:
1. 先读取根导航文件（`AGENTS.md`/`CLAUDE.md`），再定位最近项目级导航文件
2. 使用 `harness-engineering` skill 执行具体工程任务（优先遵循最近作用域规则）
3. 每次变更后，如果失败模式重复，回写到 harness docs（遵循 feedback-loops.md）

---

## Execution Notes

- 优先小步落地：先创建文档和门禁骨架，再逐步补强自动化。
- 如果仓库当前没有测试框架，不要伪造通过；明确记录"测试 harness 待建立"。
- 如果同时维护 AGENTS.md 与 CLAUDE.md，默认保持语义等价（strict parity）；仅在用户明确要求时使用指针模式。
- 如果用户只要求"设计 harness" → 停止在模板和计划；如果要求"初始化 harness" → 直接创建文件。
- 对于 **Go、Rust、Java、Kotlin** 等非 Node/Python 栈，加载 `references/tooling-templates.md` 中对应章节；如果是极罕见技术栈（如 Zig、Nim），仅创建文档骨架和导航文件，在 Commands 区块标注"待补充"。
- Monorepo 项目：根导航文件只做全局索引；每个项目根必须有项目级导航文件（`AGENTS.md` 或 `CLAUDE.md`）承载本地命令、约束和验证。
- docs 分层：根 docs 仅仓库级事实；项目 docs 仅项目级事实，避免相互污染。
- 幂等性：重复运行 harness-init 不产生重复内容。使用带版本 marker 的区块（如 `<!-- harness-init:start root-nav version=2 -->` / `<!-- harness-init:end root-nav version=2 -->`、`<!-- harness-init:start project-nav <path> version=2 -->` / `<!-- harness-init:end project-nav <path> version=2 -->`）做局部替换。
- 工具抽象：以下提到的任务跟踪、`Read`、`Write`、`Bash`、`Edit` 等为抽象操作描述，对应当前 agent 运行时中可用的等效工具。如果当前环境没有同名工具，使用功能等效的替代。
- Shell 兼容：若目标仓库主要运行在 Windows 且 `bash` 不可用，允许生成 `.ps1` 等效脚本或同名 wrapper，并在导航/报告中同时记录 POSIX 与 PowerShell 调用方式。
SKILL.md 1169 行，远超 skill 入口应保持精简的形态；再加上 harness-init-v4-claude-requirements.md 和 .kiro/specs 这类过程文档留在 skill 包内，会增加执行时噪音。
