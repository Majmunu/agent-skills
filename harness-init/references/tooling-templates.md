# Tooling Templates

加载时机：**Step 4-5 配置门禁时**读取本文件。根据 Step 1 识别的技术栈，只读取对应章节。

---

## Script Merge & Shell Compatibility

### package.json / Makefile 合并规则（必须幂等）

- 仅补缺失项，不覆盖已有命令。
- 若目标 key 已存在且语义冲突，新增 `:<harness-suffix>` 变体而不是替换原 key。
  - 例如：`arch-check` 已存在冲突时，新增 `arch-check:harness`。
- 所有新增命令都必须在 init report 记录来源与用途。

### Shell 兼容规则

- POSIX 优先：`.harness/scripts/*.sh` 作为 canonical。
- 若运行环境无 `bash` 且目标团队长期使用 Windows：
  - 允许生成 `.ps1` 等效脚本或 wrapper。
  - 导航文档必须同时给出 POSIX 与 PowerShell 调用示例。
- 在 CI 文档中明确 runner 假设（Linux/Windows），避免本地与 CI 行为分裂。

---

## Node / TypeScript

### package.json scripts 最小集

**原则：优先复用已有 scripts；没有才推荐以下模板。**

```json
{
  "scripts": {
    "dev": "<优先使用已有的 dev/start/serve 命令；若无，推荐对应框架命令，如 vite / next dev / nest start / node index.js>",
    "build": "<优先使用已有的 build 命令；若无，推荐对应框架命令>",
    "lint": "eslint . --max-warnings 0",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "type-check": "tsc --noEmit",
    "test": "<优先使用已有的 test 命令；若无，推荐 vitest run / jest / mocha>",
    "test:coverage": "<优先使用已有的 coverage 命令；若无，推荐 vitest run --coverage / jest --coverage>",
    "arch:check": "npx madge --circular src/",
    "health": "<对应框架的健康检查命令>"
  }
}
```

### ESLint 最小配置（`eslint.config.js`）

```js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      'no-console': 'warn',
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unused-vars': 'error',
    },
  },
);
```

### pre-commit 配置（`.pre-commit-config.yaml`）

```yaml
repos:
  - repo: local
    hooks:
      - id: lint
        name: ESLint
        entry: npm run lint
        language: system
        pass_filenames: false
      - id: type-check
        name: TypeScript type-check
        entry: npm run type-check
        language: system
        pass_filenames: false
      - id: test
        name: Unit tests
        entry: npm test
        language: system
        pass_filenames: false
```

---

## Python

### pyproject.toml 最小配置

```toml
[tool.ruff]
line-length = 100
select = ["E", "F", "I", "N", "UP", "B", "SIM"]
ignore = []

[tool.ruff.format]
quote-style = "double"

[tool.mypy]
python_version = "3.11"
strict = true
ignore_missing_imports = true

[tool.pytest.ini_options]
addopts = "--timeout=60 --tb=short -ra"
testpaths = ["tests"]

[tool.coverage.run]
source = ["src"]
omit = ["tests/*", "**/__init__.py"]

[tool.coverage.report]
fail_under = 70
```

### pre-commit 配置（`.pre-commit-config.yaml`）

```yaml
repos:
  - repo: local
    hooks:
      - id: ruff-check
        name: ruff lint
        entry: ruff check .
        language: system
        types: [python]
        pass_filenames: false
      - id: ruff-format
        name: ruff format
        entry: ruff format --check .
        language: system
        types: [python]
        pass_filenames: false
      - id: mypy
        name: mypy type-check
        entry: mypy src/
        language: system
        types: [python]
        pass_filenames: false
      - id: pytest
        name: pytest
        entry: pytest tests/ -x --tb=short
        language: system
        pass_filenames: false
```

---

## Go

### Makefile 最小集

```makefile
.PHONY: install dev lint fmt vet test build arch-check

install:
	go mod download

dev:
	go run ./cmd/...

lint:
	golangci-lint run ./...

fmt:
	gofmt -l -w .
	goimports -l -w .

vet:
	go vet ./...

test:
	go test ./... -race -timeout 120s

test-coverage:
	go test ./... -race -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html

build:
	go build -o bin/ ./...

arch-check:
	@echo "Checking for import cycles..."
	@output=$$(go build ./... 2>&1); status=$$?; \
	if [ $$status -ne 0 ]; then \
	  if echo "$$output" | grep -qi "import cycle"; then \
	    echo "FAIL: import cycle detected"; exit 1; \
	  else \
	    echo "FAIL: go build failed"; echo "$$output"; exit 1; \
	  fi; \
	fi; \
	echo "OK: no import cycles"
	@echo "Checking go vet..."
	go vet ./...

outdated:
	go list -u -m all
```

