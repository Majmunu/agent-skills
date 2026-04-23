# CI Governance Template

加载时机：**Step 5.5 配置双轨 CI 与升级策略**。

---

## Required Document

canonical 文件：`.harness/docs/ci-governance.md`

---

## CI Tracks

### Track A: Bootstrap

目的：
- observe failure modes
- collect baseline
- reduce false positives
- prepare for enforcement

行为：
- split jobs:
  - `bootstrap-observe`: non-critical checks, may be non-blocking
  - `critical-gates`: always blocking
- checks run and report results

### Track B: Enforced

目的：
- block unsafe changes
- enforce engineering rules
- protect architecture boundaries

行为：
- required checks must pass
- failures block merge

---

## Gate Priority Policy

优先级从高到低：
1. `security/auth/data-migration` checks
2. architecture boundary checks
3. plan-required checks
4. custom lint / convention checks

规则：
- 第 1 类在命中对应变更范围/PR labels 时，在 `bootstrap` 与 `enforced` 都必须阻断（除非 ADR 例外且未过期）。
- 低优先级检查可在 bootstrap 期仅报告，enforced 期阻断。
- `not-run` 不能视为 `pass`；bootstrap 可记录 `not-run`，enforced 的 blocking gates 不允许 `not-run`。

critical-gates minimum:
- plan-required
- alias-integrity
- wrapper-integrity
- placeholder-angle
- expired-adr-exception

conditional critical gates (by changed scope or PR labels):
- security
- auth
- data-migration

---

## Promotion Criteria

一个 bootstrap 检查升级为 enforced 的前提：
- `stable_days >= 7`
- `failure_rate < 5%`
- `critical_path_coverage >= 85%`
- `false_positive_count == 0` in last 7 days
- `rollback_path_documented == true`
- `owner_assigned == true`

---

## Demotion Criteria

enforced 检查临时降级仅允许在以下条件满足时：
- `false_positive_incident == true` or `critical_delivery_blocked == true`
- ADR 例外存在
- fix owner 已指定
- 例外过期时间已设置

降级不可永久存在。

---

## ADR Exception Contract

例外路径：`.harness/docs/decisions/ADR-exceptions/*.md`

每个例外必须包含：
- `owner`
- `expires_on`
- `scope`
- `reason`
- `rollback_condition`

过期后自动失效，CI 必须恢复阻断。

---

## Gate Severity Config

建议在仓库写入 `.harness/gate-severity.yml`：

```yaml
version: 1
tracks:
  bootstrap:
    blocking:
      - security
      - auth
      - data-migration
    non_blocking:
      - naming
      - file-size
      - logging-structure
    critical_gates:
      - security
      - auth
      - data-migration
      - placeholder-angle
      - expired-adr-exception
  enforced:
    blocking:
      - security
      - auth
      - data-migration
      - architecture-boundary
      - plan-required
      - alias-integrity
      - wrapper-integrity
      - placeholder-angle
      - expired-adr-exception
```

---

## Workflow Shape (Recommended)

GitHub Actions:

```yaml
jobs:
  bootstrap-observe:
    if: ${{ vars.CI_TRACK == 'bootstrap' }}
    continue-on-error: true
    runs-on: ubuntu-latest
    env:
      HARNESS_TRACK: bootstrap
      HARNESS_STRICT_MODE: "false"
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash .harness/scripts/check-boundaries.sh
      - run: bash .harness/scripts/check-naming.sh
      - run: bash .harness/scripts/check-file-size.sh

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
      - name: Run critical gates
        env:
          HARNESS_TRACK: bootstrap
          GITHUB_EVENT_NAME: ${{ github.event_name }}
          PR_BODY_FILE: .harness/pr-body.txt
          BASE_REF: ${{ github.event_name == 'pull_request' && github.event.pull_request.base.sha || 'origin/main' }}
          HEAD_REF: ${{ github.event_name == 'pull_request' && github.event.pull_request.head.sha || 'HEAD' }}
          PR_LABELS: ${{ github.event_name == 'pull_request' && join(github.event.pull_request.labels.*.name, ',') || '' }}
        run: bash .harness/scripts/check-critical.sh

  enforced-validate:
    if: ${{ vars.CI_TRACK == 'enforced' }}
    runs-on: ubuntu-latest
    continue-on-error: false
    env:
      HARNESS_TRACK: enforced
      HARNESS_STRICT_MODE: "true"
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash .harness/scripts/check-all.sh
```

GitLab CI:

```yaml
bootstrap_observe:
  rules:
    - if: '$CI_TRACK == "bootstrap"'
  allow_failure: true
  script:
    - HARNESS_TRACK=bootstrap HARNESS_STRICT_MODE=false bash .harness/scripts/check-boundaries.sh
    - HARNESS_TRACK=bootstrap HARNESS_STRICT_MODE=false bash .harness/scripts/check-naming.sh

critical_gates:
  allow_failure: false
  script:
    - mkdir -p .harness
    - printf "%s" "${CI_MERGE_REQUEST_DESCRIPTION:-}" > .harness/pr-body.txt
    - EVENT_NAME="push"; if [ "${CI_PIPELINE_SOURCE:-}" = "merge_request_event" ]; then EVENT_NAME="pull_request"; fi
    - GITHUB_EVENT_NAME="${EVENT_NAME}" PR_BODY_FILE=".harness/pr-body.txt" PR_LABELS="${CI_MERGE_REQUEST_LABELS:-}" BASE_REF="${CI_MERGE_REQUEST_DIFF_BASE_SHA:-origin/main}" HEAD_REF="${CI_COMMIT_SHA:-HEAD}" HARNESS_TRACK=bootstrap bash .harness/scripts/check-critical.sh

enforced_validate:
  rules:
    - if: '$CI_TRACK == "enforced"'
  allow_failure: false
  script:
    - HARNESS_TRACK=enforced HARNESS_STRICT_MODE=true bash .harness/scripts/check-all.sh
```
