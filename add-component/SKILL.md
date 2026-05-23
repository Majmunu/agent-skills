---
name: add-component
description: >
  Quick-add a zero-code editor component. Covers runtime (snify) and designer (editor)
  file creation and registration, including property panel, events, actions, variables,
  and CSS variable style semantic layer.
---

# Add Component Skill

> Standard flow for adding a complete component to this zero-code editor.
> Each component requires files in **two packages**: **5 files + 4 registrations**.

## Agent Quick Path

Read this section first and execute it before scanning the long reference tables.

1. Inspect current examples: `Button`, `SearchBar`, and the nearest similar component.
2. Create runtime component using `style-api.ts`, `useComponentStyles`, and `withCustomWrapper`.
3. Create panel config through `add-property-config`; do not handwave `supportedEvents` or `supportedActions`.
4. For each event, prove the runtime payload shape and update semantic event-param options when needed.
5. For list/table row interactions, use `loopContext`; do not read another component's private variable.
6. For data-returning actions, update `contract/outputSchema.ts` and editor value-source tests.
7. Run `node scripts/validate-component-config.mjs {Name}` for new configs, then lint/type-check relevant packages.

Long sections below are reference material; keep the checklist near the end as the final gate.

## Architecture Overview

```
mini_workspace/
packages/snify/src/
  components/{Name}/                <- Runtime component (Preview / Mini Program)
    index.tsx                       <- Component impl (observer + connect + withCustomWrapper)
    style-api.ts                    <- (Recommended) Style semantic layer / CSS var mapping (kebab-case)
    {name}.module.scss              <- (Optional) Component private styles
  components/registry.ts            <- Registration 1: runtime export
  config/components/{Name}.json     <- Panel config (properties / events / actions)
  config/components/index.ts        <- Registration 2: config import mapping

apps/editor/src/designable/designable-components/
  {Name}/index.tsx                  <- Designer adapter (DnFC + Behavior + Resource)
  index.ts                          <- Registration 3: designer export

apps/editor/src/app.tsx             <- Registration 4: import + ResourceWidget + ComponentTreeWidget
```

### Two Directory Responsibilities

| Directory                       | Role               | Description                                        |
| ------------------------------- | ------------------ | -------------------------------------------------- |
| `components/{Name}/`            | **Component impl** | How the component looks and runs                   |
| `config/components/{Name}.json` | **Panel config**   | What can be configured in the editor's right panel |

---

## Step 1: Create Runtime Component

**Path**: `packages/snify/src/components/{Name}/index.tsx`

### Template (Following Button New Architecture)