### .golangci.yml 最小配置

```yaml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - gofmt
    - goimports
    - revive
    - gocritic

linters-settings:
  revive:
    rules:
      - name: exported

issues:
  exclude-rules:
    - path: "_test.go"
      linters:
        - errcheck

run:
  timeout: 5m
```

### pre-commit 配置（`.pre-commit-config.yaml`）

```yaml
repos:
  - repo: local
    hooks:
      - id: go-fmt
        name: go fmt
        entry: gofmt -l .
        language: system
        pass_filenames: false
      - id: go-vet
        name: go vet
        entry: go vet ./...
        language: system
        pass_filenames: false
      - id: golangci-lint
        name: golangci-lint
        entry: golangci-lint run
        language: system
        pass_filenames: false
      - id: go-test
        name: go test
        entry: go test ./... -race -timeout 60s
        language: system
        pass_filenames: false
```

---

## Rust

### Makefile 最小集（或 `justfile`）

```makefile
.PHONY: install check fmt lint test build audit

install:
	cargo fetch

check:
	cargo check

fmt:
	cargo fmt --check

fmt-fix:
	cargo fmt

lint:
	cargo clippy -- -D warnings

test:
	cargo test

test-coverage:
	cargo llvm-cov --html

build:
	cargo build --release

audit:
	cargo audit

outdated:
	cargo outdated
```

### `.cargo/config.toml` 最小配置

```toml
[build]
rustflags = ["-D", "warnings"]
```

### pre-commit 配置（`.pre-commit-config.yaml`）

```yaml
repos:
  - repo: local
    hooks:
      - id: cargo-fmt
        name: cargo fmt
        entry: cargo fmt --check
        language: system
        pass_filenames: false
      - id: cargo-clippy
        name: cargo clippy
        entry: cargo clippy -- -D warnings
        language: system
        pass_filenames: false
      - id: cargo-test
        name: cargo test
        entry: cargo test
        language: system
        pass_filenames: false
```

---

## Java (Maven)

### pom.xml 插件配置（添加到 `<build><plugins>` 中）

```xml
<!-- Checkstyle -->
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-checkstyle-plugin</artifactId>
  <version>3.3.1</version>
  <configuration>
    <configLocation>google_checks.xml</configLocation>
    <failOnViolation>true</failOnViolation>
  </configuration>
</plugin>

<!-- Surefire (tests) -->
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-surefire-plugin</artifactId>
  <version>3.2.5</version>
  <configuration>
    <failIfNoTests>true</failIfNoTests>
  </configuration>
</plugin>

<!-- JaCoCo (coverage) -->
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <version>0.8.11</version>
  <executions>
    <execution>
      <goals><goal>prepare-agent</goal></goals>
    </execution>
    <execution>
      <id>report</id>
      <phase>test</phase>
      <goals><goal>report</goal></goals>
    </execution>
    <execution>
      <id>check</id>
      <goals><goal>check</goal></goals>
      <configuration>
        <rules>
          <rule>
            <limits>
              <limit>
                <counter>LINE</counter>
                <value>COVEREDRATIO</value>
                <minimum>0.70</minimum>
              </limit>
            </limits>
          </rule>
        </rules>
      </configuration>
    </execution>
  </executions>
</plugin>
```

### Makefile 最小集（包装 Maven 命令）

```makefile
.PHONY: install compile lint test build

install:
	mvn dependency:resolve

compile:
	mvn compile -DskipTests

lint:
	mvn checkstyle:check

test:
	mvn test

build:
	mvn package -DskipTests

outdated:
	mvn versions:display-dependency-updates
```

### pre-commit 配置（`.pre-commit-config.yaml`）

```yaml
repos:
  - repo: local
    hooks:
      - id: maven-checkstyle
        name: Checkstyle
        entry: mvn checkstyle:check -q
        language: system
        pass_filenames: false
      - id: maven-compile
        name: Compile
        entry: mvn compile -DskipTests -q
        language: system
        pass_filenames: false
      - id: maven-test
        name: Tests
        entry: mvn test -q
        language: system
        pass_filenames: false
```

---

## Java / Kotlin (Gradle)

### build.gradle.kts 插件最小集

```kotlin
plugins {
    kotlin("jvm") version "2.0.0"
    id("io.gitlab.arturbosch.detekt") version "1.23.6"
    id("com.diffplug.spotless") version "6.25.0"
    jacoco
}

detekt {
    buildUponDefaultConfig = true
    allRules = false
}

spotless {
    kotlin {
        ktlint()
    }
    java {
        googleJavaFormat()
    }
}

jacoco {
    toolVersion = "0.8.11"
}

tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                minimum = "0.70".toBigDecimal()
            }
        }
    }
}

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}
```

