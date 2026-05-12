#!/usr/bin/env bash
# check-secrets.sh — Detect potential secret leaks in the repository
# Usage: bash scripts/harness/check-secrets.sh [--strict]
#
# Checks:
# 1. .env files tracked by git
# 2. Common token patterns (API keys, JWT, Bearer tokens)
# 3. Private key patterns (RSA, EC, SSH)
# 4. Hardcoded tokens in CI configs
#
# Output: pass/fail/warn with structured failure info
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

errors=0
warnings=0

emit_fail() {
  local gate="$1" reason="$2" evidence="$3" fix="$4" docs="$5"
  echo "FAIL: $gate"
  echo "Reason: $reason"
  echo "Evidence: $evidence"
  echo "Fix: $fix"
  echo "Docs: $docs"
  echo "Bypass: not allowed"
  echo ""
  errors=$((errors + 1))
}

emit_warn() {
  local gate="$1" reason="$2" evidence="$3" fix="$4" docs="$5"
  echo "warn: $gate"
  echo "Reason: $reason"
  echo "Evidence: $evidence"
  echo "Fix: $fix"
  echo "Docs: $docs"
  echo ""
  warnings=$((warnings + 1))
}

cd "$REPO_ROOT"

# --- Check 1: .env files tracked by git ---
echo "── Check: .env files tracked by git ──"
ENV_FILES=$(git ls-files '*.env' '.env' '.env.*' 2>/dev/null || true)
if [ -n "$ENV_FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    emit_fail "check-secrets:env-tracked" \
      ".env file is tracked by git" \
      "$f" \
      "Add '$f' to .gitignore and run: git rm --cached '$f'" \
      "docs/security-threat-model.md"
  done <<< "$ENV_FILES"
else
  echo "pass: no .env files tracked by git"
fi

# --- Check 2: Common token patterns ---
echo ""
echo "── Check: Common token patterns ──"
# Patterns to detect (simplified but effective)
TOKEN_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                    # AWS Access Key
  'sk-[a-zA-Z0-9]{20,}'                 # OpenAI/Stripe secret key
  'ghp_[a-zA-Z0-9]{36}'                 # GitHub personal access token
  'glpat-[a-zA-Z0-9\-]{20,}'            # GitLab personal access token
  'xox[baprs]-[a-zA-Z0-9\-]+'           # Slack token
  'eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.' # JWT token
)

SCAN_DIRS=()
[ -d ".github" ] && SCAN_DIRS+=(".github")
[ -d ".gitlab-ci.yml" ] && SCAN_DIRS+=(".gitlab-ci.yml")
[ -f ".gitlab-ci.yml" ] && SCAN_DIRS+=(".gitlab-ci.yml")

# Scan tracked files (exclude binary, node_modules, etc.)
TOKEN_FOUND=false
for pattern in "${TOKEN_PATTERNS[@]}"; do
  MATCHES=$(git grep -lnE "$pattern" -- ':(exclude)*.lock' ':(exclude)node_modules' ':(exclude)dist' ':(exclude)build' ':(exclude)vendor' 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    TOKEN_FOUND=true
    while IFS= read -r match; do
      [ -z "$match" ] && continue
      emit_fail "check-secrets:token-pattern" \
        "Potential secret/token pattern detected" \
        "$match (pattern: $pattern)" \
        "Remove the token from source code and use environment variables instead" \
        "docs/security-threat-model.md"
    done <<< "$MATCHES"
  fi
done

if [ "$TOKEN_FOUND" = false ]; then
  echo "pass: no common token patterns detected"
fi

# --- Check 3: Private key patterns ---
echo ""
echo "── Check: Private key patterns ──"
KEY_PATTERNS=(
  '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
  '-----BEGIN PGP PRIVATE KEY BLOCK-----'
)

KEY_FOUND=false
for pattern in "${KEY_PATTERNS[@]}"; do
  MATCHES=$(git grep -lnE "$pattern" -- ':(exclude)*.lock' ':(exclude)node_modules' ':(exclude)dist' ':(exclude)vendor' ':(exclude)*.example' ':(exclude)*.sample' 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    KEY_FOUND=true
    while IFS= read -r match; do
      [ -z "$match" ] && continue
      emit_fail "check-secrets:private-key" \
        "Private key file detected in repository" \
        "$match" \
        "Remove the private key from the repository, rotate the key, and add the file to .gitignore" \
        "docs/security-threat-model.md"
    done <<< "$MATCHES"
  fi
done

if [ "$KEY_FOUND" = false ]; then
  echo "pass: no private key patterns detected"
fi

# --- Check 4: Hardcoded tokens in CI configs ---
echo ""
echo "── Check: Hardcoded tokens in CI configs ──"
CI_FILES=""
[ -f ".gitlab-ci.yml" ] && CI_FILES="$CI_FILES .gitlab-ci.yml"
[ -d ".github/workflows" ] && CI_FILES="$CI_FILES $(find .github/workflows -name '*.yml' -o -name '*.yaml' 2>/dev/null | tr '\n' ' ')"

CI_TOKEN_FOUND=false
if [ -n "$CI_FILES" ]; then
  for ci_file in $CI_FILES; do
    [ -z "$ci_file" ] && continue
    [ ! -f "$ci_file" ] && continue
    # Check for hardcoded values (not using ${{ secrets.* }} or env vars)
    HARDCODED=$(grep -nE '(token|password|secret|api_key|apikey)\s*[:=]\s*["\x27][^${\x27"]+["\x27]' "$ci_file" 2>/dev/null | grep -viE '(TODO|待补充|\$\{\{|secrets\.)' || true)
    if [ -n "$HARDCODED" ]; then
      CI_TOKEN_FOUND=true
      emit_fail "check-secrets:ci-hardcoded" \
        "Potential hardcoded token in CI configuration" \
        "$ci_file: $HARDCODED" \
        "Replace hardcoded values with CI secret variables (e.g., \${{ secrets.TOKEN_NAME }})" \
        "docs/security-threat-model.md"
    fi
  done
fi

if [ "$CI_TOKEN_FOUND" = false ]; then
  echo "pass: no hardcoded tokens in CI configs"
fi

# --- Summary ---
echo ""
echo "── Summary ──"
if [ $errors -gt 0 ]; then
  echo "fail: check-secrets ($errors issue(s) found, $warnings warning(s))"
  exit 1
elif [ $warnings -gt 0 ]; then
  echo "warn: check-secrets ($warnings warning(s))"
  exit 0
else
  echo "pass: check-secrets (all checks passed)"
  exit 0
fi
