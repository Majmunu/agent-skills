# Structure Tests & Architecture Enforcement

加载时机：**Step 5 添加结构测试时**读取本文件。

---

## Node / TypeScript

### 方案一：madge（循环依赖检测，推荐最小方案）

```bash
# 安装
npm install -g madge

# 检测循环依赖
npx madge --circular src/

# 生成依赖图（可视化）
npx madge --image deps.svg src/
```

在 `package.json` 中添加：
```json
{
  "scripts": {
    "arch:check": "madge --circular src/ && echo 'No circular deps'"
  }
}
```

### 方案二：ESLint import 路径限制（层级依赖）

```js
// eslint.config.js 中添加
{
  rules: {
    'no-restricted-imports': ['error', {
      patterns: [
        {
          group: ['*/service/*'],
          importNames: [],
          message: 'Service layer must not be imported directly from UI layer. Use the public API.'
        }
      ]
    }]
  }
}
```

### 方案三：dependency-cruiser（完整结构测试）

```bash
npm install -D dependency-cruiser
npx depcruise --init   # 生成 .dependency-cruiser.js
```

`.dependency-cruiser.js` 规则示例：
```js
module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      comment: 'Circular dependencies are forbidden',
      from: {},
      to: { circular: true }
    },
    {
      name: 'service-no-ui',
      severity: 'error',
      comment: 'Service must not import UI',
      from: { path: '^src/service/' },
      to: { path: '^src/ui/' }
    }
  ],
  options: {
    doNotFollow: { path: 'node_modules' }
  }
};
```

---

## Python

### 方案一：pytest + importlib（内置，零依赖）

```python
# tests/test_structure.py
"""Structure tests: enforce architecture constraints."""
import ast
import os
from pathlib import Path
import pytest


def get_imports(filepath: Path) -> list[str]:
    """Extract all imports from a Python file."""
    with open(filepath) as f:
        tree = ast.parse(f.read())
    imports = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                imports.append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                imports.append(node.module)
    return imports


def find_python_files(directory: str) -> list[Path]:
    return list(Path(directory).rglob("*.py"))


class TestServiceLayer:
    def test_service_no_ui_imports(self):
        """Service layer must not import UI modules."""
        service_files = find_python_files("src/service")
        violations = []
        for f in service_files:
            for imp in get_imports(f):
                if imp.startswith("src.ui") or imp.startswith("ui."):
                    violations.append(f"{f}: imports {imp}")
        assert not violations, f"Service layer UI import violations:\n" + "\n".join(violations)

    def test_service_no_handler_imports(self):
        """Service layer must not import handler/router modules."""
        service_files = find_python_files("src/service")
        violations = []
        for f in service_files:
            for imp in get_imports(f):
                if imp.startswith("src.handler") or imp.startswith("src.router"):
                    violations.append(f"{f}: imports {imp}")
        assert not violations, f"Service layer handler import violations:\n" + "\n".join(violations)


class TestRepoLayer:
    def test_repo_no_service_imports(self):
        """Repo layer must not import service modules."""
        repo_files = find_python_files("src/repo")
        violations = []
        for f in repo_files:
            for imp in get_imports(f):
                if imp.startswith("src.service"):
                    violations.append(f"{f}: imports {imp}")
        assert not violations, f"Repo layer service import violations:\n" + "\n".join(violations)
```

### 方案二：pylint import-only-modules 插件（CI 级别）

```toml
# pyproject.toml
[tool.pylint.MASTER]
load-plugins = ["pylint.extensions.import_order"]
```

---

## Go

### 方案一：go build 自带循环检测（零依赖，首选）

```bash
# Go 编译器原生拒绝循环导入。注意：不能简单用 pipe + grep，因为 go build 成功时
# exit 0 但无输出，grep 找不到 "import cycle" 会返回 1 导致误判。正确写法：
output=$(go build ./... 2>&1)
status=$?
if [ $status -ne 0 ]; then
  if echo "$output" | grep -qi "import cycle"; then
    echo "FAIL: import cycle detected"
  else
    echo "FAIL: go build failed: $output"
  fi
  exit 1
fi
echo "OK: no import cycles"
```

### 方案二：govulncheck + 自定义脚本