```tsx
import { connect, mapProps, observer } from '@formily/react'
import type { typePropsBase } from '../type'
import { useComponentStyles } from '../../workbench/PanelEditor/hooks/useComponentStyles'
import { useComponentVariables } from '../../core'
import { useVariableRef } from '../../core/variable/hooks'
import type { VariableRef } from '../../core/variable'
import { withCustomWrapper } from '../../hocs/withCustomWrapper'
import { {Name}StyleSchema, {Name}InitialProps } from './style-api'
import './{name}.module.scss'

// ===== 1. Define Props Type =====
type typeProps = typePropsBase & Partial<{
  id: string
  // Component-specific static props (prefer variable system; these are fallbacks)
  // titleVariableRef: VariableRef
  // loading: boolean
  // disabled: boolean
}>

// ===== 2. Observer Component =====
export const {Name}Component = observer(({ children, ...props }: typeProps) => {
  const {
    attributes,
    style: propsStyle,
    id,
    ...restProps
  } = props

  // ⚠️ CRITICAL: Read custom properties from `attributes`, NOT from top-level props!
  // The PropertyPanel writes fieldName values to x-component-props.attributes[fieldName].
  // Example: config JSON defines { fieldName: "shape" }
  //   → stored at x-component-props.attributes.shape
  //   → accessible as props.attributes.shape (NOT props.shape)

  // ===== 3. Merge defaults with panel attributes =====
  // New architecture: no mergeAttributs callback to write back to designer tree.
  // Instead, InitialProps provides fallback + attributes override in memory.
  const finalAttributes = { ...{Name}InitialProps, ...attributes }

  // ===== 4. Style System =====
  // With style-api.ts managing color/border/font:
  //   commonScope: 'layout-only'  -> only generate common layout vars, skip appearance
  //   bindingScope: 'layout-only' -> only inject layout style bindings, appearance via CSS
  // Simple components (no style-api) can use 'all' for both.
  const { style: styles } = useComponentStyles(finalAttributes, {Name}StyleSchema, {
    commonScope: 'layout-only',
    bindingScope: 'layout-only',
  })

  // ===== 5. Component Variable System =====
  // Component-owned variables: values declared by x-variable-schema and scoped to this node.
  const componentVars = useComponentVariables(id || '')
  // Priority: component variable > props static value
  // WARNING: variable name must match the 'name' field in x-variable-schema exactly
  // const isLoading = componentVars.loading !== undefined
  //   ? Boolean(componentVars.loading) : props.loading

  // Property bindings selected from the right panel should use VariableRef.
  // Example priority: variableRef > deprecated variableKey fallback > static value.
  // const titleRef = finalAttributes.titleVariableRef as VariableRef | undefined
  // const [titleValue] = useVariableRef<string>(titleRef)
  // const title = titleRef?.variableId && titleValue !== undefined
  //   ? String(titleValue)
  //   : String(finalAttributes.title ?? '')

  // ===== 6. Merge Styles =====
  const mergedStyle: Record<string, unknown> = {
    ...(styles as Record<string, unknown>),
    ...propsStyle,
  }

  // ===== 7. Render =====
  return (
    <div id={id} style={mergedStyle} {...restProps}>
      {/* Use @taroify/core components or custom JSX */}
    </div>
  )
})

// ===== 8. Formily Connect =====
export const {Name}Base = connect(
  {Name}Component,
  mapProps((props) => ({ ...props }))
)

// ===== 9. Export Style API (for external consumption) =====
export { {Name}StyleKeys, {Name}StyleSchema, {Name}InitialProps } from './style-api'

// ===== 10. Event System HOC =====
export const {Name} = withCustomWrapper({Name}Base)
```

### commonScope Selection Guide

| Scenario                                              | commonScope   | bindingScope  | Notes                                      |
| ----------------------------------------------------- | ------------- | ------------- | ------------------------------------------ |
| Has `style-api.ts`, component self-manages appearance | `layout-only` | `layout-only` | Avoids common + private dual-path conflict |
| No `style-api.ts`, fully relies on common properties  | `all`         | `all`         | Simple mode                                |

### Event System

`withCustomWrapper` auto-intercepts these events and dispatches to the global event bus.
**No manual event dispatch code needed**:

| Event                                                                 | Strategy | Delay     |
| --------------------------------------------------------------------- | -------- | --------- |
| `onChange`, `onInput`                                                 | Debounce | 300ms     |
| `onClick`, `onTap`                                                    | Throttle | 500ms     |
| `onTouchStart`, `onTouchMove`, `onLongPress`                          | Throttle | 100ms     |
| `onFocus`, `onBlur`                                                   | Normal   | Immediate |
| `onSubmit`, `onConfirm`, `onTouchEnd`, `onPlay`, `onPause`, `onEnded` | Normal   | Immediate |

> But the component must declare `supportedEvents` in `config/components/{Name}.json`
> for it to appear in the editor's interaction panel.
> `load` is a lifecycle contract, but it is **not** auto-fired by `withCustomWrapper`.
> Only declare `load` after verifying a mount-time dispatch path exists for the component/runtime.

### Interaction Contract Rules

Event/action options are contract-backed. Before adding any value to
`supportedEvents` or `supportedActions`, verify it exists in the current
interaction contract sources:

```
packages/snify/src/core/interaction/contract/metadata.ts
packages/snify/src/core/interaction/contract/registry.ts
packages/snify/src/core/interaction/contract/outputSchema.ts
```

Rules:

| Field                | Rule                                                                                                                                                                                                                         |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `supportedEvents`    | Use standard event keys from `EventContract.key`, e.g. `click`, `change`, `input`, `focus`, `blur`. Do not use `onClick` in JSON.                                                                                            |
| `supportedActions`   | Use **canonical** action keys only (e.g. `setNavigationBarTitle`, NOT legacy alias `setPageTitle`). Action must be `active + runtimeSupported + editorConfigurable`. See `add-property-config` Skill Step V9 for validation. |
| Planned actions      | Do not expose in normal component JSON. Check `metadata.ts`: `status: 'planned'`, `runtimeSupported: false`, or `editorConfigurable: false` means not usable for normal configs.                                             |
| Component forwarding | If JSON declares an event, the component must call the injected external handler, e.g. `onChange?.(value)`, after internal state updates.                                                                                    |
| New event/action     | Add or update the interaction contract first, then runtime handler/schema, then JSON, then tests.                                                                                                                            |