### Makefile 最小集

```makefile
.PHONY: install lint fmt test build

install:
	./gradlew dependencies

lint:
	./gradlew detekt

fmt:
	./gradlew spotlessCheck

fmt-fix:
	./gradlew spotlessApply

test:
	./gradlew test

build:
	./gradlew build -x test

outdated:
	./gradlew dependencyUpdates
```

### pre-commit 配置（`.pre-commit-config.yaml`）

```yaml
repos:
  - repo: local
    hooks:
      - id: gradle-spotless
        name: Spotless format check
        entry: ./gradlew spotlessCheck
        language: system
        pass_filenames: false
      - id: gradle-detekt
        name: Detekt lint
        entry: ./gradlew detekt
        language: system
        pass_filenames: false
      - id: gradle-test
        name: Tests
        entry: ./gradlew test
        language: system
        pass_filenames: false
```

---

## CI 模板

### GitHub Actions（`.github/workflows/harness-validate.yml`）

### CI 模式说明

- **bootstrap mode（初始化观察期）**：允许失败，仅用于建立基线与收集信号。
- bootstrap 必须拆分 `bootstrap-observe`（可失败）与 `critical-gates`（不可失败）。
- **enforced mode（正式门禁）**：不允许失败，用作真实合并门禁。
- 初次接入可使用 bootstrap mode；当基线稳定后必须切换到 enforced mode。
- Promotion Criteria（写死在文档/CI 注释中）：
  - 连续 N 天稳定（建议 7-14）
  - 失败率低于阈值（建议 < 5%）
  - 关键路径覆盖率达到目标阈值

### bootstrap mode（观察期，双 job）

```yaml
name: Harness Validation (Bootstrap)
on: [push, pull_request]

jobs:
  bootstrap-observe:
    runs-on: ubuntu-latest
    continue-on-error: true
    env:
      HARNESS_TRACK: bootstrap
      HARNESS_STRICT_MODE: "false"
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Setup environment
        run: <stack-specific setup step>
      - name: Lint
        run: make lint
      - name: Test
        run: make test
      - name: Architecture check
        run: make arch-check
      - name: Harness validation surface
        run: <validate-harness command>
      - name: Root navigation scope check (multi-project only)
        run: |
          if [ -f scripts/check-agents-scope.mjs ]; then
            node scripts/check-agents-scope.mjs
          elif [ -f scripts/check-agents-scope.sh ]; then
            bash scripts/check-agents-scope.sh
          else
            echo "SKIP: scripts/check-agents-scope.sh/.mjs not found"
          fi
  critical-gates:
    runs-on: ubuntu-latest
    continue-on-error: false
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Prepare PR body context
        if: ${{ github.event_name == 'pull_request' }}
        env:
          PR_BODY: ${{ github.event.pull_request.body }}
        run: |
          mkdir -p .harness
          printf "%s" "$PR_BODY" > .harness/pr-body.txt
      - name: Critical gates
        env:
          HARNESS_TRACK: bootstrap
          GITHUB_EVENT_NAME: ${{ github.event_name }}
          PR_BODY_FILE: .harness/pr-body.txt
          BASE_REF: ${{ github.event_name == 'pull_request' && github.event.pull_request.base.sha || 'origin/main' }}
          HEAD_REF: ${{ github.event_name == 'pull_request' && github.event.pull_request.head.sha || 'HEAD' }}
          PR_LABELS: ${{ github.event_name == 'pull_request' && join(github.event.pull_request.labels.*.name, ',') || '' }}
        run: bash .harness/scripts/check-critical.sh
```

### enforced mode（正式门禁）

```yaml
name: Harness Validation
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    continue-on-error: false
    env:
      HARNESS_TRACK: enforced
      HARNESS_STRICT_MODE: "true"
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Setup environment
        run: <stack-specific setup step>
      - name: Lint
        run: make lint
      - name: Test
        run: make test
      - name: Architecture check
        run: make arch-check
      - name: Harness validation surface
        run: <validate-harness command>
      - name: Root navigation scope check (multi-project only)
        run: |
          if [ -f .harness/scripts/check-agents-scope.mjs ]; then
            node .harness/scripts/check-agents-scope.mjs
          elif [ -f .harness/scripts/check-agents-scope.sh ]; then
            bash .harness/scripts/check-agents-scope.sh
          else
            echo "SKIP: .harness/scripts/check-agents-scope.sh/.mjs not found"
          fi
      - name: Harness full gates (enforced)
        run: bash .harness/scripts/check-all.sh
```

### GitLab CI（`.gitlab-ci.yml`）

### bootstrap mode（观察期，双 job）

