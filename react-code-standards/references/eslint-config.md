# ESLint Reference Config — Fallback Template

> **This is a fallback template for projects without an existing ESLint config.**
> If your project already has an ESLint config, follow that instead.
> Use this as a starting point for new projects or when the team decides to adopt
> a unified standard.

## Compatibility

- Requires `eslint` ≥ 9.0 (flat config)
- Requires `eslint-plugin-react` ≥ 7.35
- Requires `eslint-plugin-react-hooks` ≥ 5.0
- Requires `typescript-eslint` ≥ 8.0
- Requires `eslint-plugin-import` with `eslint-import-resolver-typescript`

For React 18 projects with older plugin versions, some rules may not be available
(e.g., `react/hook-use-state`, `react/no-object-type-as-default-prop`). Adjust or
remove those rules accordingly.

## Table of Contents
- [Base Configuration](#base-configuration)
- [Essential Rules](#essential-rules)
- [Import Rules](#import-rules)
- [Custom Rule Explanations](#custom-rule-explanations)

## Base Configuration

```javascript
// eslint.config.js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactPlugin from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import importPlugin from 'eslint-plugin-import';
import a11y from 'eslint-plugin-jsx-a11y';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  reactPlugin.configs.flat.recommended,
  reactPlugin.configs.flat['jsx-runtime'],
  reactHooks.configs.flat.recommended,
  a11y.flatConfigs.recommended,
  {
    settings: {
      react: { version: 'detect' },
      'import/resolver': {
        typescript: { alwaysTryTypes: true },
      },
    },
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // --- React Core ---
      'react/no-unstable-nested-components': 'error',
      'react/jsx-no-leaked-render': 'error',
      'react/jsx-pascal-case': 'error',
      'react/jsx-no-useless-fragment': 'warn',
      'react/function-component-definition': ['warn', {
        namedComponents: 'function-declaration',
        unnamedComponents: 'arrow-function',
      }],
      'react/destructuring-assignment': ['warn', 'always'],
      'react/no-array-index-key': 'warn',
      'react/jsx-no-constructed-context-values': 'error',
      // Optional rules — require eslint-plugin-react ≥ 7.35; remove if using older version
      'react/hook-use-state': 'warn',
      'react/no-object-type-as-default-prop': 'warn',

      // --- React Hooks ---
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',

      // --- TypeScript ---
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/consistent-type-imports': ['error', {
        prefer: 'type-imports',
        fixStyle: 'inline-type-imports',
      }],
      '@typescript-eslint/consistent-type-exports': 'error',
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],
      '@typescript-eslint/naming-convention': ['warn',
        { selector: 'typeLike', format: ['PascalCase'] },
        { selector: 'enumMember', format: ['UPPER_CASE'] },
        { selector: 'variable', format: ['camelCase', 'UPPER_CASE', 'PascalCase'] },
        { selector: 'function', format: ['camelCase', 'PascalCase'] },
      ],

      // --- General Quality ---
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'prefer-const': 'error',
      'no-var': 'error',
      'eqeqeq': ['error', 'always'],
      'curly': ['error', 'all'],
      'no-nested-ternary': 'error',
      'max-lines': ['warn', { max: 250, skipBlankLines: true, skipComments: true }],
      'max-lines-per-function': ['warn', {
        max: 50,
        skipBlankLines: true,
        skipComments: true,
        IIFEs: true,
      }],
      'complexity': ['warn', 10],
      'max-depth': ['warn', 4],
      'max-params': ['warn', 4],
  },
  {
    // Import ordering
    plugins: { import: importPlugin },
    rules: {
      'import/order': ['error', {
        groups: [
          'builtin',
          'external',
          'internal',
          'parent',
          'sibling',
          'index',
          'type',
        ],
        pathGroups: [
          { pattern: 'react', group: 'builtin', position: 'before' },
          { pattern: 'next/**', group: 'builtin', position: 'before' },
          { pattern: '@/**', group: 'internal' },
        ],
        pathGroupsExcludedImportTypes: ['react'],
        'newlines-between': 'always',
        alphabetize: { order: 'asc', caseInsensitive: true },
      }],
      'import/no-duplicates': 'error',
      'import/no-cycle': 'error',
      'import/no-default-export': 'warn',
    },
  },
  {
    // Allow default exports for pages, layouts, configs
    files: [
      '**/app/**/page.tsx',
      '**/app/**/layout.tsx',
      '**/app/**/loading.tsx',
      '**/app/**/error.tsx',
      '**/app/**/not-found.tsx',
      '**/pages/**/*.tsx',        // Next.js Pages Router
      '**/*.config.*',
      '**/middleware.*',
    ],
    rules: {
      'import/no-default-export': 'off',
    },
  },
  {
    // Relaxed rules for test files
    files: ['**/*.test.*', '**/*.spec.*', '**/__tests__/**'],
    rules: {
      'max-lines': 'off',
      'max-lines-per-function': 'off',
      // Relaxed to warn: mock return values often lack precise types; still prefer typed mocks
      '@typescript-eslint/no-unsafe-assignment': 'warn',
    },
  },
);
```

## Essential Rules

### Must-Have (Error level)

| Rule | Why |
|---|---|
| `react/no-unstable-nested-components` | Prevents components defined inside render causing state loss |
| `react/jsx-no-leaked-render` | Catches `{count && <X />}` rendering `0` |
| `react-hooks/rules-of-hooks` | Hooks must follow call order rules |
| `@typescript-eslint/no-explicit-any` | Eliminates `any` — use `unknown` + narrowing |
| `import/no-cycle` | Prevents circular dependencies |
| `eqeqeq` | Prevents type coercion bugs |

### Should-Have (Warn level)

| Rule | Why |
|---|---|
| `react-hooks/exhaustive-deps` | Catches stale closure bugs |
| `max-lines` | Enforces file size discipline |
| `max-lines-per-function` | Keeps functions focused |
| `complexity` | Flags overly complex logic |
| `react/no-array-index-key` | Catches key antipattern |

## Import Rules

### Path Aliases

Configure in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@/components/*": ["./src/components/*"],
      "@/features/*": ["./src/features/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/lib/*": ["./src/lib/*"],
      "@/types/*": ["./src/types/*"]
    }
  }
}
```

> **Note**: Install `eslint-import-resolver-typescript` for `import/no-cycle` and
> other import rules to correctly resolve TypeScript path aliases.

### Import Grouping

1. React / framework (`react`, `next/*`)
2. External packages (`zod`, `@tanstack/*`)
3. Internal aliases (`@/components/*`, `@/lib/*`)
4. Relative parent (`../`)
5. Relative sibling (`./`)
6. Type-only imports (`import type {}`)
7. Styles / assets

## Custom Rule Explanations

### `max-lines: 250`

Hard limit per file. Forces extraction of sub-components and hooks.
Test files are exempt.

### `max-lines-per-function: 50`

Keeps functions readable. Includes component body.
If a function exceeds this, extract logic to helpers or custom hooks.

### `complexity: 10`

Cyclomatic complexity limit. High complexity = hard to test.
Refactor to reduce branching (early returns, strategy pattern, etc.).

### `max-depth: 4`

Prevents deeply nested code. Flatten with early returns and extraction.

### `max-params: 4`

General functions with too many params should use an options object or be decomposed.

> **Note on component props**: `max-params` counts function parameters, not destructured
> properties. `function Card({ a, b, c, d, e }: Props)` has 1 parameter. Use the
> "Props count" guideline in SKILL.md (soft: 5, hard: 8) for props, not this ESLint rule.

## Rule Classification

### Quality-Core (must-have)

These rules catch bugs, type safety issues, and React rule violations:

- `rules-of-hooks`, `exhaustive-deps`
- `no-explicit-any`, `no-unsafe-*`
- `no-unstable-nested-components`, `jsx-no-constructed-context-values`
- `jsx-no-leaked-render`, `no-array-index-key`
- `import/no-cycle`, `eqeqeq`, `no-var`, `prefer-const`
- `complexity`, `max-depth`, `max-lines-per-function`

### Style (optional, team preference)

These rules enforce consistency but are not correctness issues:

- `function-component-definition`, `destructuring-assignment`
- `naming-convention`, `jsx-pascal-case`
- `import/order`, `no-default-export`
- `no-console`, `curly`

Projects may adjust or disable style rules to match existing conventions.
