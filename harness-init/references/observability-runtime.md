# Observability Runtime Reference

加载时机：**Step 4 Runtime + Observability + UI**。

本文档说明 `.harness/observability.yml` 配置文件的完整 schema、各 provider 的使用方式，以及 query 脚本的输入/输出规范。

---

## Configuration File

路径：`.harness/observability.yml`

该文件由 harness-init 在 Step 4 生成，定义项目的 logs、metrics、traces 查询后端和 SLO 目标。所有 `scripts/harness/query-*.sh` 脚本从此文件读取 provider 配置。

---

## Schema Overview

```yaml
version: 1
logs:
  provider: <provider>       # file | loki | victoria-logs | elastic | not-configured
  local_path: <path>         # 本地日志路径（provider=file 时使用）
  endpoint_env: <ENV_VAR>    # 存放远程 endpoint 的环境变量名
  endpoint: <url>            # 远程 endpoint URL
metrics:
  provider: <provider>       # prometheus | victoria-metrics | not-configured
  endpoint_env: <ENV_VAR>
  endpoint: <url>
  query_timeout: <seconds>
traces:
  provider: <provider>       # tempo | jaeger | otel | not-configured
  endpoint_env: <ENV_VAR>
  endpoint: <url>
slo:
  availability: <target>     # e.g. "99.9%"
  latency_p95: <target>      # e.g. "200ms"
  error_rate: <target>       # e.g. "0.1%"
```

---

## Logs Providers

### `file` — 本地文件日志

最简单的 provider，使用 `grep` 或 `rg`（ripgrep）搜索本地日志文件。

| 配置项 | 说明 |
|---|---|
| `local_path` | 日志文件目录，相对于项目根目录 |
| `endpoint_env` | 不使用（可忽略） |
| `endpoint` | 不使用（可忽略） |

**query-logs.sh 输入：**
```bash
scripts/harness/query-logs.sh --since 1h --level error --keyword "timeout"
```

**query-logs.sh 输出（file provider）：**
```
provider: file
path: logs/
---
logs/app.log:142: [2024-01-15 10:23:45] ERROR timeout connecting to database
logs/app.log:156: [2024-01-15 10:24:01] ERROR request timeout after 30s
---
matches: 2
```

### `loki` — Grafana Loki

通过 Loki HTTP API 查询日志。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `LOGS_ENDPOINT` |
| `endpoint` | Loki 实例 URL，如 `http://loki.internal:3100` |

**query-logs.sh 输出（loki provider）：**
```
provider: loki
endpoint: http://loki.internal:3100
query: {app="myservice"} |= "timeout" | level="error"
---
<loki query results in JSON lines format>
---
matches: <count>
```

### `victoria-logs` — VictoriaLogs

通过 VictoriaLogs HTTP API 查询日志。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `LOGS_ENDPOINT` |
| `endpoint` | VictoriaLogs 实例 URL，如 `http://vlogs.internal:9428` |

**query-logs.sh 输出（victoria-logs provider）：**
```
provider: victoria-logs
endpoint: http://vlogs.internal:9428
query: _msg:"timeout" AND level:error AND _time:[now-1h, now]
---
<victoria-logs query results>
---
matches: <count>
```

### `elastic` — Elasticsearch / OpenSearch

通过 Elasticsearch REST API 查询日志。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `LOGS_ENDPOINT` |
| `endpoint` | Elasticsearch 实例 URL，如 `http://elasticsearch.internal:9200` |

**query-logs.sh 输出（elastic provider）：**
```
provider: elastic
endpoint: http://elasticsearch.internal:9200
query: {"query":{"bool":{"must":[{"match":{"level":"error"}},{"match_phrase":{"message":"timeout"}}]}}}
---
<elasticsearch query results>
---
matches: <count>
```

### `not-configured`

当 provider 设为 `not-configured` 时，脚本输出 `not-run`。

**query-logs.sh 输出：**
```
not-run: Logs provider is not configured.
Command: query-logs.sh --since 1h --level error --keyword "timeout"
Reason: .harness/observability.yml logs.provider is "not-configured"
Risk: Cannot query application logs for incident diagnosis
```