### Event Parameter UX Contract

Editor users should choose semantic event data, not implementation paths like
`0.detail.value`. Runtime still stores legacy `eventPath` strings for compatibility,
so new components must make their forwarded payload match the editor's semantic
selector.

Current source of truth for the editor selector:

```
apps/editor/src/designable/designable-react-settings-form/src/widgets/InteractiveSidebar/valueSources.ts
```

Rules:

| Component / Event                                           | Forwarded payload rule                                                            | User-facing option                                |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------- |
| Button-like `click` / `tap`                                 | No business payload by default. Do not rely on event params.                      | Empty state: current event has no business params |
| Input / TextArea / SearchBar `input` / `change` / `confirm` | Forward an event-like object with `detail.value` or `target.value` when possible. | `输入值`                                          |
| Switch / Checkbox `change`                                  | Forward the checked boolean as the first argument.                                | `是否选中`                                        |
| TabBar `change`                                             | Forward the selected value as the first argument.                                 | `选中值`                                          |
| List / Table / Repeater row events                          | Put row data in `loopContext`, not in raw event params.                           | `当前行`, `当前行 ID`, `当前行索引`, `当前行 Key` |

Loop/repeater components should dispatch row metadata as an argument shaped like:

```ts
{
  loopContext: {
    item,
    index,
    key,
  },
}
```

`EventManager` reads this metadata and exposes it through the `loopContext`
value source. Do not make other components read another component's private
component variable to discover the current row.

When adding a component with new business event parameters:

1. Forward a stable semantic payload from the runtime component.
2. Add or update the semantic option in `buildEventPathOptions`.
3. Add tests in `valueSources.test.ts`.
4. Keep raw event-object access as compatibility/advanced behavior only.

### Action Output Contract

The action result picker only shows actions that have output metadata. Runtime
stores:

```ts
{
  sourceType: 'actionOutput',
  actionId: 'previous-action-key',
  outputPath: 'records'
}
```

The editor shows it as natural choices: choose previous action, then choose
`records`, `record`, `deletedId`, etc.

Rules:

| Case                                      | Required update                                                                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| New action returns business data          | Add its fields to `packages/snify/src/core/interaction/contract/outputSchema.ts`.                                               |
| Existing action gets new return field     | Update `outputSchema.ts`, editor labels, and tests.                                                                             |
| Condition/scenario needs execution result | Use system fields `system.success`, `system.status`, `system.error`; ordinary `setVariable` should keep them hidden by default. |
| New data-flow examples                    | Prefer `requestData -> action output -> setVariable page.list.records -> list/table binding`.                                   |

Reference training doc:

```
packages/snify/docs/事件合同与交互流转规范.md
```

---

## Step 2: Create style-api.ts (Recommended)

**Path**: `packages/snify/src/components/{Name}/style-api.ts`

> WARNING: Use **kebab-case** filename (`style-api.ts`), not the legacy `style_api.ts`.

This file defines the **Component Semantic Layer (Layer 3)**, mapping panel design fields
to component-controlled CSS variables.

