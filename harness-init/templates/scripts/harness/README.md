# Harness Scripts Templates

> Harness Init Contract Version: v3
> Generated/Updated by: harness-init

This directory contains template versions of all harness scripts that will be deployed to target projects during `harness-init`.

## Scripts

These scripts are copied to the target project's `scripts/harness/` directory during initialization.

### Core Gates
- `check-all.sh` — Aggregate all checks
- `check-critical.sh` — Bootstrap critical minimum blocking surface
- `check-placeholders.sh` — Angle-bracket and TODO placeholder detection
- `check-alias-integrity.sh` — Legacy docs alias-only verification
- `check-wrapper-integrity.sh` — Legacy scripts wrapper-only verification
- `check-secrets.sh` — Secret/token leak detection
- `check-permissions.sh` — Permission boundary and approval policy verification

### Quality & Observability
- `score-quality.sh` — 7-dimension quality scoring
- `query-logs.sh` — Log query (file/Loki/VictoriaLogs/Elastic)
- `query-metrics.sh` — Metrics query (Prometheus/VictoriaMetrics)
- `query-traces.sh` — Trace query (Jaeger/Tempo/OTel)

### Runtime & Worktree
- `worktree-create.sh` — Create isolated git worktree
- `worktree-run.sh` — Execute command in worktree
- `worktree-clean.sh` — Clean worktree safely
- `worktree-status.sh` — Show worktree status

### UI Verification
- `capture-dom.sh` — DOM snapshot capture
- `capture-screenshot.sh` — Page screenshot capture
- `check-console.sh` — Console error detection
- `verify-user-journey.sh` — Critical user journey execution

### Context & Integration
- `update-context-snapshot.sh` — Update context snapshot
- `sync-issues.sh` — Sync issue tracker status
- `link-plan-to-issue.sh` — Link ExecPlan to issue
- `fetch-review-context.sh` — Fetch MR/PR review context
- `create-merge-request.sh` — Create MR with plan link

## Deployment

During `harness-init`, these templates are copied to the target project. Existing scripts are NOT overwritten — only missing scripts are added (idempotent).
