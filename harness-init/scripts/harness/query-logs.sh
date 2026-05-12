#!/usr/bin/env bash
# Harness Init — Observability: Log Query Script
# Reads .harness/observability.yml to determine provider and queries logs accordingly.
# Exit codes: 0=success, 1=failure, 2=not-run

set -euo pipefail

# --- Defaults ---
SINCE=""
LEVEL=""
KEYWORD=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.harness/observability.yml"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") --since <duration> [--level <level>] [--keyword <keyword>]

Query application logs based on .harness/observability.yml provider configuration.

Parameters:
  --since <duration>   Query time range (e.g. 1h, 30m, 7d) [required]
  --level <level>      Log level filter (debug, info, warn, error, fatal)
  --keyword <keyword>  Keyword search filter

Exit codes:
  0  Query successful (regardless of match count)
  1  Query failed (connection error, auth failure, etc.)
  2  Not configured (not-run)
EOF
  exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)  SINCE="$2"; shift 2 ;;
    --level)  LEVEL="$2"; shift 2 ;;
    --keyword) KEYWORD="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

if [[ -z "$SINCE" ]]; then
  echo "Error: --since is required"
  usage
fi

# --- YAML Reading Helper ---
# Lightweight YAML value reader (supports simple key: value lines)
read_yml_value() {
  local file="$1"
  local key_path="$2"
  # Split key_path by '.' and grep nested values
  local IFS='.'
  read -ra keys <<< "$key_path"
  local indent=0
  local result=""
  local in_section=true

  if [[ ${#keys[@]} -eq 1 ]]; then
    result=$(grep -E "^${keys[0]}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  elif [[ ${#keys[@]} -eq 2 ]]; then
    result=$(sed -n "/^${keys[0]}:/,/^[a-z]/p" "$file" 2>/dev/null | grep -E "^[[:space:]]+${keys[1]}:" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
  fi
  echo "$result"
}

# --- Config Check ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "not-run: Logs provider is not configured."
  echo "Command: query-logs.sh --since $SINCE${LEVEL:+ --level $LEVEL}${KEYWORD:+ --keyword \"$KEYWORD\"}"
  echo "Reason: .harness/observability.yml does not exist"
  echo "Risk: Cannot query application logs for incident diagnosis"
  exit 2
fi

# --- Read Provider Config ---
PROVIDER=$(read_yml_value "$CONFIG_FILE" "logs.provider")
LOCAL_PATH=$(read_yml_value "$CONFIG_FILE" "logs.local_path")
ENDPOINT_ENV=$(read_yml_value "$CONFIG_FILE" "logs.endpoint_env")
ENDPOINT=$(read_yml_value "$CONFIG_FILE" "logs.endpoint")

# --- Handle not-configured ---
if [[ -z "$PROVIDER" || "$PROVIDER" == "not-configured" ]]; then
  echo "not-run: Logs provider is not configured."
  echo "Command: query-logs.sh --since $SINCE${LEVEL:+ --level $LEVEL}${KEYWORD:+ --keyword \"$KEYWORD\"}"
  echo "Reason: .harness/observability.yml logs.provider is \"not-configured\""
  echo "Risk: Cannot query application logs for incident diagnosis"
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

# --- Provider: file ---
query_file_provider() {
  local log_path="$PROJECT_ROOT/$LOCAL_PATH"

  if [[ -z "$LOCAL_PATH" ]]; then
    echo "not-run: Logs local_path is not configured."
    echo "Command: query-logs.sh --since $SINCE${LEVEL:+ --level $LEVEL}${KEYWORD:+ --keyword \"$KEYWORD\"}"
    echo "Reason: .harness/observability.yml logs.local_path is empty"
    echo "Risk: Cannot query application logs for incident diagnosis"
    exit 2
  fi

  if [[ ! -d "$log_path" && ! -f "$log_path" ]]; then
    echo "provider: file"
    echo "path: $LOCAL_PATH"
    echo "---"
    echo "No log files found at: $LOCAL_PATH"
    echo "---"
    echo "matches: 0"
    exit 0
  fi

  # Build grep/rg pattern
  local search_tool="grep"
  if command -v rg >/dev/null 2>&1; then
    search_tool="rg"
  fi

  local pattern=""
  local grep_args=()
  local rg_args=()

  # Level filter
  if [[ -n "$LEVEL" ]]; then
    local level_upper
    level_upper=$(echo "$LEVEL" | tr '[:lower:]' '[:upper:]')
    if [[ "$search_tool" == "rg" ]]; then
      rg_args+=(-i -e "$level_upper")
    else
      grep_args+=(-i -e "$level_upper")
    fi
  fi

  # Keyword filter
  if [[ -n "$KEYWORD" ]]; then
    if [[ "$search_tool" == "rg" ]]; then
      if [[ ${#rg_args[@]} -gt 0 ]]; then
        # rg doesn't support multiple -e with AND; use pipe
        :
      else
        rg_args+=(-i -e "$KEYWORD")
      fi
    else
      if [[ ${#grep_args[@]} -gt 0 ]]; then
        :
      else
        grep_args+=(-i -e "$KEYWORD")
      fi
    fi
  fi

  echo "provider: file"
  echo "path: $LOCAL_PATH"
  echo "---"

  local results=""
  local match_count=0

  if [[ "$search_tool" == "rg" ]]; then
    # Use rg for searching
    if [[ -n "$LEVEL" && -n "$KEYWORD" ]]; then
      results=$(rg -i --no-heading "$KEYWORD" "$log_path" 2>/dev/null | grep -i "$LEVEL" || true)
    elif [[ -n "$LEVEL" ]]; then
      results=$(rg -i --no-heading "$LEVEL" "$log_path" 2>/dev/null || true)
    elif [[ -n "$KEYWORD" ]]; then
      results=$(rg -i --no-heading "$KEYWORD" "$log_path" 2>/dev/null || true)
    else
      results=$(rg --no-heading "." "$log_path" 2>/dev/null || true)
    fi
  else
    # Use grep for searching
    if [[ -n "$LEVEL" && -n "$KEYWORD" ]]; then
      results=$(grep -rni "$KEYWORD" "$log_path" 2>/dev/null | grep -i "$LEVEL" || true)
    elif [[ -n "$LEVEL" ]]; then
      results=$(grep -rni "$LEVEL" "$log_path" 2>/dev/null || true)
    elif [[ -n "$KEYWORD" ]]; then
      results=$(grep -rni "$KEYWORD" "$log_path" 2>/dev/null || true)
    else
      results=$(grep -rn "." "$log_path" 2>/dev/null || true)
    fi
  fi

  if [[ -n "$results" ]]; then
    echo "$results"
    match_count=$(echo "$results" | wc -l | tr -d ' ')
  fi

  echo "---"
  echo "matches: $match_count"
  exit 0
}

# --- Provider: loki ---
query_loki_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Logs endpoint is not configured."
    echo "Command: query-logs.sh --since $SINCE${LEVEL:+ --level $LEVEL}${KEYWORD:+ --keyword \"$KEYWORD\"}"
    echo "Reason: .harness/observability.yml logs.endpoint is not set and ${ENDPOINT_ENV:-LOGS_ENDPOINT} env var is empty"
    echo "Risk: Cannot query application logs for incident diagnosis"
    exit 2
  fi

  # Build LogQL query
  local query='{app=~".+"}'
  if [[ -n "$KEYWORD" ]]; then
    query="${query} |= \"$KEYWORD\""
  fi
  if [[ -n "$LEVEL" ]]; then
    query="${query} | level=\"$LEVEL\""
  fi

  echo "provider: loki"
  echo "endpoint: $endpoint"
  echo "query: $query"
  echo "---"

  # Execute Loki query via HTTP API
  local api_url="$endpoint/loki/api/v1/query_range"
  local response
  if ! response=$(curl -sf --max-time 30 "$api_url" \
    --data-urlencode "query=$query" \
    --data-urlencode "since=$SINCE" 2>&1); then
    echo "Error: Failed to query Loki at $endpoint"
    echo "---"
    echo "matches: 0"
    exit 1
  fi

  echo "$response"
  local count
  count=$(echo "$response" | grep -c "\"values\"" 2>/dev/null || echo "0")
  echo "---"
  echo "matches: $count"
  exit 0
}

# --- Provider: victoria-logs ---
query_victoria_logs_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Logs endpoint is not configured."
    echo "Command: query-logs.sh --since $SINCE${LEVEL:+ --level $LEVEL}${KEYWORD:+ --keyword \"$KEYWORD\"}"
    echo "Reason: .harness/observability.yml logs.endpoint is not set and ${ENDPOINT_ENV:-LOGS_ENDPOINT} env var is empty"
    echo "Risk: Cannot query application logs for incident diagnosis"
    exit 2
  fi

  # Build VictoriaLogs query
  local query_parts=()
  if [[ -n "$KEYWORD" ]]; then
    query_parts+=("_msg:\"$KEYWORD\"")
  fi
  if [[ -n "$LEVEL" ]]; then
    query_parts+=("level:$LEVEL")
  fi
  query_parts+=("_time:[now-$SINCE, now]")

  local query
  query=$(IFS=" AND "; echo "${query_parts[*]}")

  echo "provider: victoria-logs"
  echo "endpoint: $endpoint"
  echo "query: $query"
  echo "---"

  # Execute VictoriaLogs query via HTTP API
  local api_url="$endpoint/select/logsql/query"
  local response
  if ! response=$(curl -sf --max-time 30 "$api_url" \
    --data-urlencode "query=$query" 2>&1); then
    echo "Error: Failed to query VictoriaLogs at $endpoint"
    echo "---"
    echo "matches: 0"
    exit 1
  fi

  echo "$response"
  local count
  count=$(echo "$response" | wc -l | tr -d ' ')
  echo "---"
  echo "matches: $count"
  exit 0
}

# --- Provider: elastic ---
query_elastic_provider() {
  local endpoint
  endpoint=$(resolve_endpoint)

  if [[ -z "$endpoint" ]]; then
    echo "not-run: Logs endpoint is not configured."
    echo "Command: query-logs.sh --since $SINCE${LEVEL:+ --level $LEVEL}${KEYWORD:+ --keyword \"$KEYWORD\"}"
    echo "Reason: .harness/observability.yml logs.endpoint is not set and ${ENDPOINT_ENV:-LOGS_ENDPOINT} env var is empty"
    echo "Risk: Cannot query application logs for incident diagnosis"
    exit 2
  fi

  # Build Elasticsearch query
  local must_clauses=()
  if [[ -n "$LEVEL" ]]; then
    must_clauses+=("{\"match\":{\"level\":\"$LEVEL\"}}")
  fi
  if [[ -n "$KEYWORD" ]]; then
    must_clauses+=("{\"match_phrase\":{\"message\":\"$KEYWORD\"}}")
  fi
  must_clauses+=("{\"range\":{\"@timestamp\":{\"gte\":\"now-$SINCE\"}}}")

  local must_json
  must_json=$(IFS=","; echo "${must_clauses[*]}")
  local query="{\"query\":{\"bool\":{\"must\":[$must_json]}}}"

  echo "provider: elastic"
  echo "endpoint: $endpoint"
  echo "query: $query"
  echo "---"

  # Execute Elasticsearch query
  local response
  if ! response=$(curl -sf --max-time 30 "$endpoint/_search" \
    -H "Content-Type: application/json" \
    -d "$query" 2>&1); then
    echo "Error: Failed to query Elasticsearch at $endpoint"
    echo "---"
    echo "matches: 0"
    exit 1
  fi

  echo "$response"
  local count
  count=$(echo "$response" | grep -o '"total":[0-9]*' | head -1 | cut -d: -f2 || echo "0")
  echo "---"
  echo "matches: ${count:-0}"
  exit 0
}

# --- Dispatch by Provider ---
case "$PROVIDER" in
  file)
    query_file_provider
    ;;
  loki)
    query_loki_provider
    ;;
  victoria-logs)
    query_victoria_logs_provider
    ;;
  elastic)
    query_elastic_provider
    ;;
  *)
    echo "not-run: Logs provider '$PROVIDER' is not supported."
    echo "Command: query-logs.sh --since $SINCE${LEVEL:+ --level $LEVEL}${KEYWORD:+ --keyword \"$KEYWORD\"}"
    echo "Reason: .harness/observability.yml logs.provider is \"$PROVIDER\" (unsupported)"
    echo "Risk: Cannot query application logs for incident diagnosis"
    exit 2
    ;;
esac
