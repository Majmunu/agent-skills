---
name: react-code-standards
description: >
  Enforce React project coding standards when generating, reviewing, or refactoring
  React/TypeScript code. Supports React 18, React 19+, and React Compiler. Use when:
  (1) creating new React components, hooks, or pages, (2) reviewing or refactoring
  existing React code, (3) setting up project structure or ESLint config, (4) writing
  tests for React components, or (5) any task that produces .tsx/.ts files in a React
  codebase. Covers code quality, naming, component design, hooks, TypeScript, state
  management, testing, and performance. Reads project-local configs first; falls back
  to built-in references.
---

# React Code Standards (2026-05)

Apply these standards as guidelines. Project-local configs take precedence; fix violations against the applicable config before delivery.

## Environment Detection

Before generating code, detect the project environment:

1. **React version**: `package.json` → `dependencies.react` → React 18 or 19+
2. **React Compiler**: Check for `babel-plugin-react-compiler` in deps or build config (`vite.config.*`, `babel.config.*`, `next.config.*`). **React 19 alone does NOT mean Compiler is enabled**
3. **Framework**: Next.js (App Router / Pages Router), Vite SPA, React Router, Remix, Expo, etc.
4. **Rendering model**:
   - **RSC-capable**: Next.js App Router, any framework with server component support → apply [RSC] rules
   - **Client-only SPA**: Vite SPA, CRA, React Router (client-only), standalone React → apply [SPA] rules
   - When uncertain, default to [SPA] (safer — avoids recommending server-only APIs in client code)
5. **Toolchain configs**: Read and respect ALL project-local config files:

| Config | Files to Check |
|---|---|
| TypeScript | `tsconfig.json`, `tsconfig.app.json`, `tsconfig.node.json` |
| ESLint | `eslint.config.js`, `.eslintrc.*`, `package.json#eslintConfig` |
| Prettier | `.prettierrc`, `.prettierrc.*`, `prettier.config.*`, `package.json#prettier` |
| Stylelint | `.stylelintrc`, `.stylelintrc.*`, `stylelint.config.*` |
| EditorConfig | `.editorconfig` |
| Package Manager | `pnpm-workspace.yaml`, `.npmrc`, `yarn.lock` / `pnpm-lock.yaml` |
| Build Tool | `vite.config.*`, `next.config.*`, `webpack.config.*` |

6. **Existing patterns**: On first encounter with a project, scan 3+ existing components to establish conventions. On subsequent interactions, reuse established patterns unless the user indicates a change

### Config Priority (highest → lowest)

| Priority | Source | Action |
|---|---|---|
| 1 | Project's own config files | Follow exactly |
| 2 | Existing code patterns | Match style (see caveat) |
| 3 | This skill's reference standards | Apply as supplement only |

**Never override project-local configs.** Match existing patterns for formatting and style choices. Do NOT match existing anti-patterns (`any` usage, broken naming, missing error handling) — apply quality rules instead.

### Version & Feature Markers

| Marker | Meaning | Detection |
|---|---|---|
| [R18] | React 18 runtime/API | `react` version in package.json |
| [R19] | React 19+ runtime/API | `react` version in package.json |
| [COMPILER] | React Compiler enabled | `babel-plugin-react-compiler` in deps/config |
| [RSC] | Server Components / server-capable framework | Next.js App Router, framework with server rendering |
| [SPA] | Client-only SPA | Vite SPA, CRA, React Router client-only, no server runtime |

**Critical distinctions — do not conflate**:
- [R19] does NOT imply [COMPILER]. React Compiler is a separate build tool that must be explicitly installed and configured. Apply [COMPILER] rules only when compiler presence is confirmed. See [references/react-compiler.md](references/react-compiler.md).
- [R19] does NOT imply [RSC]. A React 19 Vite SPA has no Server Components.
- [RSC] does NOT imply all components are server components. Client Components (`"use client"`) still follow client-side rules.

## Core Rules

### Size Limits

Fallback defaults; project-local ESLint rules override when present.

| Metric | Soft | Hard | Action |
|---|---|---|---|
| Component file | 150 lines | 250 | Extract sub-components or hooks |
| Hook file | 120 lines | 200 | Split into smaller hooks |
| Utility file | 80 lines | 150 | Split by domain |
| Function body | 40 lines | 50 | Extract helpers |
| JSX depth | 4 levels | 6 | Extract sub-components |
| Props count | 5 | 8 | Use composition or object props |
| useEffect count | 2 | 3 | Extract to custom hook |