```bash
# scripts/arch-check.sh
#!/bin/bash

echo "=== Checking import cycles ==="
output=$(go build ./... 2>&1)
status=$?
if [ $status -ne 0 ]; then
  if echo "$output" | grep -qi "import cycle"; then
    echo "FAIL: import cycles detected"
    exit 1
  else
    echo "FAIL: go build failed: $output"
    exit 1
  fi
fi
echo "OK: no import cycles"

echo "=== Checking forbidden cross-layer imports ==="
# Service层不应直接依赖 handler 层
VIOLATIONS=$(grep -rn '"<module>/internal/handler"' internal/service/ 2>/dev/null || true)
if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: service layer imports handler layer:"
  echo "$VIOLATIONS"
  exit 1
fi
echo "OK"

echo "=== All architecture checks passed ==="
```

### 方案三：go-cleanarch（专用工具）

```bash
go install github.com/roblaszczak/go-cleanarch@latest
go-cleanarch -application app -domain domain -infrastructure infrastructure -interfaces interfaces
```

---

## Rust

### 方案一：cargo build 自带循环检测（零依赖）

```bash
# Rust 编译器原生检测循环依赖。同理不能用 pipe + grep：
output=$(cargo check 2>&1)
status=$?
if [ $status -ne 0 ]; then
  if echo "$output" | grep -qi "cycle"; then
    echo "FAIL: dependency cycle detected"
  else
    echo "FAIL: cargo check failed: $output"
  fi
  exit 1
fi
echo "OK: no cycles"
```

### 方案二：cargo-modules（可视化模块树）

```bash
cargo install cargo-modules
cargo modules dependencies --package <your-crate>
```

### 方案三：自定义结构测试（`tests/architecture.rs`）

```rust
// tests/architecture.rs
// Verify module boundaries via compile-time checks

#[test]
fn domain_does_not_depend_on_infrastructure() {
    // This is enforced by Rust's module system when using pub(crate) visibility.
    // Add specific integration tests here if needed.
    // Example: ensure no tokio runtime is initialized in pure domain code.
}
```

---

## Java / Kotlin

### 方案一：ArchUnit（推荐，功能最强）

```xml
<!-- Maven: pom.xml -->
<dependency>
  <groupId>com.tngtech.archunit</groupId>
  <artifactId>archunit-junit5</artifactId>
  <version>1.3.0</version>
  <scope>test</scope>
</dependency>
```

```kotlin
// Gradle: build.gradle.kts
testImplementation("com.tngtech.archunit:archunit-junit5:1.3.0")
```

```java
// src/test/java/ArchitectureTest.java
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.Architectures;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

@AnalyzeClasses(packages = "com.example")
public class ArchitectureTest {

    @ArchTest
    static final ArchRule layered_architecture =
        Architectures.layeredArchitecture()
            .consideringAllDependencies()
            .layer("Domain").definedBy("..domain..")
            .layer("Application").definedBy("..application..")
            .layer("Infrastructure").definedBy("..infrastructure..")
            .layer("Presentation").definedBy("..presentation..")
            .whereLayer("Domain").mayNotAccessAnyLayer()
            .whereLayer("Application").mayOnlyAccessLayers("Domain")
            .whereLayer("Infrastructure").mayOnlyAccessLayers("Application", "Domain")
            .whereLayer("Presentation").mayOnlyAccessLayers("Application", "Domain");

    @ArchTest
    static final ArchRule no_cycles =
        com.tngtech.archunit.library.dependencies.SlicesRuleDefinition
            .slices().matching("com.example.(*)..").should().beFreeOfCycles();

    @ArchTest
    static final ArchRule domain_no_spring =
        noClasses().that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("org.springframework..")
            .as("Domain layer must not depend on Spring Framework");
}
```

---

## 结构测试集成到 CI

各技术栈都应将结构测试命令加入 CI pipeline（参考 `tooling-templates.md` 中对应 Makefile/scripts）：

```yaml
# .github/workflows/arch-check.yml
name: Architecture Check
on: [push, pull_request]

jobs:
  arch-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run architecture checks
        run: make arch-check   # 或各栈对应命令
```

---

## Root Navigation 污染检测（多项目仓库）

用于检测根导航文件（`AGENTS.md` 或 `CLAUDE.md`）是否混入了项目级命令或局部环境变量。建议把该脚本接入 `arch-check` 或独立 CI job。
推荐落地路径：`scripts/check-agents-scope.sh`。