```yaml
stages:
  - validate

bootstrap_observe:
  stage: validate
  script:
    - HARNESS_TRACK=bootstrap HARNESS_STRICT_MODE=false make lint
    - HARNESS_TRACK=bootstrap HARNESS_STRICT_MODE=false make test
    - HARNESS_TRACK=bootstrap HARNESS_STRICT_MODE=false make arch-check
    - HARNESS_TRACK=bootstrap HARNESS_STRICT_MODE=false <validate-harness command>
    - if [ -f .harness/scripts/check-agents-scope.mjs ]; then node .harness/scripts/check-agents-scope.mjs; elif [ -f .harness/scripts/check-agents-scope.sh ]; then bash .harness/scripts/check-agents-scope.sh; else echo "SKIP: .harness/scripts/check-agents-scope.sh/.mjs not found"; fi
  allow_failure: true
  rules:
    - when: always

critical_gates:
  stage: validate
  script:
    - mkdir -p .harness
    - printf "%s" "${CI_MERGE_REQUEST_DESCRIPTION:-}" > .harness/pr-body.txt
    - EVENT_NAME="push"; if [ "${CI_PIPELINE_SOURCE:-}" = "merge_request_event" ]; then EVENT_NAME="pull_request"; fi
    - GITHUB_EVENT_NAME="${EVENT_NAME}" PR_BODY_FILE=".harness/pr-body.txt" PR_LABELS="${CI_MERGE_REQUEST_LABELS:-}" BASE_REF="${CI_MERGE_REQUEST_DIFF_BASE_SHA:-origin/main}" HEAD_REF="${CI_COMMIT_SHA:-HEAD}" HARNESS_TRACK=bootstrap bash .harness/scripts/check-critical.sh
  allow_failure: false
  rules:
    - when: always
```

### enforced mode（正式门禁）

```yaml
stages:
  - validate

harness_validate:
  stage: validate
  script:
    - make lint
    - make test
    - make arch-check
    - <validate-harness command>
    - if [ -f scripts/check-agents-scope.mjs ]; then node scripts/check-agents-scope.mjs; elif [ -f scripts/check-agents-scope.sh ]; then bash scripts/check-agents-scope.sh; else echo "SKIP: scripts/check-agents-scope.sh/.mjs not found"; fi
    - HARNESS_TRACK=enforced HARNESS_STRICT_MODE=true bash .harness/scripts/check-all.sh
  allow_failure: false
  rules:
    - when: always
```

> **注意**: 以上 CI 模板中的 `make lint`/`make test`/`make arch-check` 应根据实际技术栈替换为对应命令。如果项目使用 Makefile，直接复用；否则替换为对应命令（如 `npm run lint`、`ruff check .`、`go test ./...` 等）。

### Cross-module Plan Gate（PR 计划关联门禁）

canonical 脚本：`.harness/scripts/check-plan-required.sh`

门禁规则：
- 若改动跨多个模块/作用域或命中规则（schema/CI/边界/infra/高风险标签），PR 必须关联 plan。
- PR 描述必须包含可解析的 plan 路径（支持 root 与 project-scoped `.harness/docs/exec-plans/*`）。
- 被引用 plan 文件必须存在且状态合法（默认 `active|completed`，可通过规则文件扩展）。
- active/completed 计划文件前 60 行必须有 `Status:` 字段。
- 非 PR 事件（如 `push`）自动跳过。
- multi-project：
  - 单项目作用域变更优先要求 `<project>/.harness/docs/exec-plans/*`
  - 跨项目/仓库级变更要求 `.harness/docs/exec-plans/*`

Pass examples:
- `.harness/docs/exec-plans/active/2026-04-cross-project.md`
- `apps/editor/.harness/docs/exec-plans/active/2026-04-editor.md`

建议将可判定触发条件写入 `.harness/plan-required-rules.yml`。
- 可选：`allowed_plan_statuses`（默认 `active|completed`，例如仅在特殊 ADR 下允许扩展）。

GitHub Actions 示例：

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0

- name: Prepare PR body context
  if: ${{ github.event_name == 'pull_request' }}
  env:
    PR_BODY: ${{ github.event.pull_request.body }}
  run: |
    mkdir -p .harness
    printf "%s" "$PR_BODY" > .harness/pr-body.txt

- name: Cross-module plan required gate
  if: ${{ github.event_name == 'pull_request' }}
  env:
    PR_BODY_FILE: .harness/pr-body.txt
    BASE_REF: ${{ github.event.pull_request.base.sha }}
    HEAD_REF: ${{ github.event.pull_request.head.sha }}
    GITHUB_EVENT_NAME: ${{ github.event_name }}
    PR_LABELS: ${{ join(github.event.pull_request.labels.*.name, ',') }}
  run: bash .harness/scripts/check-plan-required.sh