Do not exceed hard limits unless the project's ESLint config explicitly allows higher values.

### Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Component | PascalCase | `UserProfile`, `DataGrid` |
| Hook | `use` + camelCase | `useAuth`, `useUserSession` |
| Handler prop | `on` + verb | `onClick`, `onFilterChange` |
| Handler impl | `handle` + verb | `handleClick`, `handleSubmit` |
| Boolean | `is`/`has`/`should` | `isVisible`, `hasError` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Type / Interface | PascalCase | `UserProfileProps` |
| Context | PascalCase + `Context` | `AuthContext` |

Name after **what it provides**, not how it works. Avoid generic names: `data`, `info`, `item`, `temp`.

### Component Design

- One component per file for exported components
- Function declarations preferred; arrow expressions also acceptable — match project style
- Prefer named exports for reusable components. Respect existing project convention. Framework-required default exports (`page.tsx`, `layout.tsx`, `route.tsx`) are always acceptable
- No nested component definitions inside render (causes remount every render)
- No index as key for dynamic lists — use stable unique IDs from data (`key={item.id}`)
- [R18] Avoid inline object/function in JSX props **only when** passed to memoized children, Context values, or effect dependencies. Otherwise prefer readability
- [COMPILER] Inline objects/functions are auto-optimized; only refactor for readability

### Hooks

- All hooks at top of component, before conditionals
- Custom hooks MUST start with `use` and return typed values
- [R18] `useCallback` only for handlers passed to `React.memo`'d children. `useMemo` only for expensive computations. Profile before adding
- [COMPILER] New code: do not add manual memo by default. Existing code: do not remove automatically — leave unless user requests cleanup and profiling supports it
- [R19] `useActionState` and `useFormStatus` for form mutations
- [R19] `useOptimistic` for optimistic UI updates
- [R19] `use(promise)` — **CAN** be called in conditionals/loops (unlike other hooks). Promise must have stable reference. Cannot be in `try-catch`. Wrap with `<Suspense>`. In Server Components prefer `async`/`await`
- [R19] `useEffectEvent` — use when an Effect needs latest props/state without re-subscribing. Do not call during render; do not pass to children as event handler
- [R19] `ref` as prop — new components can accept ref directly; `forwardRef` no longer needed. Do not migrate existing `forwardRef` unless user requests
- Prefer `useReducer` when state transitions depend on previous state or follow state-machine patterns. For independent booleans, `useState` is simpler
- Respect project-local `exhaustive-deps` setting. If `error`, never suppress. If `warn`, a documented disable with reason is acceptable when the alternative is worse

### Data Fetching

Follow the project's existing data layer first. Do not introduce new data-fetching libraries unless already used or explicitly requested.

1. **Project has an existing data layer** → follow it. Do not add TanStack Query / SWR / Apollo if not already present
2. [RSC] **Server-capable framework** → prefer Server Components, route loaders, server functions. Use Client Components only for interactive UI
3. [SPA] **Client-only app** → prefer the project's existing data abstraction. If none exists, recommend TanStack Query / SWR / React Router loaders for server-state
4. `useEffect` is acceptable for external synchronization and last-resort client-side fetching. Do not use it to duplicate derived state or synchronize values computable during render

### TypeScript

- **Project has tsconfig**: follow its settings, do not override
- **No tsconfig (fallback)**: recommend `strict: true`, `noUncheckedIndexedAccess: true`
- Avoid `any` — use `unknown` + narrowing or generics. If neither tsconfig strict nor ESLint `no-explicit-any` is present, treat as best-practice guideline rather than hard block
- Avoid `as` assertions unless necessary and commented with reason
- Use project's convention for props typing (`interface` vs `type`). If none: both acceptable — `interface` for simple object shapes, `type` for unions/intersections/mapped types

### State Management

1. **UI-local** → `useState` / `useReducer`
2. **Server data** → project's existing data layer, TanStack Query, SWR, or RSC
3. **Shared state** → Context (infrequent changes) or Zustand / Jotai (frequent changes)
4. **Form state** → [R19] Actions API; [R18] React Hook Form or manual
5. **URL state** (filters, pagination, tabs) → router hooks (`useSearchParams`, `useLocation`). Prefer URL over `useState` for shareable/persistent state