规则：
- Root navigation file may contain repo-wide commands only if they are explicitly marked as shared commands.
- Project-local commands must be moved to project-level navigation files (`AGENTS.md` or `CLAUDE.md`).
- 允许通过 `.harness/agents-root-allowlist.txt` 对少量已确认的 repo-wide 模式做白名单豁免。

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Checking root navigation scope pollution..."

ROOT_FILES=()
[ -f "AGENTS.md" ] && ROOT_FILES+=("AGENTS.md")
[ -f "CLAUDE.md" ] && ROOT_FILES+=("CLAUDE.md")
ALLOWLIST_FILE=".harness/agents-root-allowlist.txt"

if [ "${#ROOT_FILES[@]}" -eq 0 ]; then
  echo "OK: no root AGENTS.md/CLAUDE.md"
  exit 0
fi

is_allowed() {
  local key="$1"
  [ -f "$ALLOWLIST_FILE" ] && grep -Fx "$key" "$ALLOWLIST_FILE" >/dev/null 2>&1
}

is_line_in_shared_commands() {
  local root_file="$1"
  local line_no="$2"
  awk -v target="$line_no" '
    BEGIN { in_shared=0; found=0 }
    /^## /{
      if ($0 ~ /^## Shared Commands/) {in_shared=1; next}
      if (in_shared) {in_shared=0}
    }
    {
      if (NR == target) {
        found=1
        if (in_shared) exit 0
        exit 1
      }
    }
    END {
      if (found == 0) exit 1
    }
  ' "$root_file"
}

suggest_target() {
  local pattern="$1"
  local line_text="$2"
  local preferred_nav_file="$3"

  if echo "$line_text" | grep -Eq "cd[[:space:]]+apps/[^[:space:]]+"; then
    local p
    p=$(echo "$line_text" | sed -nE 's/.*cd[[:space:]]+(apps\/[^[:space:]]+).*/\1/p' | head -1)
    [ -n "$p" ] && { echo "$p/$preferred_nav_file"; return; }
  fi
  if echo "$line_text" | grep -Eq "cd[[:space:]]+packages/[^[:space:]]+"; then
    local p
    p=$(echo "$line_text" | sed -nE 's/.*cd[[:space:]]+(packages\/[^[:space:]]+).*/\1/p' | head -1)
    [ -n "$p" ] && { echo "$p/$preferred_nav_file"; return; }
  fi
  if echo "$line_text" | grep -Eq "cd[[:space:]]+services/[^[:space:]]+"; then
    local p
    p=$(echo "$line_text" | sed -nE 's/.*cd[[:space:]]+(services\/[^[:space:]]+).*/\1/p' | head -1)
    [ -n "$p" ] && { echo "$p/$preferred_nav_file"; return; }
  fi
  if echo "$line_text" | grep -Eq "cd[[:space:]]+frontend"; then echo "frontend/$preferred_nav_file"; return; fi
  if echo "$line_text" | grep -Eq "cd[[:space:]]+backend"; then echo "backend/$preferred_nav_file"; return; fi

  case "$pattern" in
    DATABASE_URL|MONGO_URI|REDIS_URL|POSTGRES_URL|MYSQL_URL|API_BASE_URL)
      if [ -d "services/api" ]; then
        echo "services/api/$preferred_nav_file"
      else
        echo "<nearest-service>/$preferred_nav_file"
      fi
      return
      ;;
    VITE_|NEXT_PUBLIC_)
      if [ -d "apps/web" ]; then
        echo "apps/web/$preferred_nav_file"
      elif [ -d "frontend" ]; then
        echo "frontend/$preferred_nav_file"
      else
        echo "<nearest-frontend>/$preferred_nav_file"
      fi
      return
      ;;
  esac

  echo "<nearest-project>/$preferred_nav_file"
}

HARD_FORBIDDEN_PATTERNS=(
  "cd apps/"
  "cd packages/"
  "cd services/"
  "cd frontend/"
  "cd backend/"
  "DATABASE_URL"
  "MONGO_URI"
  "REDIS_URL"
  "POSTGRES_URL"
  "MYSQL_URL"
  "API_BASE_URL"
  "VITE_"
  "NEXT_PUBLIC_"
)