---

## Metrics Providers

### `prometheus` — Prometheus

通过 Prometheus HTTP API 执行 PromQL 查询。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `METRICS_ENDPOINT` |
| `endpoint` | Prometheus 实例 URL，如 `http://prometheus.internal:9090` |
| `query_timeout` | 查询超时秒数（默认 30） |

**query-metrics.sh 输入：**
```bash
scripts/harness/query-metrics.sh --query 'rate(http_requests_total{status=~"5.."}[5m])' --time 2024-01-15T10:00:00Z
```

**query-metrics.sh 输出（prometheus provider）：**
```
provider: prometheus
endpoint: http://prometheus.internal:9090
query: rate(http_requests_total{status=~"5.."}[5m])
---
<prometheus query result in JSON format>
---
status: success
```

### `victoria-metrics` — VictoriaMetrics

通过 VictoriaMetrics HTTP API 执行 PromQL/MetricsQL 查询。接口兼容 Prometheus。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `METRICS_ENDPOINT` |
| `endpoint` | VictoriaMetrics 实例 URL，如 `http://vmselect.internal:8481` |
| `query_timeout` | 查询超时秒数（默认 30） |

**query-metrics.sh 输出（victoria-metrics provider）：**
```
provider: victoria-metrics
endpoint: http://vmselect.internal:8481
query: rate(http_requests_total{status=~"5.."}[5m])
---
<victoria-metrics query result in JSON format>
---
status: success
```

### `not-configured`

**query-metrics.sh 输出：**
```
not-run: Metrics provider is not configured.
Command: query-metrics.sh --query '...'
Reason: .harness/observability.yml metrics.provider is "not-configured"
Risk: Cannot query application metrics for performance analysis or SLO verification
```

---

## Traces Providers

### `tempo` — Grafana Tempo

通过 Tempo HTTP API 查询分布式追踪。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `TRACES_ENDPOINT` |
| `endpoint` | Tempo 实例 URL，如 `http://tempo.internal:3200` |

**query-traces.sh 输入：**
```bash
# 按 trace ID 查询
scripts/harness/query-traces.sh --trace-id abc123def456

# 按 service name 查询
scripts/harness/query-traces.sh --service myservice --since 1h
```

**query-traces.sh 输出（tempo provider）：**
```
provider: tempo
endpoint: http://tempo.internal:3200
query: traceID=abc123def456
---
<tempo trace data in JSON format>
---
spans: <count>
```

### `jaeger` — Jaeger

通过 Jaeger HTTP API 查询分布式追踪。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `TRACES_ENDPOINT` |
| `endpoint` | Jaeger 实例 URL，如 `http://jaeger.internal:16686` |

**query-traces.sh 输出（jaeger provider）：**
```
provider: jaeger
endpoint: http://jaeger.internal:16686
query: service=myservice&operation=GET /api/users
---
<jaeger trace data in JSON format>
---
spans: <count>
```

### `otel` — OpenTelemetry Collector

通过 OpenTelemetry Collector 的 gRPC/HTTP 接口查询追踪数据。通常需要配合后端存储（如 Tempo、Jaeger）使用。

| 配置项 | 说明 |
|---|---|
| `endpoint_env` | 环境变量名，如 `TRACES_ENDPOINT` |
| `endpoint` | OTel Collector 实例 URL，如 `http://otel-collector.internal:4317` |

**query-traces.sh 输出（otel provider）：**
```
provider: otel
endpoint: http://otel-collector.internal:4317
query: service.name=myservice
---
<otel trace data>
---
spans: <count>
```

### `not-configured`

**query-traces.sh 输出：**
```
not-run: Traces provider is not configured.
Command: query-traces.sh --trace-id abc123
Reason: .harness/observability.yml traces.provider is "not-configured"
Risk: Cannot query distributed traces for request flow analysis
```

---

## SLO Section

SLO（Service Level Objectives）定义项目的可用性、延迟和错误率目标。quality scoring 脚本使用这些值判断服务是否达标。