```

### Doc-gardening 定时任务（自动闭环）

建议新增定时 job（每日/每周）：
- 扫描过期文档与规则漂移
- 自动生成修复 PR（或补丁工单）
- 更新 `feedback-loops.md` 与 `entropy-gc.md` 的维护记录
- 建议产出 `.harness/docs/doc-gardening-report.md` 作为自动 PR 工件

GitHub Actions 示例（报告 + 自动 PR）：

```yaml
permissions:
  contents: write
  pull-requests: write

- name: Run doc-gardening and generate report
  env:
    DOC_GARDENING_WRITE_REPORT: "true"
  run: bash .harness/scripts/doc-gardening.sh

- name: Create doc-gardening PR
  uses: peter-evans/create-pull-request@v6
  with:
    commit-message: "docs(harness): 更新 doc-gardening 报告"
    title: "docs(harness): 更新 doc-gardening 报告"
    body: |
      Automated doc-gardening report refresh.
      - source: scheduled workflow
      - command: bash .harness/scripts/doc-gardening.sh
    branch: codex/doc-gardening-report
    delete-branch: true
```

### 运行面脚本建议（agent 可读可执行）

canonical script root：
- `.harness/scripts/`

multi-project 执行规则：
- 所有 harness 脚本从 repository root 执行
- 使用 `HARNESS_TARGET_SCOPE=<project-path>` 限定项目作用域

建议统一入口：
- `.harness/scripts/check-all.sh`：聚合门禁检查
- `.harness/scripts/check-critical.sh`：bootstrap critical 强门禁（最小阻断面）
- `.harness/scripts/check-placeholders.sh`：placeholder 过滤检查（忽略 harness marker）
- `.harness/scripts/check-boundaries.sh`：边界门禁
- `.harness/scripts/check-plan-required.sh`：跨模块计划门禁
- `.harness/scripts/check-alias-integrity.sh`：alias 漂移门禁
- `.harness/scripts/check-wrapper-integrity.sh`：legacy wrapper 残留门禁
- `.harness/scripts/reproduce.sh`：问题复现
- `.harness/scripts/validate.sh`：本地完整验证
- `.harness/scripts/regression.sh`：回归测试
- `.harness/scripts/pre-release.sh`：发布前检查
- `.harness/scripts/query-logs.sh`：日志查询（SLO 验证）
- `.harness/scripts/query-metrics.sh`：指标查询（SLO 验证）

fresh init 默认不生成 legacy 根脚本：

```bash
scripts/check-all.sh
scripts/validate.sh
scripts/regression.sh
```

---

### Gate Severity 与 ADR 例外

建议在仓库维护：
- `.harness/gate-severity.yml`
- `.harness/canonical-paths.yml`（可选，供 alias-integrity 动态读取 legacy 映射）
- `.harness/docs/decisions/ADR-exceptions/*.md`

规则：
- security/auth/data-migration 检查在命中对应变更范围或 PR label 时，在 bootstrap 与 enforced 都阻断。
- 临时降级必须有 ADR 例外且包含 `owner`、`expires_on`、`scope`。
- 过期例外必须恢复阻断。

可选映射文件示例（`.harness/canonical-paths.yml`）：

```yaml
version: 1
legacy_docs:
  - docs/autonomy-levels.md
  - docs/boundaries.md
  - docs/architecture-rules.md
  - docs/ci.md
  - docs/runtime-observability.md
```

---

### Harness Script Skeletons（最小可执行骨架）

通用骨架（用于大多数 gate 脚本）：

```bash
#!/usr/bin/env bash
set -euo pipefail

scope="${HARNESS_TARGET_SCOPE:-.}"
echo "Running <gate-name> on scope: ${scope}"

# TODO: configure rules
# exit 0 when pass
# exit 1 when fail
# exit 2 when not configured but required
exit 2
```

`.harness/scripts/check-all.sh`（完整聚合模板）：

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

scope="${HARNESS_TARGET_SCOPE:-.}"
track="${HARNESS_TRACK:-enforced}"
strict="${HARNESS_STRICT_MODE:-}"
SEVERITY_FILE="${HARNESS_GATE_SEVERITY_FILE:-.harness/gate-severity.yml}"
failed=0
BASH_BIN="${BASH:-bash}"

if [ -z "$strict" ]; then
  if [ "$track" = "bootstrap" ]; then
    strict="false"
  else
    strict="true"
  fi
fi

default_blocking_bootstrap="boundaries plan-required"
default_blocking_enforced="boundaries plan-required file-size naming logging placeholder-angle alias-integrity wrapper-integrity"

read_blocking_from_severity() {
  local target_track="$1"
  if [ ! -f "$SEVERITY_FILE" ]; then
    return 1
  fi
  awk -v track="$target_track" '
    BEGIN {in_track=0; in_blocking=0}
    /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*$/ {
      key=$0
      gsub(/^[[:space:]]+|:[[:space:]]*$/, "", key)
      if (key == track) {
        in_track=1
      } else if (in_track && key != "blocking" && key != "non_blocking" && key != "critical_gates") {
        in_track=0
        in_blocking=0
      }
    }
    in_track && /^[[:space:]]*blocking:[[:space:]]*$/ { in_blocking=1; next }
    in_track && in_blocking && /^[[:space:]]*-[[:space:]]*/ {
      gsub(/^[[:space:]]*-[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print $0
      next
    }
    in_track && in_blocking && /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*$/ { in_blocking=0 }
  ' "$SEVERITY_FILE" | paste -sd' ' -
}

blocking_gates="$(read_blocking_from_severity "$track" || true)"
if [ -z "$blocking_gates" ]; then
  if [ "$track" = "bootstrap" ]; then
    blocking_gates="$default_blocking_bootstrap"
  else
    blocking_gates="$default_blocking_enforced"
  fi
fi

gate_is_blocking() {
  local gate="$1"
  local normalized="$gate"
  case "$normalized" in
    boundaries) normalized="architecture-boundary" ;;
    file-size) normalized="file-size" ;;
    naming) normalized="naming" ;;
    logging) normalized="logging-structure" ;;
    placeholder-angle) normalized="placeholder-angle" ;;
    alias-integrity) normalized="alias-integrity" ;;
    wrapper-integrity) normalized="wrapper-integrity" ;;
    plan-required) normalized="plan-required" ;;
  esac
  for g in $blocking_gates; do
    if [ "$g" = "$gate" ] || [ "$g" = "$normalized" ]; then
      return 0
    fi
  done
  return 1
}