```ts
/**
 * {Name} Component Style API
 * Component Semantic Layer (Layer 3):
 * - Maps common fields (fillColor, fontSize...) to component semantic vars (--sn-{name}-*)
 * - Supports one-to-many mapping (e.g., fillColor -> default/hover/active)
 */

import type { ComponentStyleSchema } from '../../core'
import { Transformers, Parsers } from '../../core'
import { safePxTransform } from '../utils'

// ===== CSS Variable Namespace =====
export const {Name}StyleKeys = {
  color: {
    bg: '--sn-{name}-color-bg',
    text: '--sn-{name}-color-text',
    border: '--sn-{name}-color-border',
  },
  layout: {
    radius: '--sn-{name}-layout-radius',
    fontSize: '--sn-{name}-layout-font-size',
    height: '--sn-{name}-layout-height',
  },
} as const

// ===== Panel Field -> CSS Variable Mapping =====
export const {Name}StyleSchema: ComponentStyleSchema = {
  fillColor: {
    cssVar: {Name}StyleKeys.color.bg,
    transform: Transformers.identity,
    parse: Parsers.color,
    when: (values) => values.fillType === 'solid',
  },
  color: {
    cssVar: {Name}StyleKeys.color.text,
    transform: Transformers.identity,
    parse: Parsers.color,
  },
  strokeColor: {
    cssVar: {Name}StyleKeys.color.border,
    transform: Transformers.identity,
    parse: Parsers.color,
  },
  fontSize: {
    cssVar: {Name}StyleKeys.layout.fontSize,
    transform: Transformers.transform,
  },
  radius: {
    cssVar: {Name}StyleKeys.layout.radius,
    transform: Transformers.borderRadius,
    parse: Parsers.px,
  },
}

// ===== Initial default attributes when dragged in =====
// CAUTION: Avoid strong visual defaults (fillColor/textColor) here,
// or Layer4 instance variables will be generated prematurely,
// overriding theme Token fallback chain.
export const {Name}InitialProps = {
  width: '100%',
  height: safePxTransform(96),
  fillType: 'solid',
  strokeType: 'none',
  strokeWidth: 1,
}
```

---

## Step 3: Create Component Styles (Optional)

**Path**: `packages/snify/src/components/{Name}/{name}.module.scss`

```scss
.{name} {
  display: flex;
  align-items: center;
  position: relative;
  box-sizing: border-box;
  overflow: hidden;

  // Use :global to override third-party UI library styles
  :global {
    .taroify-xxx {
      // Consume CSS variables from style-api
      background-color: var(--sn-{name}-color-bg, transparent);
      color: var(--sn-{name}-color-text, #333);
      border-radius: var(--sn-{name}-layout-radius, 0);
    }
  }
}
```

---

## Step 4: Create Panel Config JSON

**Path**: `packages/snify/src/config/components/{Name}.json`

> WARNING: Path is `config/components/`, NOT `components/{Name}/`!
> System loads via `config/components/index.ts`. Wrong path = config not loaded.

### ➡️ Cross-Skill Reference

For complete property configuration rules, naming conventions, setter types, visibility logic,
events/actions, and validation rules, **read the dedicated Skill**:

```
.codex/skills/add-property-config/SKILL.md
```

That Skill covers:

- `ComponentConfig` schema (6 top-level fields)
- 6 fixed category keys (DO NOT create new ones)
- 23+ setter types with extra fields
- Property naming: `{componentName}_{fieldName}` format
- `fieldName` global uniqueness requirement
- `visibleWhen` conditional visibility (4 operators, and/or logic)
- `linkedFields` value linking
- `supportedEvents` / `supportedActions` with contract verification
- `defaultValue` special formats (tuple, JSON string, etc.)
- Complete examples (minimal → complex)

### Quick Template

```json
{
  "disabledCommonProps": [],
  "visibleWhenOverrides": {},
  "propertyStyleOverrides": {},
  "customGroups": [
    {
      "key": "{name}Basic",
      "label": "基础设置",
      "categoryKey": "component"
    }
  ],
  "customProperties": [
    {
      "key": "{name}_title",
      "label": "标题",
      "fieldName": "title",
      "type": "TextInput",
      "defaultValue": "标题",
      "groupKey": "{name}Basic",
      "categoryKey": "component"
    }
  ],
  "supportedEvents": ["click"],
  "supportedActions": ["setVariable"]
}
```

### Variable Binding Rules

New bindable component properties must use `VariableRef` as the canonical storage shape:

```ts
type VariableRef = {
  variableId: string;
  variableName: string;
  scope: "global" | "page" | "component";
  varType: "string" | "number" | "boolean" | "array" | "object" | "any";
  path?: string;
};
```

Runtime priority:

```ts
const valueRef = attributes?.valueRef as VariableRef | undefined;
const [refValue] = useVariableRef(valueRef);
const value =
  valueRef?.variableId && refValue !== undefined ? refValue : attributes?.value;
```

Rules:

