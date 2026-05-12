# React Project Structure — Fallback Template

> **This is a fallback reference for projects without an established folder structure.**
> If your project already follows a convention, match that instead.
> Never reorganize existing project structure without explicit user approval.

## Table of Contents
- [Feature-Based Architecture](#feature-based-architecture)
- [Next.js App Router Example](#nextjs-app-router-example)
- [SPA / Vite Example](#spa--vite-example)
- [Shared Layers](#shared-layers)
- [File Naming](#file-naming)
- [Barrel Exports](#barrel-exports)
- [Dependency Direction](#dependency-direction)

## Feature-Based Architecture

Organize by **business domain**, not by file type.

The examples below show two common setups. Adapt the `app/` or `pages/` layer to your
framework; the `features/`, `components/`, `hooks/`, `lib/`, `types/` layers are universal.

## Next.js App Router Example

```
src/
├── app/                        # Next.js App Router
│   ├── (auth)/
│   │   ├── login/
│   │   │   └── page.tsx
│   │   └── register/
│   │       └── page.tsx
│   ├── dashboard/
│   │   ├── page.tsx
│   │   ├── loading.tsx
│   │   └── error.tsx
│   ├── layout.tsx
│   └── globals.css
│
├── features/                   # (shared structure — see below)
├── components/
├── hooks/
├── lib/
├── types/
├── constants/
└── styles/
```

## SPA / Vite Example

```
src/
├── pages/                      # Route-level components (SPA)
│   ├── LoginPage.tsx
│   ├── RegisterPage.tsx
│   ├── DashboardPage.tsx
│   └── NotFoundPage.tsx
│
├── router/                     # Router config (react-router, etc.)
│   └── index.tsx
│
├── features/                   # Domain-specific modules
│   ├── auth/
│   │   ├── components/
│   │   │   ├── LoginForm.tsx
│   │   │   ├── LoginForm.test.tsx
│   │   │   └── LoginForm.module.css
│   │   ├── hooks/
│   │   │   ├── useAuth.ts
│   │   │   └── useAuth.test.ts
│   │   ├── utils/
│   │   │   └── validateCredentials.ts
│   │   ├── types/
│   │   │   └── auth.types.ts
│   │   ├── constants/
│   │   │   └── auth.constants.ts
│   │   └── index.ts            # Public API barrel
│   │
│   ├── products/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── types/
│   │   └── index.ts
│   │
│   └── orders/
│       ├── components/
│       ├── hooks/
│       ├── types/
│       └── index.ts
│
├── components/                 # Shared UI components (design system)
│   ├── ui/
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   ├── Modal.tsx
│   │   └── index.ts
│   └── layout/
│       ├── Header.tsx
│       ├── Sidebar.tsx
│       └── index.ts
│
├── hooks/                      # Shared hooks (cross-feature)
│   ├── useMediaQuery.ts
│   ├── useDebounce.ts
│   └── index.ts
│
├── lib/                        # Framework / library wrappers
│   ├── api.ts                  # HTTP client setup
│   ├── auth.ts                 # Auth utilities
│   └── query-client.ts         # TanStack Query client
│
├── types/                      # Global types
│   ├── api.types.ts
│   └── common.types.ts
│
├── constants/                  # Global constants
│   └── config.ts
│
├── styles/                     # Global styles / tokens
│   ├── tokens.css
│   └── reset.css
│
├── App.tsx                     # Root component
└── main.tsx                    # Entry point
```

## Shared Layers

| Layer | Path | Purpose | Import Rule |
|---|---|---|---|
| `components/` | `@/components/*` | Reusable UI primitives | No feature imports |
| `hooks/` | `@/hooks/*` | Cross-feature hooks | No feature imports |
| `lib/` | `@/lib/*` | Library wrappers | No component/feature imports |
| `types/` | `@/types/*` | Global types | No runtime imports |
| `constants/` | `@/constants/*` | App-wide constants | No runtime imports |

## File Naming

| Category | Convention | Example |
|---|---|---|
| Component | PascalCase `.tsx` | `UserCard.tsx` |
| Hook | camelCase with `use` `.ts` | `useAuth.ts` |
| Utility | camelCase `.ts` | `formatDate.ts` |
| Type definition | camelCase `.types.ts` | `auth.types.ts` |
| Constants | camelCase `.constants.ts` | `api.constants.ts` |
| Test | mirror + `.test.tsx/ts` | `UserCard.test.tsx` |
| Style module | mirror + `.module.css` | `UserCard.module.css` |
| Barrel | `index.ts` | `index.ts` |

## Barrel Exports (Optional)

Use barrel `index.ts` only for features with a **stable public API** that other features consume. Do not create barrels automatically unless the project already uses them.

```tsx
// features/auth/index.ts — only if other features import from auth
export { LoginForm } from './components/LoginForm';
export { useAuth } from './hooks/useAuth';
export type { AuthUser, AuthSession } from './types/auth.types';
```

Rules:
- Only export what other features actually need
- Internal implementation details stay private
- Never re-export third-party libraries from barrels
- Keep barrels flat (no barrel importing another barrel)
- Avoid global barrels that re-export all features — causes circular dependency and tree-shaking issues

## Dependency Direction

Strict unidirectional dependency flow:

```
app/ or pages/  →  features/*  →  components/  →  (no upward imports)
(routing layer)                →  hooks/
                               →  lib/
                               →  types/
                               →  constants/
```

> `app/` = Next.js App Router; `pages/` = SPA routing layer (react-router, etc.)

Rules:
- **features/ cannot import runtime code from other features/** — extract shared logic to `components/`, `hooks/`, or `lib/`. However, **`import type` from another feature's barrel export is allowed** (type-only imports don't create runtime coupling)
- **components/ cannot import from features/** — they are pure UI primitives
- **lib/ cannot import from components/ or features/** — they are infrastructure
- **No circular imports** (enforced by `import/no-cycle` ESLint rule)

If two features need to share runtime logic, either:
1. Extract to a shared hook/component in the global layer
2. Create a new shared feature module
3. Use events/pub-sub for loose coupling
