# Code Review Output Format

When reviewing React code, structure the output as follows:

## 1. Environment Detected

```
React version:       18.x / 19.x
Framework:           Next.js App Router / Vite SPA / React Router / Remix / etc.
Rendering model:     RSC / SPA / SSG
React Compiler:      enabled / not found / unknown
TypeScript:          strict / non-strict / not found
ESLint config:       found (flat/legacy) / not found
Prettier config:     found / not found
Test framework:      Vitest / Jest / Testing Library / Playwright / none found
CSS methodology:     CSS Modules / Tailwind / styled-components / etc.
Existing patterns:   scanned N files — conventions noted
```

## 2. Must Fix

Correctness, runtime bugs, Hook rule violations, type safety, security vulnerabilities, accessibility blockers.

Each item:
```
[MUST] <file>:<line> — <brief description>
  Reason: <why this is a correctness/safety issue>
  Fix: <concrete code change>
```

## 3. Should Fix

Maintainability, duplicated logic, weak typing (`any`), missing error handling, unclear module boundaries, missing tests for critical paths.

Each item:
```
[SHOULD] <file>:<line> — <brief description>
  Reason: <why this improves maintainability>
  Suggestion: <concrete improvement>
```

## 4. Nice to Have

Style consistency, naming improvements, small readability optimizations, comment additions.

Each item:
```
[NICE] <file>:<line> — <brief description>
```

## 5. Suggested Patch

When possible, provide concrete code changes (diff format or full replacement). Group by file.

## 6. Validation Status

```
Commands run:
  - pnpm lint        → ✅ passed / ❌ N errors / ⏭️ not run
  - pnpm typecheck   → ✅ passed / ❌ N errors / ⏭️ not run
  - pnpm test        → ✅ passed / ❌ N failures / ⏭️ not run
  - pnpm build       → ✅ passed / ❌ failed / ⏭️ not run
```

**Rules**:
- Only mark as "passed" if the command was actually executed and succeeded
- If unable to run commands, mark as "⏭️ not run" with reason
- **Never claim a command was run if it was not**

## Example Output

```
### Environment
React 19.2, Next.js 15 App Router, TypeScript strict, ESLint flat config found,
React Compiler enabled, CSS Modules

### Must Fix
[MUST] UserCard.tsx:42 — useEffect missing cleanup for event listener
  Reason: Memory leak on unmount
  Fix: return () => window.removeEventListener('resize', handler)

### Should Fix
[SHOULD] useAuth.ts:15 — Return type is `any`
  Reason: Consumers lose type safety
  Suggestion: Define explicit AuthState return type

### Nice to Have
[NICE] UserCard.tsx:8 — Handler could be named `handleProfileClick` instead of `click`

### Validation
  - pnpm lint       → ✅ passed
  - pnpm typecheck  → ❌ 2 errors (fixed above)
  - pnpm test       → ⏭️ not run (no test files found)
  - pnpm build      → ⏭️ not run
```
