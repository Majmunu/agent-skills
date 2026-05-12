#!/usr/bin/env bash
# Harness Init — Observability: Traces Query Script
# Reads .harness/observability.yml to determine provider and queries distributed traces.
# Supports Tempo, Jaeger, and OpenTelemetry Collector backends.
# Exit codes: 0=success, 1=failure, 2=not-run

set -euo pipefail

# --- Defaults ---
TRACE_ID=""
SERVICE=""
SINCE=""
OPERATION=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.harness/observability.yml"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") (--trace-id <id> | --service <name>) [--since <duration>] [--operation <name>]

Query distributed traces based on .harness/observability.yml provider configuration.

Parameters:
  --trace-id <id>       Query by trace ID [mutually exclusive with --service]
  --service <name>      Query by service name [mutually exclusive with --trace-id]
  --since <duration>    Query time range (e.g. 1h, 30m, 7d)
  --operation <name>    Filter by operation name

Exit codes:
  0  Query successful (regardless of span count)
  1  Query failed (connection error, auth failure, etc.)
  2  Not configured (not-run)
EOF
  exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --trace-id)   TRACE_ID="$2"; shift 2 ;;
    --service)    SERVICE="$2"; shift 2 ;;
    --since)      SINCE="$2"; shift 2 ;;
    --operation)  OPERATION="$2"; shift 2 ;;
    --help|-h)    usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

# Validate mutually exclusive params
if [[ -z "$TRACE_ID" && -z "$SERVICE" ]]; then
  echo "Error: Either --trace-id or --service is required"
  usage
fi

if [[ -n "$TRACE_ID" && -n "$SERVICE" ]]; then
  echo "Error: --trace-id and --service are mutually exclusive"
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

# --- Build command string for not-run output ---
build_command_str() {
  local cmd="query-traces.sh"
  if [[ -n "$TRACE_ID" ]]; then
    cmd="$cmd --trace-id $TRACE_ID"
  fi
  if [[ -n "$SERVICE" ]]; then
    cmd="$cmd --service $SERVICE"
  fi
  if [[ -n "$SINCE" ]]; then
    cmd="$cmd --since $SINCE"
  fi
  if [[ -n "$OPERATION" ]]; then
    cmd="$cmd --operation $OPERATION"
  fi
  echo "$cmd"
}

# --- Config Check ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "not-run: Traces provider is not configured."
  echo "Command: $(build_command_str)"
  echo "Reason: .harness/observability.yml does not exist"
  echo "Risk: Cannot query distributed traces for request flow analysis"
  exit 2
fi

# --- Read Provider Config ---
PROVIDER=$(read_yml_value "$CONFIG_FILE" "traces.provider")
ENDPOINT_ENV=$(read_yml_value "$CONFIG_FILE" "traces.endpoint_env")
ENDPOINT=$(read_yml_value "$CONFIG_FILE" "traces.endpoint")

# --- Handle not-configured ---
if [[ -z "$PROVIDER" || "$PROVIDER" == "not-configured" ]]; then
  echo "not-run: Traces provider is not configured."
  echo "Command: $(build_command_str)"
  echo "Reason: .harness/observability.yml traces.provider is \"not-configured\""
  echo "Risk: Cannot query distributed traces for request flow analysis"
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

# --- Provider: tempo ---
query_tempo_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Traces endpoint is not configured."
    echo "Command: $(build_command_str)"
    echo "Reason: .harness/observability.yml traces.endpoint is not set and ${ENDPOINT_ENV:-TRACES_ENDPOINT} env var is empty"
    echo "Risk: Cannot query distributed traces for request flow analysis"
    exit 2
  fi

  local query_desc=""
  local api_url=""

  if [[ -n "$TRACE_ID" ]]; then
    # Query by trace ID
    query_desc="traceID=$TRACE_ID"
    api_url="$endpoint/api/traces/$TRACE_ID"

    echo "provider: tempo"
    echo "endpoint: $endpoint"
    echo "query: $query_desc"
    echo "---"

    local response
    if ! response=$(curl -sf --max-time 30 "$api_url" 2>&1); then
      echo "Error: Failed to query Tempo at $endpoint"
      echo "---"
      echo "spans: 0"
      exit 1
    fi

    echo "$response"
    local count
    count=$(echo "$response" | grep -co '"spanID"' 2>/dev/null || echo "0")
    echo "---"
    echo "spans: $count"
  else
    # Query by service name
    query_desc="service.name=$SERVICE"
    if [[ -n "$OPERATION" ]]; then
      query_desc="$query_desc&operation=$OPERATION"
    fi
    api_url="$endpoint/api/search"

    echo "provider: tempo"
    echo "endpoint: $endpoint"
    echo "query: $query_desc"
    echo "---"

    local curl_args=()
    curl_args+=(-sf --max-time 30)
    curl_args+=(--data-urlencode "tags=service.name=$SERVICE")
    if [[ -n "$OPERATION" ]]; then
      curl_args+=(--data-urlencode "tags=name=$OPERATION")
    fi
    if [[ -n "$SINCE" ]]; then
      curl_args+=(--data-urlencode "start=$(date -d "-$SINCE" +%s 2>/dev/null || date -v-"$SINCE" +%s 2>/dev/null || echo "")")
    fi

    local response
    if ! response=$(curl "${curl_args[@]}" "$api_url" 2>&1); then
      echo "Error: Failed to query Tempo at $endpoint"
      echo "---"
      echo "spans: 0"
      exit 1
    fi

    echo "$response"
    local count
    count=$(echo "$response" | grep -co '"traceID"' 2>/dev/null || echo "0")
    echo "---"
    echo "spans: $count"
  fi

  exit 0
}