run_gate() {
  local name="$1"
  shift
  echo "== Gate: ${name} =="
  set +e
  "$@"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "PASS: ${name}"
  elif [ "$rc" -eq 2 ] && [ "$strict" != "true" ] && ! gate_is_blocking "$name"; then
    echo "WARN: ${name} not configured (strict=false, non-blocking in ${track})"
  else
    echo "FAIL: ${name} (exit=${rc})"
    failed=1
  fi
}

run_gate "boundaries" "$BASH_BIN" .harness/scripts/check-boundaries.sh
run_gate "plan-required" "$BASH_BIN" .harness/scripts/check-plan-required.sh
run_gate "file-size" "$BASH_BIN" .harness/scripts/check-file-size.sh
run_gate "naming" "$BASH_BIN" .harness/scripts/check-naming.sh
run_gate "logging" "$BASH_BIN" .harness/scripts/check-logging.sh
run_gate "placeholder-angle" "$BASH_BIN" .harness/scripts/check-placeholders.sh
run_gate "alias-integrity" "$BASH_BIN" .harness/scripts/check-alias-integrity.sh
run_gate "wrapper-integrity" "$BASH_BIN" .harness/scripts/check-wrapper-integrity.sh

if [ "$failed" -ne 0 ]; then
  echo "Harness checks FAILED"
  exit 1
fi

echo "Harness checks PASSED"
```

`.harness/scripts/check-file-size.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running file size gate..."
echo "TODO: enforce max file size policy"
exit 2
```

`.harness/scripts/check-placeholders.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

targets=()
[ -f "AGENTS.md" ] && targets+=("AGENTS.md")
[ -f "CLAUDE.md" ] && targets+=("CLAUDE.md")
[ -d ".harness/docs" ] && targets+=(".harness/docs")
for p in apps/* packages/* services/*; do
  [ -d "$p/.harness/docs" ] && targets+=("$p/.harness/docs")
done

if [ "${#targets[@]}" -eq 0 ]; then
  echo "WARN: no markdown targets for placeholder scan"
  exit 0
fi

hits="$(
  grep -R --line-number --include='*.md' '<[^>]\{1,\}>' "${targets[@]}" 2>/dev/null \
    | grep -v "harness-init:start" \
    | grep -v "harness-init:end" \
    | grep -v "://" \
    | grep -v "<!--" \
    | grep -Ev '^(.*/)?(\.git|\.agents|\.claude|\.qoder|\.workflow|node_modules|dist|build|vendor|third_party|examples|fixtures)/' \
    || true
)"

if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: unresolved <...> placeholders found"
  exit 1
fi

echo "PASS: placeholder-angle"
```

`.harness/scripts/check-critical.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