| 字段 | 说明 | 示例值 |
|---|---|---|
| `availability` | 目标可用性百分比 | `"99.9%"` |
| `latency_p95` | 95 分位延迟目标 | `"200ms"` |
| `error_rate` | 错误率上限 | `"0.1%"` |

当值未确定时使用 `"TODO: 待补充"`。

### SLO 验证流程

```
1. query-metrics.sh 查询实际可用性 → 与 slo.availability 比较
2. query-metrics.sh 查询 p95 延迟 → 与 slo.latency_p95 比较
3. query-metrics.sh 查询错误率 → 与 slo.error_rate 比较
4. 输出 pass/fail 及偏差值
```

---

## Query Script Interface Summary

### query-logs.sh

| 参数 | 说明 | 必填 |
|---|---|---|
| `--since <duration>` | 查询时间范围（如 `1h`, `30m`, `7d`） | 是 |
| `--level <level>` | 日志级别过滤（`debug`, `info`, `warn`, `error`, `fatal`） | 否 |
| `--keyword <keyword>` | 关键词搜索 | 否 |

**输出格式：**
```
provider: <provider>
[endpoint: <url>]
[path: <local_path>]
[query: <constructed query>]
---
<query results>
---
matches: <count>
```

**退出码：**
- `0` — 查询成功（无论是否有匹配）
- `1` — 查询失败（连接错误、认证失败等）
- `2` — 未配置（not-run）

### query-metrics.sh

| 参数 | 说明 | 必填 |
|---|---|---|
| `--query <promql>` | PromQL 查询表达式 | 是 |
| `--time <timestamp>` | 查询时间点（ISO 8601） | 否 |
| `--range <duration>` | 范围查询时间窗口 | 否 |
| `--step <duration>` | 范围查询步长 | 否 |

**输出格式：**
```
provider: <provider>
endpoint: <url>
query: <promql>
---
<query results in JSON>
---
status: success|error
```

**退出码：**
- `0` — 查询成功
- `1` — 查询失败
- `2` — 未配置（not-run）

### query-traces.sh

| 参数 | 说明 | 必填 |
|---|---|---|
| `--trace-id <id>` | 按 trace ID 查询 | 与 --service 二选一 |
| `--service <name>` | 按 service name 查询 | 与 --trace-id 二选一 |
| `--since <duration>` | 查询时间范围 | 否 |
| `--operation <name>` | 按 operation 过滤 | 否 |

**输出格式：**
```
provider: <provider>
endpoint: <url>
query: <constructed query>
---
<trace data>
---
spans: <count>
```

**退出码：**
- `0` — 查询成功
- `1` — 查询失败
- `2` — 未配置（not-run）

---

## Environment Variables

| 变量名 | 用途 | 对应 provider |
|---|---|---|
| `LOGS_ENDPOINT` | 日志后端 URL | loki, victoria-logs, elastic |
| `METRICS_ENDPOINT` | 指标后端 URL | prometheus, victoria-metrics |
| `TRACES_ENDPOINT` | 追踪后端 URL | tempo, jaeger, otel |

脚本优先读取环境变量，若环境变量未设置则回退到 `observability.yml` 中的 `endpoint` 字段。

---

## Integration with Quality Score

`score-quality.sh` 的 `observability_surface` 维度（满分 15）检查以下项目：

| 检查项 | 分值 | 判定逻辑 |
|---|---|---|
| observability.yml 存在 | 3 | 文件存在且 YAML 合法 |
| query-logs 可用 | 3 | provider 非 not-configured 且脚本可执行 |
| query-metrics 可用 | 3 | provider 非 not-configured 且脚本可执行 |
| UI verification 已配置 | 3 | runtime.yml 中 ui.provider 非 not-configured |
| health check 可用 | 3 | runtime.yml 中 dev.health_check 非 TODO |

未配置的项目扣分，不给予 pass。

---

## Stub Behavior Contract

当 provider 为 `not-configured` 或 endpoint 环境变量未设置时：

1. 脚本输出 `not-run` 状态（非 pass、非 fail）
2. 说明未执行的命令
3. 说明原因（哪个配置缺失）
4. 说明残余风险
5. 退出码为 `2`

绝不输出 fake success。