| Scenario                                                   | Required pattern                                                              |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Bind an existing editor variable to a component prop       | Add a `VariableRefSelector` property and store it in `attributes.{fieldName}` |
| Component declares its own state/value variable            | Use `x-variable-schema`; runtime reads via `useComponentVariables(id)`        |
| Existing component already has `variableKey` or string IDs | Keep fallback only, mark field `deprecated: true`, and prefer `variableRef`   |
| New component or new property                              | Do not introduce new `variableKey`, `name`, or `nodeId::name` bindings        |

`x-variable-schema` defines variables owned by the component instance. It is not a replacement
for panel property binding. Panel binding should store `VariableRef`, usually with field names
such as `valueRef`, `titleRef`, `srcRef`, or a legacy-compatible `variableRef`.

### ⚠️ Property Storage Path (Critical)

Custom properties defined in `customProperties[].fieldName` are stored in a **nested** location:

```
PropertyPanel onChange(fieldName, value)
  → AttributeSidebar writes to:
    node.props['x-component-props'].attributes[fieldName]
  → Runtime component receives:
    props.attributes[fieldName]
```

**NOT** `x-component-props[fieldName]` (top-level). This means:

```tsx
// ✅ CORRECT: Read from attributes
const shape = (attributes.shape as string) || "square";
const isDisabled = Boolean(attributes.disabled);

// ❌ WRONG: Read from top-level props (these will always be undefined)
const { shape, disabled } = props; // shape/disabled are NOT here!
```

This applies to ALL custom properties defined in config JSON. Only formily-managed
props (like `value`, `onChange`, `dataSource`) come as top-level props.

---

## Step 5: Register Runtime Export (Registration 1)

**File**: `packages/snify/src/components/registry.ts`

Add one line:

```ts
export * from "./{Name}";
```

---

## Step 6: Register Panel Config (Registration 2)

**File**: `packages/snify/src/config/components/index.ts`

Add import and mapping:

```ts
// At the top import section:
import {Name} from './{Name}.json'

// In the componentConfigs object:
export const componentConfigs: Record<string, ComponentConfig> = {
  // ... existing
  {Name},
}
```

> WARNING: Skip this step = property panel, event panel, action panel ALL BLANK!

---

## Step 7: Create Designer Adapter

**Path**: `apps/editor/src/designable/designable-components/{Name}/index.tsx`

```tsx
import React from 'react'
import { {Name} as Component } from 'snify'

import {
  createBehavior,
  createResource,
} from '@/designable/designable-core/src'
import { DnFC } from '@/designable/designable-react/src'

// ===== Designer Wrapper Component =====
export const {Name}: DnFC<React.ComponentProps<typeof Component>> = (
  props: any,
) => {
  return (
    <Component
      {...props}
      id={props['data-designer-node-id']}
    >
      {props.children}
    </Component>
  )
}

// ===== Behavior: Designer behavior definition =====
{Name}.Behavior = createBehavior({
  name: '{Name}',                    // Unique ID (must match x-component)
  extends: ['Field'],                // Fixed inheritance
  selector: (node) => node.props['x-component'] === '{Name}',
  designerProps: {},
  designerLocales: {
    'zh-CN': {
      title: '{Chinese Name}',
    },
  },
})

// ===== Resource: Drag resource definition =====
{Name}.Resource = createResource({
  icon: 'CardSource',                 // Options: 'CardSource', 'InputSource', etc.
  title: '{Chinese Name}',
  elements: [
    {
      componentName: 'Field',
      props: {
        type: 'basic',               // 'basic' = basic component category
        title: '{Chinese Name}',
        'x-component': '{Name}',     // Must match Behavior.name
        'x-component-props': {
          // Default props when dragged in
        },
        // ===== Component Variable Definition (Optional) =====
        // Auto-registered to variable system on drag. Names must match both sides.
        'x-variable-schema': {
          value: {
            scope: 'component',
            name: 'value',           // <- runtime reads componentVars.value
            varType: 'string',
            defaultValue: 'default',
            desc: 'Component value',
          },
          disabled: {
            scope: 'component',
            name: 'disabled',        // <- runtime reads componentVars.disabled
            varType: 'boolean',
            defaultValue: false,
            desc: 'Disabled state',
          },
        },
      },
    },
  ],
})
```

### Component Variable Lifecycle

Variable names declared in designer and consumed in runtime must be **exactly the same**:

