# Observability Templates

加载时机：**Step 4 Guides + Sensors + Observability**。

---

## Required Document

canonical 文件：`.harness/docs/observability.md`

---

## Minimum Agent-readable Surface

每个生产服务至少定义：
- health check command
- log query command
- metrics query command
- SLO check command
- rollback verification command

---

## Canonical Script Entry

必须使用：
- `.harness/scripts/query-logs.sh`
- `.harness/scripts/query-metrics.sh`

可选补充：
- `.harness/scripts/reproduce.sh`
- `.harness/scripts/validate.sh`
- `.harness/scripts/regression.sh`
- `.harness/scripts/pre-release.sh`

---

## Stub Behavior Contract

初始 stub 可以没有真实平台接入，但必须满足：
- explain required environment variables
- return non-zero when not configured
- no fake success path
- include clear setup instruction in output

---

## Stub Template: query-logs.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${LOG_BACKEND:-}" ]; then
  echo "ERROR: LOG_BACKEND is not configured"
  echo "Set LOG_BACKEND and implement provider query in .harness/scripts/query-logs.sh"
  exit 2
fi

echo "TODO: implement log query for backend: ${LOG_BACKEND}"
exit 2
```

## Stub Template: query-metrics.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${METRICS_BACKEND:-}" ]; then
  echo "ERROR: METRICS_BACKEND is not configured"
  echo "Set METRICS_BACKEND and implement provider query in .harness/scripts/query-metrics.sh"
  exit 2
fi

echo "TODO: implement metrics query for backend: ${METRICS_BACKEND}"
exit 2
```

---

## Observability Doc Template

```md
# Observability

## Service Inventory

| Service | Health | Logs | Metrics | SLO | Rollback Verify |
|---|---|---|---|---|---|
| <service> | `<cmd>` | `<cmd>` | `<cmd>` | `<cmd>` | `<cmd>` |

## Required Environment

- LOG_BACKEND=<provider>
- METRICS_BACKEND=<provider>

## Incident Verification Flow

1. Run health check
2. Query logs
3. Query metrics
4. Compare against SLO
5. Verify rollback result
```
