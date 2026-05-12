# React Compiler Rules

Apply these rules **only** when React Compiler is confirmed to be enabled in the project.

## Detection

Check the following to determine if the project uses React Compiler:

```
# Package dependencies
babel-plugin-react-compiler    → in devDependencies or dependencies
react-compiler-runtime         → present when targeting React 17/18

# Build config integration
vite.config.*     → look for react-compiler plugin
babel.config.*    → look for babel-plugin-react-compiler in plugins
next.config.*     → look for experimental.reactCompiler flag
rspack/rsbuild    → look for compiler plugin config
```

**If none of these are found, do NOT apply [COMPILER] rules** — even if the project uses React 19.

## Verification

If DevTools are available, compiled components show a "Memo ✨" badge. This confirms the compiler is active at runtime.

## Rules for New Code

- **Do not add** `useMemo`, `useCallback`, or `React.memo` by default
- Trust the compiler to handle referential stability and re-render optimization
- Use `useMemo`/`useCallback` only when:
  - Profiling shows the compiler missed an optimization
  - Effect dependency stability explicitly requires it
  - The `"use memo"` directive is needed for specific critical sections

## Rules for Existing Code

- **Do not remove** existing `useMemo`/`useCallback`/`React.memo` automatically
- Leave manual memoization in place unless:
  - The user explicitly requests cleanup
  - Tests and profiling confirm removal is safe
  - The `"use no memo"` directive is used to opt out specific code
- The compiler is designed to work alongside existing memoization — removing it may change compiled output

## Component Purity Requirements

The compiler assumes components follow the Rules of React:

- Components and hooks must be **pure** (same inputs → same output)
- Do not **mutate** props, state, or global values during render
- Do not **read ref.current** during render
- Do not **write to refs** during render
- Side effects belong in `useEffect`, event handlers, or `useEffectEvent`

If the compiler skips a component (visible in DevTools or build logs), fix Rules of React violations rather than suppressing diagnostics.

## ESLint Integration

React Compiler diagnostics are exposed through `eslint-plugin-react-hooks`. The recommended preset includes compiler-aware rules:

- `rules-of-hooks` — hook call order
- `exhaustive-deps` — dependency correctness
- `purity` — render purity violations
- `immutability` — mutation during render
- `refs` — ref access timing
- `set-state-in-render` — setState during render
- `set-state-in-effect` — setState patterns in effects
- `static-components` — components that could be extracted

Use the hooks plugin's recommended preset when compiler is enabled:

```js
import reactHooks from 'eslint-plugin-react-hooks';

export default [
  reactHooks.configs['recommended-latest'],
];
```

## Compatibility

| React Version | Compiler Support | Notes |
|---|---|---|
| React 19+ | Full native support | Recommended target |
| React 18 | Via `react-compiler-runtime` | Add to dependencies |
| React 17 | Via `react-compiler-runtime` | Add to dependencies |
| React < 17 | Not supported | — |