CONTEXTUAL_PATTERNS=(
  "npm run dev"
  "pnpm dev"
  "yarn dev"
  "go run"
  "cargo run"
  "docker compose up"
  "pnpm --filter"
  "yarn workspace"
  "npm --workspace"
  "turbo dev"
  "turbo run dev"
  "nx serve"
)

failed=0
warn=0

for ROOT_FILE in "${ROOT_FILES[@]}"; do
  PREFERRED_NAV_FILE="$(basename "$ROOT_FILE")"
  echo "Inspecting $ROOT_FILE ..."

  for pattern in "${HARD_FORBIDDEN_PATTERNS[@]}"; do
    while IFS= read -r match; do
      [ -z "$match" ] && continue
      line_no="${match%%:*}"
      line_text="${match#*:}"
      if is_allowed "$pattern" || is_allowed "$pattern@$line_no"; then
        echo "ALLOWLISTED: $pattern (line $line_no)"
        continue
      fi
      echo "WARNING: hard pollution pattern in root $ROOT_FILE: $pattern (line $line_no)"
      echo "  -> $line_text"
      echo "  Suggested target: $(suggest_target "$pattern" "$line_text" "$PREFERRED_NAV_FILE")"
      failed=1
    done < <(grep -n "$pattern" "$ROOT_FILE" 2>/dev/null || true)
  done

  for pattern in "${CONTEXTUAL_PATTERNS[@]}"; do
    while IFS= read -r match; do
      [ -z "$match" ] && continue
      line_no="${match%%:*}"
      line_text="${match#*:}"
      if is_allowed "$pattern" || is_allowed "$pattern@$line_no"; then
        echo "ALLOWLISTED: $pattern (line $line_no)"
        continue
      fi
      if is_line_in_shared_commands "$ROOT_FILE" "$line_no"; then
        echo "WARNING(shared): contextual command appears in root Shared Commands of $ROOT_FILE: $pattern (line $line_no)"
        echo "  -> Ensure this command is truly repo-wide or add explicit allowlist."
        warn=1
        continue
      fi
      echo "WARNING: possible project-specific command in root $ROOT_FILE: $pattern (line $line_no)"
      echo "  -> $line_text"
      echo "  Suggested target: $(suggest_target "$pattern" "$line_text" "$PREFERRED_NAV_FILE")"
      failed=1
    done < <(grep -n "$pattern" "$ROOT_FILE" 2>/dev/null || true)
  done
done

if [ "$failed" -eq 1 ]; then
  echo "Root navigation file may be polluted. Move project-specific rules to the nearest project navigation file (AGENTS.md/CLAUDE.md)."
  echo "If a pattern is intentionally repo-wide, add it to $ALLOWLIST_FILE (one pattern per line; optional pattern@line)."
  exit 1
fi

if [ "$warn" -eq 1 ]; then
  echo "Root navigation files passed with warnings. Review shared commands and allowlist intentionally repo-wide entries."
  exit 0
fi

