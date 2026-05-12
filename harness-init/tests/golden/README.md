# Golden Test Baselines

## Overview

This directory contains **golden baseline files** — the expected output of `harness-init` when run against each fixture scenario. The golden test approach compares the actual generated output against these pre-approved baselines to detect unintended regressions in template generation.

## How It Works

1. `tests/assert-golden.sh` runs `harness-init` against a fixture (or receives the generated output directory)
2. The script compares each file in `tests/golden/<fixture-name>/` against the corresponding file in the generated output
3. **Timestamps**, **dynamic IDs**, and other non-deterministic content are normalized before comparison
4. If any file differs, the test outputs `FAIL` with the specific diff, file path, and line numbers

## Directory Structure

```
tests/golden/
├── README.md                    # This file
└── single-node-ts/              # Baseline for single-node-ts fixture
    ├── AGENTS.md                # Expected navigation file
    ├── .harness/
    │   └── runtime.yml          # Expected runtime config
    └── docs/
        └── runtime-surface.md   # Expected runtime surface doc
```

## Updating Baselines

When a template change is intentional, update the baselines:

```bash
tests/assert-golden.sh <generated-output-dir> tests/golden/<fixture-name> --update
```

This copies the current generated output into the golden directory, replacing the old baselines.

## What Gets Compared

- All files present in the golden baseline directory are compared against the generated output
- Files in the generated output that are NOT in the golden baseline are ignored (allows incremental baseline coverage)
- Comparison ignores:
  - Timestamps (ISO 8601 patterns, `Last Updated:` lines)
  - Dynamic IDs (UUIDs, random hashes)
  - Trailing whitespace differences

## Adding a New Fixture Baseline

1. Run `harness-init` against the fixture to produce output
2. Review the output manually to confirm correctness
3. Copy the relevant files to `tests/golden/<fixture-name>/`
4. Or use: `tests/assert-golden.sh <output-dir> tests/golden/<fixture-name> --update`

## Requirements Traceability

- **Requirement 24.1**: Maintain golden baselines in `tests/golden/`
- **Requirement 24.2**: Diff comparison via `tests/assert-golden.sh`
- **Requirement 24.3**: Output fail with diff content, file paths, line numbers
- **Requirement 24.4**: `--update` flag to refresh baselines
- **Requirement 24.5**: Ignore timestamps and dynamic IDs
