#!/usr/bin/env bash
# assert-root-nav-clean.sh — Root navigation cleanliness checker
#
# Validates that root-level navigation files (AGENTS.md / CLAUDE.md) contain
# only global rules, repo layout, and project index — not project-specific
# commands, env vars, or database configs.
#
# Usage: tests/assert-root-nav-clean.sh <working-directory>
#
# Requirements: 3.1, 3.2, 3.3

set -euo pipefail

# --- Arguments ---
WORK_DIR="${1:?Usage: assert-root-nav-clean.sh <working-directory>}"

if [[ ! -d "$WORK_DIR" ]]; then
  echo "FAIL: assert-root-nav-clean"
  echo "Reason: Working directory does not exist"
  echo "Evidence: $WORK_DIR"
  echo "Fix: Provide a valid directory path as argument"
  echo "Docs: references/nav-templates.md"
  exit 1
fi

# --- Locate root navigation file ---
NAV_FILE=""
if [[ -f "$WORK_DIR/AGENTS.md" ]]; then
  NAV_FILE="$WORK_DIR/AGENTS.md"
elif [[ -f "$WORK_DIR/CLAUDE.md" ]]; then
  NAV_FILE="$WORK_DIR/CLAUDE.md"
fi

if [[ -z "$NAV_FILE" ]]; then
  # No root navigation file found — nothing to check, pass vacuously
  echo "pass: assert-root-nav-clean (no root navigation file found)"
  exit 0
fi

NAV_BASENAME="$(basename "$NAV_FILE")"

# --- Pollution patterns ---
# Pattern 1: cd into project subdirectories (Requirement 3.1)
CD_PATTERNS=(
  'cd apps/'
  'cd packages/'
  'cd services/'
)

# Pattern 2: Project-specific environment variables (Requirement 3.2)
ENV_VAR_PATTERNS=(
  'DATABASE_URL'
  'REDIS_URL'
  'MONGO_URI'
  'MONGODB_URI'
  'POSTGRES_URL'
  'MYSQL_URL'
  'DB_HOST'
  'DB_PASSWORD'
  'DB_USER'
  'DB_NAME'
  'DB_PORT'
  'RABBITMQ_URL'
  'AMQP_URL'
  'ELASTICSEARCH_URL'
  'KAFKA_BROKERS'
  'S3_BUCKET'
  'AWS_SECRET_ACCESS_KEY'
)

# Pattern 3: Project-specific database setup commands (Requirement 3.2)
DB_COMMAND_PATTERNS=(
  'createdb '
  'dropdb '
  'psql '
  'mysql '
  'mongosh '
  'redis-cli '
  'prisma migrate'
  'prisma db push'
  'knex migrate'
  'sequelize db:migrate'
  'typeorm migration:run'
  'drizzle-kit push'
)

# --- Scanning ---
VIOLATIONS=()
VIOLATION_COUNT=0

scan_patterns() {
  local pattern_type="$1"
  shift
  local patterns=("$@")

  for pattern in "${patterns[@]}"; do
    # Use grep with line numbers; -n for line number, -i for case-insensitive on env vars
    local grep_opts="-n"
    if [[ "$pattern_type" == "env_var" ]]; then
      grep_opts="-n"
    fi

    while IFS=: read -r line_num line_content; do
      if [[ -n "$line_num" ]]; then
        VIOLATIONS+=("Line $line_num: [$pattern_type] matched '$pattern' — $line_content")
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
      fi
    done < <(grep $grep_opts -F "$pattern" "$NAV_FILE" 2>/dev/null || true)
  done
}

# Scan for cd patterns (Requirement 3.1)
scan_patterns "cd_project_path" "${CD_PATTERNS[@]}"

# Scan for env var patterns (Requirement 3.2)
scan_patterns "env_var" "${ENV_VAR_PATTERNS[@]}"

# Scan for database command patterns (Requirement 3.2)
scan_patterns "db_command" "${DB_COMMAND_PATTERNS[@]}"

# --- Output ---
if [[ $VIOLATION_COUNT -gt 0 ]]; then
  echo "FAIL: assert-root-nav-clean"
  echo "Reason: Root navigation file '$NAV_BASENAME' contains project-specific commands or configuration"
  echo "Evidence:"
  for v in "${VIOLATIONS[@]}"; do
    echo "  $v"
  done
  echo "Fix: Move project-specific commands to the nearest project-level navigation file (e.g., apps/editor/AGENTS.md). Root navigation should only contain global rules, repo layout overview, and project index."
  echo "Docs: references/nav-templates.md"
  exit 1
else
  echo "pass: assert-root-nav-clean"
  exit 0
fi
