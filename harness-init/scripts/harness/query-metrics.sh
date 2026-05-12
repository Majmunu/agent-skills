#!/usr/bin/env bash
# Harness Init — Observability: Metrics Query Script
# Reads .harness/observability.yml to determine provider and executes PromQL queries.
# Supports Prometheus and VictoriaMetrics backends.
# Exit codes: 0=success, 1=failure, 2=not-run

set -euo pipefail

# --- Defaults ---
QUERY=""
TIME=""
RANGE=""
STEP=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.harness/observability.yml"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") --query <promql> [--time <timestamp>] [--range <duration>] [--step <duration>]

Query application metrics using PromQL via .harness/observability.yml provider configuration.

Parameters:
  --query <promql>      PromQL query expression [required]
  --time <timestamp>    Query time point (ISO 8601, e.g. 2024-01-15T10:00:00Z)
  --range <duration>    Range query time window (e.g. 1h, 30m)
  --step <duration>     Range query step interval (e.g. 15s, 1m)

Exit codes:
  0  Query successful
  1  Query failed (connection error, auth failure, invalid PromQL, etc.)
  2  Not configured (not-run)
EOF
  exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)  QUERY="$2"; shift 2 ;;
    --time)   TIME="$2"; shift 2 ;;
    --range)  RANGE="$2"; shift 2 ;;
    --step)   STEP="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

if [[ -z "$QUERY" ]]; then
  echo "Error: --query is required"
  usage
fi

