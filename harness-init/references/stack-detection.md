# Stack Detection & Command Mapping

加载时机：**Step 1 盘点现状时**读取本文件。

---

## Project Boundary Detection

在创建或修改导航文件（`AGENTS.md` 或 `CLAUDE.md`）前，先检测项目边界，判定当前仓库是单项目、多项目，还是嵌套子项目。

### Strong root signals

- `package.json`
- `go.mod`
- `pyproject.toml`
- `Cargo.toml`
- `pom.xml`
- `build.gradle`
- `build.gradle.kts`
- `composer.json`
- `.csproj`

### Weak root signals

- `Makefile`
- `Dockerfile`
- `docker-compose.yml`

### Monorepo signals

- `pnpm-workspace.yaml`
- `turbo.json`
- `nx.json`
- `lerna.json`
- `rush.json`
- `workspace.json`
- 根 `package.json` 包含 `workspaces`
- 存在目录：`apps/*`、`packages/*`、`services/*`、`frontend/`、`backend/`、`libs/*`、`modules/*`

### Scope and Ignore

- `HARNESS_TARGET_SCOPE=<path>`：只初始化指定作用域（例如 `apps/editor`）。
- `.harnessignore`：忽略不应扫描或初始化的目录（如 `examples/`、`fixtures/`）。
- 内置忽略目录建议至少包含：
  - `node_modules/`、`dist/`、`build/`
  - `.git/`、`.agents/`、`.claude/`、`.qoder/`、`.workflow/`
  - `.idea/`、`.vscode/`、`.turbo/`、`.yarn/`
- 盘点输出必须避免遍历镜像文档目录和大体量缓存目录，防止超时与误判。

### Detection script (boundary first)

```bash
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

  # pnpm / lerna / package.json(workspaces) 常见声明形态
  if [ -f "pnpm-workspace.yaml" ] && grep -Eq "^[[:space:]]*-[[:space:]]*[\"']?($dir|$wildcard)[\"']?[[:space:]]*$" pnpm-workspace.yaml; then
    return 0
  fi
  if [ -f "lerna.json" ] && grep -Eq "\"($dir|$wildcard)\"" lerna.json; then
    return 0
  fi
  if [ -f "package.json" ] && grep -Eq "\"($dir|$wildcard)\"" package.json; then
    return 0
  fi

  # 其他 workspace 配置文件：使用路径显式声明作为近似判定
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
  # 可选：调用方可通过 HARNESS_TARGET_SCOPE 显式指定要初始化的作用域
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
  if has_strong_root_signal "."; then echo "."; fi
  # 仅扫描浅层，避免把 vendor/node_modules 当作项目根
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
```

### Rule

- 检测到多个 project roots 时，必须视为 **multi-project repository**。
- multi-project 模式下，根导航文件只能放全局规则和索引，不得放项目级命令。
- 若当前执行目录是子项目且可独立识别为 root signal，应视为 **nested project**（局部初始化优先）。
- workspace 目录（`apps/*`、`packages/*` 等）先作为 candidate；仅在满足 strong signal / source dirs / workspace 显式声明 / 用户显式指定时才升级为 project root。
- Weak signal 单独出现时，不得直接创建项目级导航文件，除非满足：
  - 目录属于 `apps/*`、`packages/*`、`services/*`、`frontend/`、`backend/`、`libs/*`、`modules/*`
  - 或目录同时存在 `src/`、`cmd/`、`internal/`、`app/` 等源码目录
  - 或被 workspace 配置显式声明
  - 或用户显式指定该作用域

---

## 项目类型识别逻辑

按以下优先级检测（先检测到的优先）：