BASE_REF="${BASE_REF:-origin/main}"
HEAD_REF="${HEAD_REF:-HEAD}"
PR_LABELS="${PR_LABELS:-}"

changed_files="$(git diff --name-only "$BASE_REF...$HEAD_REF" 2>/dev/null || true)"
if [ -z "$changed_files" ]; then
  changed_files="$(git diff --name-only HEAD~1...HEAD 2>/dev/null || true)"
fi

failed=0
BASH_BIN="${BASH:-bash}"

run_required_gate() {
  local name="$1"
  local cmd="$2"
  echo "== Critical gate: ${name} =="
  if [ ! -f "$cmd" ]; then
    echo "FAIL: missing required script: ${cmd}"
    failed=1
    return
  fi
  set +e
  "$BASH_BIN" "$cmd"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: ${name} (exit=${rc})"
    failed=1
  else
    echo "PASS: ${name}"
  fi
}

run_conditional_domain_gate() {
  local name="$1"
  local script_path="$2"
  local path_regex="$3"
  local label_regex="$4"
  local required=0

  if [ -n "$changed_files" ] && echo "$changed_files" | grep -Eiq "$path_regex"; then
    required=1
  fi
  if [ -n "$PR_LABELS" ] && echo "$PR_LABELS" | grep -Eiq "$label_regex"; then
    required=1
  fi

  if [ "$required" -eq 1 ]; then
    if [ ! -f "$script_path" ]; then
      echo "FAIL: ${script_path} is required when ${name} scope is touched"
      failed=1
      return
    fi
    run_required_gate "$name" "$script_path"
    return
  fi

  if [ -f "$script_path" ]; then
    echo "INFO: ${name} gate script exists but current change does not require it; skip"
  else
    echo "WARN: ${script_path} not found; skipped because ${name} scope is not touched"
  fi
}

run_required_gate "plan-required" ".harness/scripts/check-plan-required.sh"
run_required_gate "placeholder-angle" ".harness/scripts/check-placeholders.sh"
run_required_gate "alias-integrity" ".harness/scripts/check-alias-integrity.sh"
run_required_gate "wrapper-integrity" ".harness/scripts/check-wrapper-integrity.sh"

# expired ADR exceptions (always blocking)
today="$(date +%F)"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  expires="$(
    awk -F: '
      /^expires_on:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {
        gsub(/[[:space:]]/, "", $2)
        print $2
        exit
      }
    ' "$f"
  )"
  if [ -n "$expires" ] && [ "$expires" \< "$today" ]; then
    echo "FAIL: expired ADR exception: $f (expires_on=${expires})"
    failed=1
  fi
done <<EOF
$(find .harness/docs/decisions/ADR-exceptions -type f -name '*.md' 2>/dev/null || true)
EOF

# domain-specific critical gates (security/auth/data-migration)
run_conditional_domain_gate \
  "security" \
  ".harness/scripts/check-security.sh" \
  '(^|/)(security|secrets?|iam|policy|policies|waf|sast|dast|csp|csrf|xss|injection)/|(^|/)(secrets?|vault)/' \
  'security'

run_conditional_domain_gate \
  "auth" \
  ".harness/scripts/check-auth.sh" \
  '(^|/)(auth|authentication|authorization|oauth|oidc|sso|jwt|token|session|rbac|permission)/|(^|/)(login|signup)/' \
  'auth|authentication|authorization'

run_conditional_domain_gate \
  "data-migration" \
  ".harness/scripts/check-data-migration.sh" \
  '(^|/)(migrations?|schema|database|db|ddl|sql)/|\.sql$|\.ddl$' \
  'migration|data-migration|schema'

if [ "$failed" -ne 0 ]; then
  echo "Critical gates FAILED"
  exit 1
fi

echo "Critical gates PASSED"
```

`.harness/scripts/check-naming.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running naming convention gate..."
echo "TODO: enforce naming conventions"
exit 2
```

`.harness/scripts/check-logging.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running logging structure gate..."
echo "TODO: enforce logging schema/fields"
exit 2
```

`.harness/scripts/check-alias-integrity.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running alias integrity gate..."

MAPPING_FILE="${CANONICAL_PATHS_FILE:-.harness/canonical-paths.yml}"
legacy_files_default="
docs/autonomy-levels.md
docs/boundaries.md
docs/architecture-rules.md
docs/ci.md
docs/runtime-observability.md
"

read_legacy_files_from_mapping() {
  [ -f "$MAPPING_FILE" ] || return 1
  awk '
    /^[[:space:]]*legacy_docs:[[:space:]]*$/ { in_list=1; next }
    in_list && /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print $0
      next
    }
    in_list && /^[[:space:]]*[A-Za-z0-9_.-]+:[[:space:]]*/ { in_list=0 }
  ' "$MAPPING_FILE"
}

