# React Testing Standards

> **This is a fallback reference for projects without established testing conventions.**
> If your project already has testing patterns, follow those instead.

## Table of Contents
- [Test Framework Detection](#test-framework-detection)
- [Test File Structure](#test-file-structure)
- [Component Testing](#component-testing)
- [Hook Testing](#hook-testing)
- [Integration Testing](#integration-testing)
- [Mocking](#mocking)
- [Patterns to Avoid](#patterns-to-avoid)

## Test Framework Detection

Before writing tests, check the project's test framework:

- If project uses **Vitest** (`vitest` in devDeps): use `vi.fn()`, `vi.mock()`, `vi.clearAllMocks()`
- If project uses **Jest** (`jest` in devDeps): use `jest.fn()`, `jest.mock()`, `jest.clearAllMocks()`
- If project uses both: match the test file's existing imports
- If unclear: check `package.json` scripts (e.g., `"test": "vitest"` vs `"test": "jest"`)

**Examples below use Vitest syntax; adapt for Jest by replacing `vi` → `jest`.**

## Test File Structure

```tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { UserProfile } from './UserProfile';

// 1. Setup and mocks at file top
const mockOnEdit = vi.fn();  // Jest: jest.fn()
const defaultProps: UserProfileProps = {
  userId: 'user-1',
  onEdit: mockOnEdit,
};

// 2. Helper render function with providers
function renderUserProfile(overrides?: Partial<UserProfileProps>) {
  const user = userEvent.setup();
  const result = render(
    <TestProviders>
      <UserProfile {...defaultProps} {...overrides} />
    </TestProviders>
  );
  return { user, ...result };
}

// 3. Describe block = component name
describe('UserProfile', () => {
  beforeEach(() => {
    vi.clearAllMocks();  // Jest: jest.clearAllMocks()
  });

  // 4. Test names: "should [expected behavior] when [condition]"
  it('should display user name when loaded', async () => {
    renderUserProfile();
    expect(await screen.findByText('John Doe')).toBeInTheDocument();
  });

  it('should call onEdit with userId when edit button is clicked', async () => {
    const { user } = renderUserProfile();
    await user.click(screen.getByRole('button', { name: /edit/i }));
    expect(mockOnEdit).toHaveBeenCalledWith('user-1');
  });

  it('should show skeleton while loading', () => {
    renderUserProfile();
    // getByTestId is acceptable here: skeleton screens lack a semantic role,
    // making role-based queries impractical for this case.
    expect(screen.getByTestId('profile-skeleton')).toBeInTheDocument();
  });

  it('should display error message on fetch failure', async () => {
    // arrange error scenario
    renderUserProfile();
    expect(await screen.findByRole('alert')).toHaveTextContent(/failed/i);
  });
});
```

## Component Testing

### What to Test

| Priority | What | How |
|---|---|---|
| High | User interactions | `userEvent.click()`, `userEvent.type()` |
| High | Rendered output for given props | `screen.getBy*`, `expect().toBeInTheDocument()` |
| High | Error/loading states | Conditional rendering assertions |
| Medium | Accessibility | `toHaveAttribute('aria-*')`, `getByRole()` |
| Medium | Callback invocations | `expect(mockFn).toHaveBeenCalledWith()` |
| Low | Styling / CSS classes | Only for behavioral styling (e.g., visibility) |

### Query Priority

Prefer queries in this order (most accessible → least):

1. `getByRole` — buttons, links, headings
2. `getByLabelText` — form inputs
3. `getByPlaceholderText` — inputs without labels
4. `getByText` — visible text
5. `getByDisplayValue` — input current values
6. `getByTestId` — last resort (acceptable for elements without semantic roles, e.g., skeleton screens)

### Async Patterns

```tsx
// ✅ Use findBy for async elements (auto-waits)
expect(await screen.findByText('Loaded Data')).toBeInTheDocument();

// ✅ Use waitFor for assertions on state changes
await waitFor(() => {
  expect(mockFn).toHaveBeenCalledTimes(1);
});

// ❌ Avoid: manual timeouts or act() wrapping for simple cases
```

## Hook Testing

```tsx
import { renderHook, act } from '@testing-library/react';
import { useCounter } from './useCounter';

describe('useCounter', () => {
  it('should initialize with the given value', () => {
    const { result } = renderHook(() => useCounter(10));
    expect(result.current.count).toBe(10);
  });

  it('should increment count', () => {
    const { result } = renderHook(() => useCounter(0));
    // act() IS correct here: calling hook methods returned by renderHook
    // requires act() to flush state updates synchronously.
    act(() => result.current.increment());
    expect(result.current.count).toBe(1);
  });

  it('should reset to initial value', () => {
    const { result } = renderHook(() => useCounter(5));
    act(() => result.current.increment());
    act(() => result.current.reset());
    expect(result.current.count).toBe(5);
  });
});
```

### When to use `act()`

| Scenario | Use `act()`? | Why |
|---|---|---|
| `renderHook` + calling hook methods | ✅ Yes | Flushes synchronous state updates from hook |
| `render()` + `userEvent` interactions | ❌ No | `userEvent` handles `act()` internally |
| `render()` + `findBy*` queries | ❌ No | `findBy*` auto-waits for async updates |
| `render()` + manual state trigger | ⚠️ Rarely | Prefer `userEvent` + `findBy` instead |

## Integration Testing

```tsx
describe('LoginFlow', () => {
  it('should navigate to dashboard after successful login', async () => {
    const { user } = renderApp({ route: '/login' });

    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/password/i), 'password123');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    expect(await screen.findByText(/dashboard/i)).toBeInTheDocument();
  });
});
```

## Mocking

### API Mocking (MSW preferred)

Examples use **MSW v2** API. For MSW v1 projects, use `rest.get()` + `ctx.json()` instead.

```tsx
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';

const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: 'Test User',
    });
  }),
];

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### Module Mocking

```tsx
// ✅ Mock at module boundary, not internals
vi.mock('@/services/api', () => ({       // Jest: jest.mock(...)
  fetchUser: vi.fn().mockResolvedValue({ name: 'Test' }),
}));

// ❌ Never mock React hooks or internal state
```

## Patterns to Avoid

```tsx
// ❌ Testing implementation details
expect(component.state.isOpen).toBe(true);

// ❌ Snapshot tests for complex components (brittle)
expect(tree).toMatchSnapshot();

// ❌ Testing library internals
expect(setState).toHaveBeenCalled();

// ❌ Using container.querySelector
const el = container.querySelector('.my-class');

// ❌ Wrapping everything in act() for render() scenarios
// (use userEvent + findBy instead — they handle act() internally)
act(() => { render(<MyComponent />); });

// ✅ Instead: use userEvent, findBy queries, and waitFor
```

## [R19] React 19 Testing Considerations

### `use(promise)` + Suspense Components

Components using `use(promise)` require a `<Suspense>` boundary in tests:

```tsx
it('should render data from use(promise)', async () => {
  const dataPromise = Promise.resolve({ name: 'Test' });
  render(
    <Suspense fallback={<div>Loading...</div>}>
      <DataComponent dataPromise={dataPromise} />
    </Suspense>
  );
  expect(await screen.findByText('Test')).toBeInTheDocument();
});
```

### Server Components

React Server Components **cannot** be tested with React Testing Library directly (RTL runs in a browser-like JSDOM environment, RSC runs on the server).

Testing strategies for RSC:
- **Unit test** the data-fetching logic separately (plain function tests)
- **Integration test** via end-to-end tools (Playwright, Cypress)
- **Test the Client Component** that receives RSC output as props

### `useActionState` / `useFormStatus`

Components using Actions API need a `<form>` wrapper in tests:

```tsx
it('should submit form via action', async () => {
  const { user } = render(
    <form action={submitAction}>
      <SubmitButton />
    </form>
  );
  await user.click(screen.getByRole('button', { name: /submit/i }));
  // Assert on expected side effects
});
```

`useFormStatus` only works inside a `<form>` — test components that use it with a parent form element.