### Error Handling

- Error Boundaries for component crash recovery: [R18] & [R19] must be class components. Use `react-error-boundary` for hook-friendly API. [R19] Actions propagate errors to nearest boundary automatically
- Wrap async ops in try/catch with typed errors
- Never swallow errors silently
- Forms: inline validation errors, not alerts

### Refs & Effect Cleanup

- Refs: DOM access and mutable values that don't trigger re-render. Do NOT read/write `ref.current` during render
- [R19] Ref callback cleanup: return cleanup function from ref callback (replaces `useEffect` for observer patterns). When cleanup is returned, React will not call ref with `null`
- Every `useEffect` with subscriptions/timers/observers MUST return a cleanup function
- React 19 did NOT change `useEffect` cleanup timing — same as React 18

### Performance

- [COMPILER] Trust automatic memoization; do not add manual memo by default
- [R18] Profile before adding `React.memo`/`useMemo`/`useCallback`
- [R18] Code-split routes with `React.lazy()` + `Suspense`
- [R19] Server Components are naturally code-split; `React.lazy()` only for Client Components
- Images: `next/image` or `loading="lazy"` + explicit dimensions

### Security

- Never use `dangerouslySetInnerHTML` unless explicitly required; sanitize input first
- Do not log tokens, cookies, authorization headers, or personal data
- Validate API boundary data with project's schema tools (zod / io-ts / valibot) if present
- Do not add new dependencies without checking existing project stack
- Keep secrets in env files; never hardcode keys

### Accessibility

- Semantic HTML first (`<button>`, `<nav>`, `<main>`, `<section>`)
- All interactive elements keyboard-accessible
- Images: meaningful `alt` or `alt=""` for decorative
- Form inputs: associated `<label>`
- ARIA only when semantic HTML is insufficient

### Styling

Respect project's CSS methodology. If no convention exists, recommend CSS Modules.

### Imports & Exports

- Import order: react → external → internal → relative → types → styles
- Named exports preferred for reusable code. Respect project convention — do not rewrite export style unless explicitly requested. Framework-required default exports are always acceptable
- Feature barrel `index.ts` only for stable public API. Do not create barrels automatically unless project already uses them. Avoid barrel chains that increase circular dependency risk
- `export type { X }` for type-only exports

## Code Review Mode

When reviewing code, follow the output format in [references/review-output.md](references/review-output.md).

## Quality Gate

Before delivering code:

- Identify available scripts from `package.json`
- Prefer running the project's own commands: `lint`, `typecheck`, `test`, `build`
- If unable to run commands, state that validation was not executed
- **Never claim a command was run if it was not**
- Follow project coverage thresholds. If none exist, prioritize meaningful coverage for critical business flows over arbitrary percentages

## Testing

See [references/testing.md](references/testing.md) for detailed patterns.

Quick rules:
- Colocate tests next to source files
- Use React Testing Library; test behavior, not implementation
- Mock network/external deps; never mock React internals
- Cover: happy path, error states, edge cases, accessibility

## References

| File | Content |
|---|---|
| [react-compiler.md](references/react-compiler.md) | React Compiler detection and rules |
| [hooks-and-effects.md](references/hooks-and-effects.md) | Hooks, effects, and memoization decision guide |
| [review-output.md](references/review-output.md) | Code review output format |
| [eslint-config.md](references/eslint-config.md) | ESLint flat config fallback template |
| [testing.md](references/testing.md) | Testing standards and patterns |
| [project-structure.md](references/project-structure.md) | Feature-based architecture template |

## Toolchain Configuration (Project-Local First)

**All toolchain configs: read project-local files first. Skill references are fallback only.**

- **TypeScript**: Read `tsconfig.json` → respect its settings exactly
- **ESLint**: Read project config → follow, don't contradict. No config → use [eslint-config.md](references/eslint-config.md)
- **Prettier**: Read `.prettierrc` → match formatting exactly. Fallback: `printWidth: 100`, `singleQuote: true`, `trailingComma: 'all'`, `semi: true`, `tabWidth: 2`
- **Stylelint**: Read `.stylelintrc` → follow CSS rules
- **EditorConfig**: Read `.editorconfig` → respect indent/encoding
- **Project Structure**: Analyze existing first. Never reorganize without approval. No convention → see [project-structure.md](references/project-structure.md)