# --- YAML Reading Helper ---
read_yml_value() {
  local file="$1"
  local key_path="$2"
  local IFS='.'
  read -ra keys <<< "$key_path"
  local result=""

  if [[ ${#keys[@]} -eq 1 ]]; then
    result=$(grep -E "^${keys[0]}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  elif [[ ${#keys[@]} -eq 2 ]]; then
    result=$(sed -n "/^${keys[0]}:/,/^[a-z]/p" "$file" 2>/dev/null | grep -E "^[[:space:]]+${keys[1]}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  fi
  echo "$result"
}

# --- Config Check ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "not-run: Metrics provider is not configured."
  echo "Command: query-metrics.sh --query '$QUERY'${TIME:+ --time $TIME}${RANGE:+ --range $RANGE}${STEP:+ --step $STEP}"
  echo "Reason: .harness/observability.yml does not exist"
  echo "Risk: Cannot query application metrics for performance analysis or SLO verification"
  exit 2
fi

# --- Read Provider Config ---
PROVIDER=$(read_yml_value "$CONFIG_FILE" "metrics.provider")
ENDPOINT_ENV=$(read_yml_value "$CONFIG_FILE" "metrics.endpoint_env")
ENDPOINT=$(read_yml_value "$CONFIG_FILE" "metrics.endpoint")
QUERY_TIMEOUT=$(read_yml_value "$CONFIG_FILE" "metrics.query_timeout")

# Default timeout
if [[ -z "$QUERY_TIMEOUT" ]]; then
  QUERY_TIMEOUT=30
fi

# --- Handle not-configured ---
if [[ -z "$PROVIDER" || "$PROVIDER" == "not-configured" ]]; then
  echo "not-run: Metrics provider is not configured."
  echo "Command: query-metrics.sh --query '$QUERY'${TIME:+ --time $TIME}${RANGE:+ --range $RANGE}${STEP:+ --step $STEP}"
  echo "Reason: .harness/observability.yml metrics.provider is \"not-configured\""
  echo "Risk: Cannot query application metrics for performance analysis or SLO verification"
  exit 2
fi

# --- Resolve endpoint from env var or config ---
resolve_endpoint() {
  local resolved=""
  if [[ -n "$ENDPOINT_ENV" ]] && [[ -n "${!ENDPOINT_ENV:-}" ]]; then
    resolved="${!ENDPOINT_ENV}"
  elif [[ -n "$ENDPOINT" && "$ENDPOINT" != "TODO: 待补充" ]]; then
    resolved="$ENDPOINT"
  fi
  echo "$resolved"
}

# --- Provider: prometheus ---
query_prometheus_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Metrics endpoint is not configured."
    echo "Command: query-metrics.sh --query '$QUERY'${TIME:+ --time $TIME}${RANGE:+ --range $RANGE}${STEP:+ --step $STEP}"
    echo "Reason: .harness/observability.yml metrics.endpoint is not set and ${ENDPOINT_ENV:-METRICS_ENDPOINT} env var is empty"
    echo "Risk: Cannot query application metrics for performance analysis or SLO verification"
    exit 2
  fi

  echo "provider: prometheus"
  echo "endpoint: $endpoint"
  echo "query: $QUERY"
  echo "---"

  local api_url
  local curl_args=()
  curl_args+=(--max-time "$QUERY_TIMEOUT")
  curl_args+=(-sf)

  if [[ -n "$RANGE" ]]; then
    # Range query
    api_url="$endpoint/api/v1/query_range"
    curl_args+=(--data-urlencode "query=$QUERY")
    if [[ -n "$TIME" ]]; then
      curl_args+=(--data-urlencode "end=$TIME")
    fi
    curl_args+=(--data-urlencode "duration=$RANGE")
    if [[ -n "$STEP" ]]; then
      curl_args+=(--data-urlencode "step=$STEP")
    else
      curl_args+=(--data-urlencode "step=15s")
    fi
  else
    # Instant query
    api_url="$endpoint/api/v1/query"
    curl_args+=(--data-urlencode "query=$QUERY")
    if [[ -n "$TIME" ]]; then
      curl_args+=(--data-urlencode "time=$TIME")
    fi
  fi

  local response
  if ! response=$(curl "${curl_args[@]}" "$api_url" 2>&1); then
    echo "Error: Failed to query Prometheus at $endpoint"
    echo "---"
    echo "status: error"
    exit 1
  fi

  echo "$response"
  echo "---"
  echo "status: success"
  exit 0
}

# --- Provider: victoria-metrics ---
query_victoria_metrics_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Metrics endpoint is not configured."
    echo "Command: query-metrics.sh --query '$QUERY'${TIME:+ --time $TIME}${RANGE:+ --range $RANGE}${STEP:+ --step $STEP}"
    echo "Reason: .harness/observability.yml metrics.endpoint is not set and ${ENDPOINT_ENV:-METRICS_ENDPOINT} env var is empty"
    echo "Risk: Cannot query application metrics for performance analysis or SLO verification"
    exit 2
  fi

  echo "provider: victoria-metrics"
  echo "endpoint: $endpoint"
  echo "query: $QUERY"
  echo "---"

  local api_url
  local curl_args=()
  curl_args+=(--max-time "$QUERY_TIMEOUT")
  curl_args+=(-sf)

  if [[ -n "$RANGE" ]]; then
    # Range query (VictoriaMetrics is Prometheus-compatible)
    api_url="$endpoint/api/v1/query_range"
    curl_args+=(--data-urlencode "query=$QUERY")
    if [[ -n "$TIME" ]]; then
      curl_args+=(--data-urlencode "end=$TIME")
    fi
    curl_args+=(--data-urlencode "duration=$RANGE")
    if [[ -n "$STEP" ]]; then
      curl_args+=(--data-urlencode "step=$STEP")
    else
      curl_args+=(--data-urlencode "step=15s")
    fi
  else
    # Instant query
    api_url="$endpoint/api/v1/query"
    curl_args+=(--data-urlencode "query=$QUERY")
    if [[ -n "$TIME" ]]; then
      curl_args+=(--data-urlencode "time=$TIME")
    fi
  fi

  local response
  if ! response=$(curl "${curl_args[@]}" "$api_url" 2>&1); then
    echo "Error: Failed to query VictoriaMetrics at $endpoint"
    echo "---"
    echo "status: error"
    exit 1
  fi

  echo "$response"
  echo "---"
  echo "status: success"
  exit 0
}

# --- Dispatch by Provider ---
case "$PROVIDER" in
  prometheus)
    query_prometheus_provider
    ;;
  victoria-metrics)
    query_victoria_metrics_provider
    ;;
  *)
    echo "not-run: Metrics provider '$PROVIDER' is not supported."
    echo "Command: query-metrics.sh --query '$QUERY'${TIME:+ --time $TIME}${RANGE:+ --range $RANGE}${STEP:+ --step $STEP}"
    echo "Reason: .harness/observability.yml metrics.provider is \"$PROVIDER\" (unsupported)"
    echo "Risk: Cannot query application metrics for performance analysis or SLO verification"
    exit 2
    ;;
esac