```bash
# 自动识别脚本
detect_stack() {
  # Monorepo 检测（先于单栈）
  if [ -f "pnpm-workspace.yaml" ] || [ -f "lerna.json" ] || \
     ([ -f "package.json" ] && python3 -c "import json; d=json.load(open('package.json')); exit(0 if 'workspaces' in d else 1)" 2>/dev/null) || \
     [ -f "nx.json" ] || [ -f "turbo.json" ]; then
    echo "monorepo-node"
    return
  fi
  if [ -f "go.work" ]; then echo "monorepo-go"; return; fi
  if [ -f "Cargo.toml" ] && grep -q "\[workspace\]" Cargo.toml 2>/dev/null; then echo "monorepo-rust"; return; fi

  # 单栈检测
  [ -f "go.mod" ]           && echo "go"     && return
  [ -f "Cargo.toml" ]       && echo "rust"   && return
  [ -f "pom.xml" ]          && echo "java-maven" && return
  [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] && echo "java-gradle" && return
  [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ] && echo "python" && return
  [ -f "package.json" ]     && echo "node"   && return
  [ -f "Gemfile" ]          && echo "ruby"   && return
  [ -f "mix.exs" ]          && echo "elixir" && return

  echo "unknown"
}

detect_stack
```

---

## 各技术栈命令映射表

### Node / TypeScript

| 命令类型 | 检测方式 | 默认命令 |
|----------|----------|----------|
| Install | `package.json` 存在 | `npm install` / `pnpm install` / `yarn` |
| Dev | `scripts.dev` in package.json | `npm run dev` |
| Lint | eslint / biome / oxlint | `npm run lint` |
| Format | prettier / biome | `npm run format` |
| Type-check | typescript | `npx tsc --noEmit` |
| Test | vitest / jest / mocha | `npm test` |
| Build | scripts.build | `npm run build` |
| Outdated | - | `npm outdated` |
| Circular | madge | `npx madge --circular src/` |

```bash
# 检测 Node 包管理器
detect_node_pm() {
  [ -f "pnpm-lock.yaml" ] && echo "pnpm" && return
  [ -f "yarn.lock" ]      && echo "yarn" && return
  echo "npm"
}
```

---

### Python

| 命令类型 | 工具 | 命令 |
|----------|------|------|
| Install | pip / poetry / uv | `pip install -e ".[dev]"` / `poetry install` / `uv sync` |
| Lint | ruff / flake8 | `ruff check .` |
| Format | ruff / black | `ruff format .` |
| Type-check | mypy / pyright | `mypy src/` |
| Test | pytest | `pytest tests/ -x --tb=short` |
| Outdated | pip | `pip list --outdated` |

```bash
# 检测 Python 工具链
detect_python_pm() {
  [ -f "pyproject.toml" ] && grep -q "tool.poetry" pyproject.toml 2>/dev/null && echo "poetry" && return
  [ -f "uv.lock" ] && echo "uv" && return
  echo "pip"
}
detect_python_linter() {
  grep -r "ruff" pyproject.toml setup.cfg .flake8 2>/dev/null | head -1 | grep -q "ruff" && echo "ruff" && return
  [ -f ".flake8" ] && echo "flake8" && return
  echo "ruff"  # default recommended
}
```

---

### Go

| 命令类型 | 命令 |
|----------|------|
| Install | `go mod download` |
| Dev | `go run ./cmd/...` （或查 Makefile） |
| Lint | `golangci-lint run ./...` |
| Format | `gofmt -l .` / `goimports -l .` |
| Type-check | `go vet ./...` |
| Test | `go test ./... -race -timeout 120s` |
| Build | `go build ./...` |
| Outdated | `go list -u -m all` |
| Circular | `go list -f '{{.ImportPath}}: {{.Imports}}' ./...` |

```bash
# 检测 Go 版本和模块名
go_module_name() { head -1 go.mod | awk '{print $2}'; }
go_version()     { grep "^go " go.mod | awk '{print $2}'; }
```

---

### Rust

| 命令类型 | 命令 |
|----------|------|
| Install | `cargo fetch` |
| Dev | `cargo run` |
| Lint | `cargo clippy -- -D warnings` |
| Format | `cargo fmt --check` |
| Type-check | `cargo check` |
| Test | `cargo test` |
| Build | `cargo build --release` |
| Outdated | `cargo outdated` （需安装 cargo-outdated） |
| Audit | `cargo audit` （需安装 cargo-audit） |

