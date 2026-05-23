#!/usr/bin/env bash
# self-test.sh — Minimal harness-init fixture entry point
# Usage: bash scripts/harness/self-test.sh [--dry-run|--init]
set -euo pipefail

MODE="init"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --init)
      MODE="init"
      shift
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--dry-run|--init]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

PROJECT_ROOT="$(pwd)"

detect_package_manager() {
  if [[ -f "$PROJECT_ROOT/pnpm-lock.yaml" || -f "$PROJECT_ROOT/pnpm-workspace.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "$PROJECT_ROOT/yarn.lock" ]]; then
    echo "yarn"
  else
    echo "npm"
  fi
}

has_npm_script() {
  local name="$1"
  [[ -f "$PROJECT_ROOT/package.json" ]] || return 1
  grep -Eq "\"$name\"[[:space:]]*:" "$PROJECT_ROOT/package.json"
}

runtime_name() {
  [[ -f "$PROJECT_ROOT/package.json" ]] && echo "Node.js" || echo "Unknown"
}

language_name() {
  if [[ -f "$PROJECT_ROOT/tsconfig.json" ]] || find "$PROJECT_ROOT/src" -maxdepth 2 -name "*.ts" -o -name "*.tsx" 2>/dev/null | grep -q .; then
    echo "TypeScript"
  elif find "$PROJECT_ROOT/src" -maxdepth 2 -name "*.js" -o -name "*.jsx" 2>/dev/null | grep -q .; then
    echo "JavaScript"
  else
    echo "Unknown"
  fi
}

command_for_script() {
  local script="$1"
  local fallback="$2"
  if has_npm_script "$script"; then
    echo "$(detect_package_manager) run $script"
  else
    echo "$fallback"
  fi
}

write_if_changed() {
  local path="$1"
  local content="$2"
  local tmp

  tmp="$(mktemp)"
  printf "%s" "$content" > "$tmp"

  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  mv "$tmp" "$path"
}

emit_plan() {
  echo "Mode: single-project"
  echo "Detected Projects:"
  echo "- . (Node.js/TypeScript)"
  echo "Files to create/update:"
  echo "- AGENTS.md"
  echo "- .harness/runtime.yml"
  echo "- docs/runtime-surface.md"
}

init_single_node_ts() {
  local package_manager runtime language dev_cmd build_cmd test_cmd lint_cmd typecheck_cmd
  package_manager="$(detect_package_manager)"
  runtime="$(runtime_name)"
  language="$(language_name)"
  dev_cmd="$(command_for_script dev "TODO: 待补充")"
  build_cmd="$(command_for_script build "TODO: 待补充")"
  test_cmd="$(has_npm_script test && echo "$package_manager test" || echo "TODO: 待补充")"
  lint_cmd="$(command_for_script lint "TODO: 待补充")"
  typecheck_cmd="npx tsc --noEmit"

  mkdir -p "$PROJECT_ROOT/.harness" "$PROJECT_ROOT/docs"

  write_if_changed "$PROJECT_ROOT/.harness/runtime.yml" "$(cat <<EOF
version: 1
runtime:
  dev:
    command: "$dev_cmd"
    url: "http://localhost:3000"
    health_check: "curl -sf http://localhost:3000/health"
  checks:
    lint: "$lint_cmd"
    test: "$test_cmd"
    typecheck: "$typecheck_cmd"
    build: "$build_cmd"
  logs:
    local_path: "logs/"
  ui:
    provider: "not-configured"
    base_url: "TODO: 待补充"
EOF
)"

  write_if_changed "$PROJECT_ROOT/AGENTS.md" "$(cat <<EOF
# Project Navigation

<!-- BEGIN GENERATED BLOCK — Harness Init Contract Version: v3 | Generated/Updated by: harness-init | Scope: root -->

## Repository Layout

- \`src/\` — Application source code ($language)
- \`docs/\` — Project documentation
- \`scripts/harness/\` — Harness automation scripts
- \`.harness/\` — Harness configuration

## Stack

- **Runtime**: $runtime
- **Language**: $language
- **Package Manager**: $package_manager

## Quick Commands

| Action | Command |
|--------|---------|
| Dev server | \`$dev_cmd\` |
| Build | \`$build_cmd\` |
| Test | \`$test_cmd\` |
| Lint | \`$lint_cmd\` |

## Documentation Index

- [Runtime Surface](docs/runtime-surface.md)
- [Architecture Boundaries](docs/architecture-boundaries.md)

## Harness Scripts

- \`scripts/harness/check-all.sh\` — Run all gate checks
- \`scripts/harness/check-critical.sh\` — Run critical gates only
- \`scripts/harness/score-quality.sh\` — Calculate quality score

<!-- END GENERATED BLOCK -->
EOF
)"

  write_if_changed "$PROJECT_ROOT/docs/runtime-surface.md" "$(cat <<EOF
# Runtime Surface

<!-- BEGIN GENERATED BLOCK — Harness Init Contract Version: v3 | Generated/Updated by: harness-init | Scope: root -->

## Dev Server

| Property | Value |
|----------|-------|
| Command | \`$dev_cmd\` |
| URL | http://localhost:3000 |
| Health Check | \`curl -sf http://localhost:3000/health\` |

## Checks

| Check | Command |
|-------|---------|
| Lint | \`$lint_cmd\` |
| Test | \`$test_cmd\` |
| Typecheck | \`$typecheck_cmd\` |
| Build | \`$build_cmd\` |

## Logs

- **Local path**: \`logs/\`

## UI Verification

- **Provider**: not-configured
- **Base URL**: TODO: 待补充

## Notes

- This document is auto-generated from \`.harness/runtime.yml\`
- Edit the YAML config to update runtime surface definitions
- Run \`scripts/harness/update-context-snapshot.sh\` after changes

<!-- END GENERATED BLOCK -->
EOF
)"
}

if [[ "$MODE" == "dry-run" ]]; then
  emit_plan
  exit 0
fi

init_single_node_ts
echo "pass: self-test init completed"