# --- Provider: jaeger ---
query_jaeger_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Traces endpoint is not configured."
    echo "Command: $(build_command_str)"
    echo "Reason: .harness/observability.yml traces.endpoint is not set and ${ENDPOINT_ENV:-TRACES_ENDPOINT} env var is empty"
    echo "Risk: Cannot query distributed traces for request flow analysis"
    exit 2
  fi

  local query_desc=""
  local api_url=""

  if [[ -n "$TRACE_ID" ]]; then
    # Query by trace ID
    query_desc="traceID=$TRACE_ID"
    api_url="$endpoint/api/traces/$TRACE_ID"

    echo "provider: jaeger"
    echo "endpoint: $endpoint"
    echo "query: $query_desc"
    echo "---"

    local response
    if ! response=$(curl -sf --max-time 30 "$api_url" 2>&1); then
      echo "Error: Failed to query Jaeger at $endpoint"
      echo "---"
      echo "spans: 0"
      exit 1
    fi

    echo "$response"
    local count
    count=$(echo "$response" | grep -co '"spanID"' 2>/dev/null || echo "0")
    echo "---"
    echo "spans: $count"
  else
    # Query by service name
    query_desc="service=$SERVICE"
    if [[ -n "$OPERATION" ]]; then
      query_desc="$query_desc&operation=$OPERATION"
    fi

    api_url="$endpoint/api/traces?service=$SERVICE"
    if [[ -n "$OPERATION" ]]; then
      api_url="$api_url&operation=$OPERATION"
    fi
    if [[ -n "$SINCE" ]]; then
      api_url="$api_url&lookback=$SINCE"
    fi

    echo "provider: jaeger"
    echo "endpoint: $endpoint"
    echo "query: $query_desc"
    echo "---"

    local response
    if ! response=$(curl -sf --max-time 30 "$api_url" 2>&1); then
      echo "Error: Failed to query Jaeger at $endpoint"
      echo "---"
      echo "spans: 0"
      exit 1
    fi

    echo "$response"
    local count
    count=$(echo "$response" | grep -co '"spanID"' 2>/dev/null || echo "0")
    echo "---"
    echo "spans: $count"
  fi

  exit 0
}

# --- Provider: otel ---
query_otel_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Traces endpoint is not configured."
    echo "Command: $(build_command_str)"
    echo "Reason: .harness/observability.yml traces.endpoint is not set and ${ENDPOINT_ENV:-TRACES_ENDPOINT} env var is empty"
    echo "Risk: Cannot query distributed traces for request flow analysis"
    exit 2
  fi

  local query_desc=""

  if [[ -n "$TRACE_ID" ]]; then
    query_desc="traceID=$TRACE_ID"
  else
    query_desc="service.name=$SERVICE"
    if [[ -n "$OPERATION" ]]; then
      query_desc="$query_desc&operation=$OPERATION"
    fi
  fi

  echo "provider: otel"
  echo "endpoint: $endpoint"
  echo "query: $query_desc"
  echo "---"

  # OTel Collector typically proxies to a backend (Tempo/Jaeger)
  # Use the standard trace query endpoint
  local api_url
  local response

  if [[ -n "$TRACE_ID" ]]; then
    api_url="$endpoint/v1/traces/$TRACE_ID"
  else
    api_url="$endpoint/v1/traces?service.name=$SERVICE"
    if [[ -n "$OPERATION" ]]; then
      api_url="$api_url&operation=$OPERATION"
    fi
    if [[ -n "$SINCE" ]]; then
      api_url="$api_url&lookback=$SINCE"
    fi
  fi

  if ! response=$(curl -sf --max-time 30 "$api_url" 2>&1); then
    echo "Error: Failed to query OpenTelemetry Collector at $endpoint"
    echo "---"
    echo "spans: 0"
    exit 1
  fi

  echo "$response"
  local count
  count=$(echo "$response" | grep -co '"spanId"\|"span_id"' 2>/dev/null || echo "0")
  echo "---"
  echo "spans: $count"
  exit 0
}

# --- Dispatch by Provider ---
case "$PROVIDER" in
  tempo)
    query_tempo_provider
    ;;
  jaeger)
    query_jaeger_provider
    ;;
  otel)
    query_otel_provider
    ;;
  *)
    echo "not-run: Traces provider '$PROVIDER' is not supported."
    echo "Command: $(build_command_str)"
    echo "Reason: .harness/observability.yml traces.provider is \"$PROVIDER\" (unsupported)"
    echo "Risk: Cannot query distributed traces for request flow analysis"
    exit 2
    ;;
esac
