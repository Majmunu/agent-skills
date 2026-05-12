# Hooks, Effects, and Memoization Guide

## Hook Call Rules (Universal)

- All hooks must be called at the top level of a component or custom hook
- Never call hooks inside conditionals, loops, or nested functions
- Exception: [R19] `use(resource)` CAN be called conditionally — it is not a traditional hook

## Memoization Decision Matrix

### [COMPILER] React Compiler Enabled

**New code**:
- Do not add `useMemo`, `useCallback`, or `React.memo` by default
- Trust the compiler to handle referential stability

**Allowed escape hatches** (even with compiler):
- `useMemo`/`useCallback` when a memoized value is intentionally used as an Effect dependency
- Profiling shows a measurable problem the compiler missed
- A third-party component explicitly depends on stable identity
- The `"use memo"` directive is needed for critical sections

**Existing code**:
- Do NOT remove manual memoization automatically
- Preserve it unless the user explicitly requests cleanup AND tests/profiling confirm the change
- The compiler works alongside existing memoization — removing it may change compiled output
- Use `"use no memo"` directive to opt out specific code from compiler optimization

### [R18] / No Compiler

- `React.memo` — wrap child components that receive the same props frequently and are expensive to render. Profile first
- `useMemo` — for expensive computations only (O(n²)+ operations, large data transforms). Not for simple object creation
- `useCallback` — only for handlers passed to `React.memo`'d children or used as effect dependencies
- Do not add memo "just in case" — it adds complexity and can mask bugs

## Effects

### When to Use `useEffect`

Correct uses:
- Synchronize with external systems (DOM APIs, third-party widgets, network subscriptions)
- Set up and tear down event listeners, observers, timers
- Fetch data as last resort when no better abstraction exists (see Data Fetching in SKILL.md)

Incorrect uses (anti-patterns):
- Computing derived state — compute during render instead
- Resetting state on prop change — use `key` prop instead
- Transforming data for display — compute inline or with `useMemo`
- Notifying parent of state changes — call during event handler instead
- Initializing global singletons — use module-level code or lazy init

### Effect Cleanup

Every `useEffect` with subscriptions/timers/observers MUST return a cleanup function:

```tsx
useEffect(() => {
  const controller = new AbortController();
  fetchData(controller.signal);
  return () => controller.abort();
}, [fetchData]);
```

### [R19] Ref Callback Cleanup

React 19 supports returning a cleanup function from ref callbacks:

```tsx
<div ref={(node) => {
  const observer = new IntersectionObserver(callback);
  observer.observe(node);
  return () => observer.disconnect(); // cleanup
}} />
```

When a cleanup is returned, React will NOT call the ref with `null` on unmount.

### [R19] `useEffectEvent`

Use when an Effect needs to read the latest props/state without re-subscribing:

```tsx
const onTick = useEffectEvent(() => {
  console.log(count); // always reads latest count
});

useEffect(() => {
  const id = setInterval(onTick, 1000);
  return () => clearInterval(id);
}, []); // no need to include count in deps
```

Rules:
- Call `useEffectEvent` at component/hook top level
- Call the returned function only inside Effects or other Effect Events
- Do NOT include Effect Event functions in dependency arrays
- Do NOT pass to children as event handlers (use regular callbacks for that)
- Do NOT use to hide real dependencies — only for "event-like" logic inside effects

### `exhaustive-deps`

- Respect the project's ESLint config setting
- If set to `error`: never suppress without a structural fix
- If set to `warn`: a documented `// eslint-disable-next-line` with reason is acceptable when the alternative is worse
- If not configured: treat as `warn` (best practice default)

## [R19] `use(resource)`

```tsx
const value = use(promise); // or use(context)
```

Allowed:
- Can be called conditionally (unlike other hooks)
- Can be called in loops
- Must be called inside a component or hook

Not allowed:
- Do NOT call inside `try`/`catch`
- Do NOT create a new Promise on every render (must have stable reference)

Preferred patterns:
- In Server Components, prefer `async`/`await` over `use(promise)`
- Create Promises in Server Components and pass stable references to Client Components
- Wrap with `<Suspense>` for pending state
- Use Error Boundaries for rejected Promises