echo "OK: root navigation files appear clean"
```

---

## Cross-module Plan Required Check（PR 门禁）

用于强制执行：跨模块 PR 改动必须关联可验证的计划文件（root 或 project-scoped `.harness/docs/exec-plans/*`，非 PR 事件自动跳过）。

canonical 脚本：`.harness/scripts/check-plan-required.sh`

建议配置文件：`.harness/plan-required-rules.yml`
- 可选字段：`allowed_plan_statuses`（默认 `active, completed`；用于 PR gate 合法状态）

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${BASE_REF:-origin/main}"
HEAD_REF="${HEAD_REF:-HEAD}"
PR_BODY_FILE="${PR_BODY_FILE:-.harness/pr-body.txt}"
EVENT_NAME="${GITHUB_EVENT_NAME:-}"
PLAN_RULES_FILE="${PLAN_RULES_FILE:-.harness/plan-required-rules.yml}"
PR_LABELS="${PR_LABELS:-}"

changed_files="$(git diff --name-only "$BASE_REF...$HEAD_REF" || true)"

if [ -z "$changed_files" ]; then
  echo "OK: no changes detected"
  exit 0
fi

if [ "$EVENT_NAME" != "pull_request" ] && [ "$EVENT_NAME" != "pull_request_target" ]; then
  echo "OK: non-PR event (${EVENT_NAME:-unknown}), skip plan gate"
  exit 0
fi

read_rule_value() {
  local key="$1"
  local default_value="$2"
  if [ ! -f "$PLAN_RULES_FILE" ]; then
    echo "$default_value"
    return
  fi
  local value
  value="$(awk -F: -v k="$key" '
    $0 ~ "^[[:space:]]*"k"[[:space:]]*:" {
      sub(/^[^:]*:[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      gsub(/^["'"'"']|["'"'"']$/, "", $0)
      print tolower($0)
      exit
    }' "$PLAN_RULES_FILE")"
  if [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default_value"
  fi
}

read_bool_rule() {
  local value
  value="$(read_rule_value "$1" "$2")"
  case "$value" in
    true|false) echo "$value" ;;
    *) echo "$2" ;;
  esac
}

read_int_rule() {
  local value
  value="$(read_rule_value "$1" "$2")"
  if echo "$value" | grep -Eq '^[0-9]+$'; then
    echo "$value"
  else
    echo "$2"
  fi
}

read_labels_regex() {
  local default_regex='security|auth|migration|public-api|rollback-required'
  if [ ! -f "$PLAN_RULES_FILE" ]; then
    echo "$default_regex"
    return
  fi
  local labels
  labels="$(awk '
    /^[[:space:]]*labels:[[:space:]]*$/ { in_labels=1; next }
    in_labels && /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+/, "", $0)
      print tolower($0)
      next
    }
    in_labels && /^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*/ { in_labels=0 }
  ' "$PLAN_RULES_FILE" | paste -sd'|' -)"
  if [ -n "$labels" ]; then
    echo "$labels"
  else
    echo "$default_regex"
  fi
}

read_allowed_statuses_regex() {
  local default_regex='active|completed'
  if [ ! -f "$PLAN_RULES_FILE" ]; then
    echo "$default_regex"
    return
  fi
  local statuses
  statuses="$(awk '
    /^[[:space:]]*allowed_plan_statuses:[[:space:]]*$/ { in_statuses=1; next }
    in_statuses && /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+/, "", $0)
      print tolower($0)
      next
    }
    in_statuses && /^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*/ { in_statuses=0 }
  ' "$PLAN_RULES_FILE" | paste -sd'|' -)"
  if [ -n "$statuses" ]; then
    echo "$statuses"
  else
    echo "$default_regex"
  fi
}

cfg_cross_scope="$(read_bool_rule "cross_scope_change" "true")"
cfg_cross_project="$(read_bool_rule "cross_project_change" "true")"
cfg_db_schema="$(read_bool_rule "db_schema_change" "true")"
cfg_ci_change="$(read_bool_rule "ci_change" "true")"
cfg_boundary="$(read_bool_rule "boundary_config_change" "true")"
cfg_infra="$(read_bool_rule "infra_change" "true")"
cfg_changed_files_gt="$(read_int_rule "changed_files_gt" "5")"
cfg_labels_regex="$(read_labels_regex)"
cfg_allowed_statuses_regex="$(read_allowed_statuses_regex)"

scopes=$(
  echo "$changed_files" \
    | awk -F/ '
      /^apps\/[^/]+\// {print $1"/"$2; next}
      /^packages\/[^/]+\// {print $1"/"$2; next}
      /^services\/[^/]+\// {print $1"/"$2; next}
    ' \
    | sort -u
)
scope_count=$(echo "$scopes" | sed '/^$/d' | wc -l | tr -d ' ')
changed_count=$(echo "$changed_files" | sed '/^$/d' | wc -l | tr -d ' ')
primary_scope="$(echo "$scopes" | sed '/^$/d' | head -n 1 || true)"

requires_plan=0