legacy_files="$(read_legacy_files_from_mapping || true)"
if [ -z "$legacy_files" ]; then
  legacy_files="$legacy_files_default"
fi

failed=0

for f in $legacy_files; do
  [ -f "$f" ] || continue
  if ! grep -q "Compatibility Alias" "$f"; then
    echo "FAIL: $f missing 'Compatibility Alias' header"
    failed=1
  fi
  if ! grep -q "Canonical source of truth" "$f"; then
    echo "FAIL: $f missing canonical pointer"
    failed=1
  fi
  if grep -Eiq '^##[[:space:]]+(Rule|Gate|Policy)\b' "$f"; then
    echo "FAIL: $f contains governance section headings"
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "PASS: alias integrity"
```

`.harness/scripts/check-wrapper-integrity.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

legacy_scripts="
scripts/check-all.sh
scripts/validate.sh
scripts/regression.sh
"

failed=0

for f in $legacy_scripts; do
  [ -f "$f" ] || continue
  if [ -f "$f" ]; then
    echo "FAIL: legacy wrapper should not exist after clean-cut migration: $f"
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "PASS: wrapper integrity"
```

`.harness/scripts/doc-gardening.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

report=".harness/docs/doc-gardening-report.md"
mkdir -p "$(dirname "$report")"

stale_plans="$(find . -path '*/.harness/docs/exec-plans/active/*.md' -type f -mtime +30 2>/dev/null || true)"
expired_adr=""
if [ -d .harness/docs/decisions/ADR-exceptions ]; then
  today="$(date +%F)"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    expires="$(
      awk -F: '
        /^expires_on:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {
          gsub(/[[:space:]]/, "", $2)
          print $2
          exit
        }
      ' "$f"
    )"
    if [ -n "$expires" ] && [ "$expires" \< "$today" ]; then
      expired_adr+="$f"$'\n'
    fi
  done <<EOF
$(find .harness/docs/decisions/ADR-exceptions -type f -name '*.md' 2>/dev/null || true)
EOF
fi

{
  echo "# Doc Gardening Report"
  echo
  echo "Generated: $(date -u +%FT%TZ)"
  echo
  echo "## Stale Active Plans (>30 days)"
  if [ -n "$stale_plans" ]; then
    echo "$stale_plans"
  else
    echo "none"
  fi
  echo
  echo "## Expired ADR Exceptions"
  if [ -n "$expired_adr" ]; then
    echo "$expired_adr"
  else
    echo "none"
  fi
} > "$report"

if [ -n "$expired_adr" ]; then
  echo "FAIL: expired ADR exceptions detected"
  exit 1
fi

echo "PASS: doc-gardening"
```

`.harness/scripts/reproduce.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running reproduce flow..."
if [ -n "${HARNESS_REPRO_COMMAND:-}" ]; then
  eval "$HARNESS_REPRO_COMMAND"
  exit $?
fi

echo "INFO: HARNESS_REPRO_COMMAND is not configured"
exit 2
```

`.harness/scripts/validate.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

track="${HARNESS_TRACK:-enforced}"
BASH_BIN="${BASH:-bash}"
if [ "$track" = "bootstrap" ]; then
  HARNESS_STRICT_MODE="${HARNESS_STRICT_MODE:-false}" "$BASH_BIN" .harness/scripts/check-all.sh
else
  HARNESS_STRICT_MODE="${HARNESS_STRICT_MODE:-true}" "$BASH_BIN" .harness/scripts/check-all.sh
fi
```

`.harness/scripts/regression.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${HARNESS_REGRESSION_COMMAND:-}" ]; then
  eval "$HARNESS_REGRESSION_COMMAND"
  exit $?
fi

echo "INFO: HARNESS_REGRESSION_COMMAND is not configured"
exit 2
```

`.harness/scripts/pre-release.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

BASH_BIN="${BASH:-bash}"
"$BASH_BIN" .harness/scripts/check-critical.sh
"$BASH_BIN" .harness/scripts/check-all.sh
```

`.harness/scripts/query-logs.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${LOG_BACKEND:-}" ]; then
  echo "ERROR: LOG_BACKEND is not configured"
  exit 2
fi

echo "INFO: query logs from backend=${LOG_BACKEND} scope=${HARNESS_TARGET_SCOPE:-.}"
exit 0
```

`.harness/scripts/query-metrics.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${METRICS_BACKEND:-}" ]; then
  echo "ERROR: METRICS_BACKEND is not configured"
  exit 2
fi

echo "INFO: query metrics from backend=${METRICS_BACKEND} scope=${HARNESS_TARGET_SCOPE:-.}"
exit 0
```