```
Designer Resource                  Runtime Component
x-variable-schema: {               useComponentVariables(id)
  value: {                               |
    name: 'value',   --- addNode -->  VariableStore.register()
    varType: 'string',                    |
    defaultValue: '...'              componentVars.value  <- same name
  }
}
```

---

## Step 8: Register Designer Export (Registration 3)

**File**: `apps/editor/src/designable/designable-components/index.ts`

Add one line:

```ts
export * from "./{Name}";
```

---

## Step 9: Register in app.tsx (Registration 4)

**File**: `apps/editor/src/app.tsx`

### 9a. Import

```tsx
import {
  // ... existing imports
  {Name},
} from '@/designable/designable-components'
```

### 9b. ResourceWidget

Add to the appropriate `<ResourceWidget>` sources array:

```tsx
<ResourceWidget title="sources.Displays" sources={[..., {Name}]} />
```

### 9c. ComponentTreeWidget

Add to `<ComponentTreeWidget>` components object:

```tsx
<ComponentTreeWidget
  components={{
    // ... existing
    {Name},
  }}
/>
```

---

## Complete Checklist

```markdown
### File Creation

- [ ] 1. `packages/snify/src/components/{Name}/index.tsx` - Runtime component
- [ ] 2. `packages/snify/src/components/{Name}/style-api.ts` - Style API (recommended, kebab-case)
- [ ] 3. `packages/snify/src/components/{Name}/{name}.module.scss` - Styles (optional)
- [ ] 4. `packages/snify/src/config/components/{Name}.json` - Panel config (properties + events + actions)
- [ ] 5. `apps/editor/src/designable/designable-components/{Name}/index.tsx` - Designer adapter

### Registration (4 places)

- [ ] 6. `packages/snify/src/components/registry.ts` - Add export
- [ ] 7. `packages/snify/src/config/components/index.ts` - Add import + mapping
- [ ] 8. `apps/editor/src/designable/designable-components/index.ts` - Add export
- [ ] 9. `apps/editor/src/app.tsx` - import + ResourceWidget + ComponentTreeWidget

### Verification

- [ ] 10. `pnpm run lint` - No errors
- [ ] 11. Refresh editor -> Component visible in sidebar
- [ ] 12. Drag to canvas -> Renders correctly
- [ ] 13. Right panel properties -> Custom properties display correctly
- [ ] 14. Right panel interaction -> Events and actions are selectable
- [ ] 15. Interaction contract checked -> Every `supportedEvents` / `supportedActions` entry matches `contract/metadata.ts` and `contract/registry.ts`
- [ ] 16. Event forwarding checked -> Declared component events call injected handlers (`onChange?.`, `onInput?.`, etc.)
- [ ] 17. Event params checked -> Runtime payload has a semantic option in `valueSources.ts`, or intentionally exposes no business params
- [ ] 18. Loop context checked -> List/Table/Repeater row actions dispatch `{ loopContext: { item, index, key } }`
- [ ] 19. Action output checked -> Data-returning actions update `contract/outputSchema.ts` and editor value-source tests
- [ ] 20. Config validation checked -> `node scripts/validate-component-config.mjs {Name}` passes for new configs
- [ ] 21. Variable binding checked -> New bindable props use `VariableRefSelector` + `useVariableRef`
- [ ] 22. Legacy binding checked -> Existing `variableKey` / string ID props are marked `deprecated` and used only as fallback
```

---

## Placeholder Reference

| Placeholder      | Example          | Description               |
| ---------------- | ---------------- | ------------------------- |
| `{Name}`         | `Rating`         | PascalCase component name |
| `{name}`         | `rating`         | lowercase component name  |
| `{Chinese Name}` | Rating Component | Display name in editor    |

---

## Reference Examples

| Component  | Characteristics                                                        | Recommendation           |
| ---------- | ---------------------------------------------------------------------- | ------------------------ |
| **Button** | New architecture: `style-api.ts` + `layout-only` + no `mergeAttributs` | Primary reference        |
| Switch     | Legacy: `style_api.ts` + `mergeAttributs` writeback                    | Structure reference only |
| Input      | Legacy: variable binding but no `x-variable-schema`                    | Do not follow            |

> **New components must follow Button's new architecture.**
> Do NOT use legacy `mergeAttributs` writeback or `style_api.ts` naming.