if [ "$cfg_cross_scope" = "true" ] && [ "$scope_count" -gt 1 ]; then requires_plan=1; fi
if [ "$cfg_cross_project" = "true" ] && [ "$scope_count" -gt 1 ]; then requires_plan=1; fi
if [ "$changed_count" -gt "$cfg_changed_files_gt" ]; then requires_plan=1; fi
if [ "$cfg_db_schema" = "true" ] && echo "$changed_files" | grep -Eq '(^|/)(schema|migrations?)/|\.sql$|\.ddl$'; then requires_plan=1; fi
if [ "$cfg_ci_change" = "true" ] && echo "$changed_files" | grep -Eq '^\.github/workflows/|^\.gitlab-ci\.yml$|^lefthook\.yml$|^\.pre-commit-config\.yaml$'; then requires_plan=1; fi
if [ "$cfg_boundary" = "true" ] && echo "$changed_files" | grep -Eq '(^|/)\.harness/scripts/check-boundaries\.sh$|(^|/)\.harness/docs/architecture-boundaries\.md$|(^|/)\.harness/'; then requires_plan=1; fi
if [ "$cfg_infra" = "true" ] && echo "$changed_files" | grep -Eq '^infra/|^infrastructure/|^deploy/|^k8s/|^helm/|Dockerfile|docker-compose'; then requires_plan=1; fi
if [ -n "$cfg_labels_regex" ] && echo "$PR_LABELS" | grep -Eiq "(${cfg_labels_regex})"; then requires_plan=1; fi

if [ "$requires_plan" -eq 0 ]; then
  echo "OK: plan not required for current change set"
  exit 0
fi

if [ ! -f "$PR_BODY_FILE" ]; then
  echo "ERROR: plan required but PR body file not found: $PR_BODY_FILE"
  exit 1
fi

plan_paths="$(grep -Eo '([[:alnum:]_.-]+/)*\.harness/docs/exec-plans/(active|completed)/[^ )]+' "$PR_BODY_FILE" | sed 's/[`\",]//g' | sort -u || true)"
if [ -z "$plan_paths" ]; then
  echo "ERROR: plan required but no plan path found in PR body"
  exit 1
fi

required_plan_scope="root"
outside_primary_scope=""
if [ "$scope_count" -eq 1 ] && [ -n "$primary_scope" ]; then
  outside_primary_scope="$(echo "$changed_files" | grep -Ev "^${primary_scope}/" | sed '/^$/d' || true)"
fi
if [ "$scope_count" -eq 1 ] && [ -n "$primary_scope" ] && [ -z "$outside_primary_scope" ]; then
  required_plan_scope="project"
fi

matched_path=""
while IFS= read -r plan_path; do
  [ -z "$plan_path" ] && continue
  [ -f "$plan_path" ] || continue
  status_line="$(head -n 60 "$plan_path" | grep -Ei "^Status:[[:space:]]*(${cfg_allowed_statuses_regex})[[:space:]]*$" || true)"
  [ -n "$status_line" ] || continue

  if [ "$required_plan_scope" = "project" ]; then
    case "$plan_path" in
      "$primary_scope"/.harness/docs/exec-plans/active/*|"$primary_scope"/.harness/docs/exec-plans/completed/*)
        matched_path="$plan_path"
        break
        ;;
    esac
  else
    case "$plan_path" in
      .harness/docs/exec-plans/active/*|.harness/docs/exec-plans/completed/*)
        matched_path="$plan_path"
        break
        ;;
    esac
  fi
done <<EOF
$plan_paths
EOF

if [ -z "$matched_path" ]; then
  echo "ERROR: no valid plan path matches required scope (${required_plan_scope})"
  if [ "$required_plan_scope" = "project" ]; then
    echo "Required example: ${primary_scope}/.harness/docs/exec-plans/active/<plan>.md"
  else
    echo "Required example: .harness/docs/exec-plans/active/<plan>.md"
  fi
  exit 1
fi

echo "OK: plan gate passed ($matched_path, scope=${required_plan_scope})"
```

---

## Alias Integrity Check

canonical 脚本：`.harness/scripts/check-alias-integrity.sh`

规则：
- legacy 文档（如 `docs/autonomy-levels.md`）必须是 alias 模板
- 不允许在 legacy 文档中新增治理正文
- 发现 canonical/legacy 双事实源直接失败

---

## Wrapper Integrity Check

fresh init 默认不生成 legacy 根脚本；repair/migration 时若必须短期兼容，wrapper 也只能指向 `.harness/scripts/*`：

```bash
#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../.harness/scripts/check-all.sh" "$@"
```

校验点：
- fresh init must leave no `scripts/check-all.sh` / `scripts/validate.sh` / `scripts/regression.sh`
- temporary wrappers, if explicitly required during migration, must call canonical script in `.harness/scripts/`
- must passthrough arguments
- must preserve exit code
- must not contain implementation logic
