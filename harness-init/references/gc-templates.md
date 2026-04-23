# Entropy Management & GC Templates

加载时机：**Step 7 配置熵管理时**读取本文件。

---

## drift-check 脚本模板

### Node / TypeScript

```bash
#!/bin/bash
# scripts/drift-check.sh
set -e
echo "=== Drift Check: $(date) ==="

echo "--- Circular dependencies ---"
npx madge --circular src/ || { echo "FAIL: circular deps found"; exit 1; }

echo "--- Outdated dependencies ---"
OUTDATED=$(npm outdated --json 2>/dev/null || echo "{}")
COUNT=$(echo "$OUTDATED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))")
echo "Outdated packages: $COUNT"
[ "$COUNT" -gt 10 ] && echo "WARNING: > 10 outdated packages"

echo "--- Test coverage check ---"
npm run test:coverage -- --reporter=json 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
total = data.get('total', {})
line_pct = total.get('lines', {}).get('pct', 0)
print(f'Line coverage: {line_pct}%')
if line_pct < 70:
    print('WARNING: coverage below 70%')
" 2>/dev/null || echo "Coverage check skipped"

echo "=== Drift check complete ==="
```

### Python

```bash
#!/bin/bash
# scripts/drift-check.sh
set -e
echo "=== Drift Check: $(date) ==="

echo "--- Outdated dependencies ---"
pip list --outdated 2>/dev/null | tee /tmp/outdated.txt
COUNT=$(cat /tmp/outdated.txt | wc -l)
echo "Outdated packages: $COUNT"

echo "--- Type errors ---"
mypy src/ --ignore-missing-imports 2>&1 | tail -5

echo "--- Ruff lint ---"
ruff check . --statistics 2>&1 | tail -10

echo "=== Drift check complete ==="
```

### Go

```bash
#!/bin/bash
# scripts/drift-check.sh
set -e
echo "=== Drift Check: $(date) ==="

echo "--- Build check ---"
go build ./...

echo "--- Vet check ---"
go vet ./...

echo "--- Outdated modules ---"
go list -u -m all 2>/dev/null | grep "\[" || echo "All modules up to date"

echo "--- Security audit ---"
command -v govulncheck >/dev/null && govulncheck ./... || echo "govulncheck not installed (go install golang.org/x/vuln/cmd/govulncheck@latest)"

echo "=== Drift check complete ==="
```

### Rust

```bash
#!/bin/bash
# scripts/drift-check.sh
set -e
echo "=== Drift Check: $(date) ==="

echo "--- Clippy ---"
cargo clippy -- -D warnings

echo "--- Outdated crates ---"
command -v cargo-outdated >/dev/null && cargo outdated || echo "cargo-outdated not installed (cargo install cargo-outdated)"

echo "--- Security audit ---"
command -v cargo-audit >/dev/null && cargo audit || echo "cargo-audit not installed (cargo install cargo-audit)"

echo "=== Drift check complete ==="
```

### Java (Maven)

```bash
#!/bin/bash
# scripts/drift-check.sh
set -e
echo "=== Drift Check: $(date) ==="

echo "--- Compile check ---"
mvn compile -DskipTests -q

echo "--- Checkstyle ---"
mvn checkstyle:check -q

echo "--- Outdated dependencies ---"
mvn versions:display-dependency-updates 2>/dev/null | grep "\->" | head -20

echo "=== Drift check complete ==="
```

---

## CI 定期 drift-check job

```yaml
# .github/workflows/weekly-drift.yml
name: Weekly Drift Check
on:
  schedule:
    - cron: '0 9 * * 1'  # 每周一 09:00
  workflow_dispatch:

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup environment
        run: <stack-specific setup step>
      - name: Run drift check
        run: bash scripts/drift-check.sh
      - name: Upload drift report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: drift-report-${{ github.run_number }}
          path: drift-report.txt
          retention-days: 30
```

---

## docs/health/baseline.md 模板

```md
# Health Baseline

**Captured**: YYYY-MM-DD
**Branch**: main / <branch>

## Metrics Snapshot

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Architecture violations | 0 | 0 | ✅ |
| Circular dependencies | 0 | 0 | ✅ |
| Test coverage (line) | XX% | ≥ 70% | ✅ / ⚠️ |
| Outdated dependencies | X | ≤ 10% | ✅ / ⚠️ |
| Dead code ratio | X% | < 5% | ✅ / ⚠️ |

## Known Technical Debt

| Item | Impact | Estimated Fix | Priority |
|------|--------|---------------|----------|
| <item> | <impact> | <time estimate> | High/Med/Low |

## Next GC Review Date

<YYYY-MM-DD>
```

---

## Canonical Doc-gardening Checks

建议 `.harness/scripts/doc-gardening.sh` 至少扫描：
- stale active plans
- TODO older than threshold
- outdated compatibility aliases
- canonical/legacy drift
- constraints without checks
- checks without docs
- feedback entries without hardening
- entropy-gc not updated
- CI governance exceptions past expiry

示例（最小骨架）：

```bash
#!/usr/bin/env bash
set -euo pipefail

report_path="${DOC_GARDENING_REPORT_PATH:-.harness/docs/doc-gardening-report.md}"
max_todo_days="${DOC_GARDENING_TODO_MAX_DAYS:-30}"

echo "# Doc Gardening Report" > "$report_path"
echo "" >> "$report_path"
echo "- generated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$report_path"
echo "- max_todo_days: ${max_todo_days}" >> "$report_path"
echo "" >> "$report_path"

echo "## Findings" >> "$report_path"
echo "" >> "$report_path"
echo "- TODO: implement stale active plans scan" >> "$report_path"
echo "- TODO: implement alias/wrapper drift scan" >> "$report_path"
echo "- TODO: implement ADR exception expiry scan" >> "$report_path"
```

---

## Entropy Compatibility Inventory Rule

`.harness/docs/entropy-gc.md` 中每个 alias/wrapper 必须记录：
- canonical target
- reason
- owner
- review date
- removal condition or permanent compatibility reason