```bash
# 检测 Rust workspace vs 单包
rust_is_workspace() { grep -q "\[workspace\]" Cargo.toml 2>/dev/null && echo "true" || echo "false"; }
rust_edition()      { grep "^edition" Cargo.toml | head -1 | grep -oE '"[0-9]+"' | tr -d '"'; }
```

---

### Java (Maven)

| 命令类型 | 命令 |
|----------|------|
| Install | `mvn dependency:resolve` |
| Compile | `mvn compile` |
| Lint | `mvn checkstyle:check` |
| Format | `mvn fmt:check` （google-java-format） |
| Type-check | `mvn compile -DskipTests` |
| Test | `mvn test` |
| Build | `mvn package -DskipTests` |
| Outdated | `mvn versions:display-dependency-updates` |

---

### Java / Kotlin (Gradle)

| 命令类型 | 命令 |
|----------|------|
| Install | `./gradlew dependencies` |
| Compile | `./gradlew compileJava` / `compileKotlin` |
| Lint | `./gradlew checkstyleMain` / `./gradlew detekt` |
| Format | `./gradlew spotlessCheck` |
| Type-check | `./gradlew compileKotlin` |
| Test | `./gradlew test` |
| Build | `./gradlew build -x test` |
| Outdated | `./gradlew dependencyUpdates` |

```bash
# 检测 Gradle wrapper
gradle_cmd() { [ -f "./gradlew" ] && echo "./gradlew" || echo "gradle"; }
# 检测是否有 Kotlin
has_kotlin() { find . -name "*.kt" -not -path "*/build/*" | head -1 | grep -q ".kt" && echo "true" || echo "false"; }
```

---

### Monorepo 特殊处理

```bash
# 检测 monorepo 结构
list_monorepo_packages() {
  # Node workspaces
  if [ -f "pnpm-workspace.yaml" ]; then
    grep -E "^\s*-" pnpm-workspace.yaml | sed "s/.*- //"
  elif [ -f "nx.json" ]; then
    ls -d apps/* packages/* 2>/dev/null | head -20
  fi
  # Go workspaces
  if [ -f "go.work" ]; then grep "^use" go.work | awk '{print $2}'; fi
  # Rust workspaces
  if grep -q "\[workspace\]" Cargo.toml 2>/dev/null; then
    grep "members" Cargo.toml | grep -oE '"[^"]+"' | tr -d '"'
  fi
}
```

Monorepo harness 策略：
- 根目录创建索引型导航文件（`AGENTS.md` 或 `CLAUDE.md`，只含全局规则、仓库布局、项目索引、共享约束）
- 子项目根目录创建项目级导航文件（`AGENTS.md` 或 `CLAUDE.md`，承载命令、局部约束、局部 docs、局部验证）
- `docs/` 分层：根 docs 只放仓库级事实；项目 docs 放在各项目目录（如 `apps/<name>/docs/`）
- 始终遵循 “nearest navigation file (`AGENTS.md` or `CLAUDE.md`) wins” 规则

---

## 未知技术栈降级策略

如果 `detect_stack` 返回 `unknown`，执行降级策略：

1. 不阻塞初始化，继续创建 generic harness
2. 在创建的导航文件 Commands 区块中，填写：
   ```
   ## Commands
   - Install: TODO: 待补充
   - Dev: TODO: 待补充
   - Lint: TODO: 待补充
   - Test: TODO: 待补充
   ```
3. 仍然完整创建 docs/ 骨架和所有文档模板
4. 跳过 tooling-templates 中的具体工具配置，在 `.harness/docs/constraints.md` 中标注“门禁配置待建立”
5. 在 `.harness/docs/decisions/ADR-0001-harness-init.md` 记录“未知技术栈，待补充命令映射”
