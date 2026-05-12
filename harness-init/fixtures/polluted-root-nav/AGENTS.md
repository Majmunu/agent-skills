# Repository Navigation

## Repository Layout

This is a monorepo with multiple applications.

## Quick Commands

### Editor App
- Start dev server: `cd apps/editor && npm run dev`
- Run tests: `cd apps/editor && npm test`
- Build: `cd apps/editor && npm run build`

### UI Package
- Build components: `cd packages/ui && npm run build`
- Run storybook: `cd packages/ui && npm run storybook`

## Environment Setup

```bash
export DATABASE_URL=postgres://localhost:5432/myapp
export REDIS_URL=redis://localhost:6379
cd apps/editor && cp .env.example .env
```

## Projects

| Project | Path | Description |
|---------|------|-------------|
| Editor | apps/editor/ | Main editor application |
| UI | packages/ui/ | Shared UI components |

## Global Rules

- All changes require an ExecPlan
- Follow architecture boundaries
