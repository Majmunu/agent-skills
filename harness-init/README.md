# harness-init

> Agent-readable engineering harness — 为任意项目初始化并持续维护智能体可驾驶的工程治理系统。

[![Agent Skill](https://img.shields.io/badge/agent--skill-v4.0.0-blue)](https://agentskills.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## What is this?

`harness-init` is an [Agent Skill](https://agentskills.io) that bootstraps and continuously maintains an engineering harness for AI coding agents (Claude Code, Codex, Cursor, etc.).

Inspired by OpenAI's [Harness Engineering](https://openai.com/index/harness-engineering/) approach: instead of stuffing everything into prompts, encode knowledge, constraints, and feedback loops into the repository itself.

## Key Capabilities

- **Navigation**: Generate AGENTS.md / CLAUDE.md as concise entry points (not encyclopedias)
- **Documentation**: Scaffold canonical docs with architecture boundaries, exec plans, ADRs
- **Quality Gates**: Executable checks for secrets, permissions, placeholders, alias integrity
- **Quality Score**: 7-dimension scoring (100 points) with mode/autonomy recommendations
- **Worktree Sandbox**: Isolated git worktree execution for agent tasks
- **UI Verification**: DOM snapshot, screenshot, console error detection
- **Observability**: Programmatic log/metric/trace queries (file, Loki, Prometheus, Tempo)
- **Context Snapshot**: Session-resumable project state summary
- **Subagent Workflows**: Routable review workflows with rubrics and routing rules
- **Integrations**: GitLab, YouTrack, MCP templates (env-var only, no real tokens)
- **Security**: Threat model, secret detection, permission boundary enforcement
- **CI Templates**: GitHub Actions + GitLab CI with bootstrap/enforced dual-track
- **PowerShell Fallback**: Degraded-mode scripts for Windows/no-bash environments
- **Self-Test**: 8 fixture scenarios + golden tests + idempotency assertions

## Install

```bash
# Clone into your skills directory
git clone https://github.com/Majmunu/agent-skills.git
cd agent-skills/harness-init

# Or for Codex CLI
codex install harness-init
```

## Usage

Tell your AI agent:

```
harness init
```

Or for specific scopes:

```
harness init scope=apps/editor
```

The agent reads `SKILL.md`, loads references on demand, and executes Steps 0-9.

## After Initialization

The harness continues working:

```bash
# Score project quality
bash scripts/harness/score-quality.sh

# Update context snapshot
bash scripts/harness/update-context-snapshot.sh

# Check for secret leaks
bash scripts/harness/check-secrets.sh

# Run all gates
bash scripts/harness/check-all.sh

# Repair drift
# Tell agent: "harness repair"
```

## Project Structure

```
harness-init/
├── SKILL.md              # Entry point (95 lines — table of contents)
├── references/           # 27 reference docs (loaded on demand)
├── scripts/harness/      # 25 executable gate/utility scripts
├── templates/            # Files deployed to target projects
│   ├── .harness/         # Config templates (runtime, scorecard, etc.)
│   ├── .github/          # GitHub Actions CI template
│   ├── gitlab-ci/        # GitLab CI template
│   ├── scripts/harness/  # Script templates for target projects
│   └── scripts/harness-pwsh/  # PowerShell fallback scripts
├── fixtures/             # 8 test scenarios
├── tests/                # Assertion scripts + golden baselines
└── subagents/            # Routing rules, workflows, review rubrics
```

## Design Principles

1. **Map, not encyclopedia** — SKILL.md is 95 lines. Details live in references/.
2. **Idempotent** — Run twice, get the same result. No duplicate markers.
3. **Honest status** — Only `pass`/`fail`/`warn`/`not-run`. Never fake success.
4. **Actionable failures** — Every gate failure includes Reason/Evidence/Fix/Docs/Bypass.
5. **Incremental** — Read → compare → patch/append. Never overwrite user content.
6. **Monorepo-safe** — Root navigation stays global. Project commands stay local.

## Scoring Dimensions

| Dimension | Points | What it measures |
|-----------|--------|-----------------|
| context_readability | 20 | Navigation clarity, docs discoverability |
| plan_discipline | 15 | ExecPlan lifecycle, PR/issue linking |
| architecture_enforcement | 20 | Executable boundary checks |
| test_confidence | 15 | Test coverage, fixtures, CI reliability |
| observability_surface | 15 | Logs/metrics/traces/UI readability |
| entropy_control | 10 | Doc gardening, drift detection |
| autonomy_readiness | 5 | L1-L4 strategy, approval, rollback |

## License

MIT
