---
name: add-property-config
description: >
  Generate or modify component property panel configuration JSON for the zero-code editor.
  Covers custom properties, groups, events, actions, visibility rules, and naming conventions.
---

# Add Property Config Skill

> Declarative JSON configuration for the editor's right-hand property panel.
> This file is the single source of truth for AI-generated component configs.

## Architecture Overview

```
PropertyPanel Rendering Pipeline:
  {Name}.json → useAsyncConfig() → ConfigurablePropertyPanel → PropertyRow → SetterRenderer
       ↑                                    ↑                        ↑
  config/components/   merges common +   renders per-property    maps type → UI
  index.ts registry    custom properties  with visibility logic  via SETTER_MAP
```

### Data Flow

1. **Config Load**: `useAsyncConfig` loads `config/components/{Name}.json` via the registry
2. **Merge**: `ConfigurablePropertyPanel` merges `commonProperties.json` + component `customProperties`
3. **Visibility**: `isPropertyVisible` evaluates `visibleWhen` conditions against current values
4. **Render**: Each property renders via `SetterRenderer` → `SETTER_MAP[type]`
5. **Storage**: Values written to `node.props['x-component-props'].attributes[fieldName]`
6. **Runtime**: Component reads `props.attributes[fieldName]` (NOT `props[fieldName]`)

### File Locations

| File | Purpose |
|---|---|
| `packages/snify/src/config/components/{Name}.json` | Component-specific config |
| `packages/snify/src/config/components/index.ts` | Config registry (import + mapping) |
| `packages/snify/src/config/commonProperties.json` | Shared common properties |
| `packages/snify/src/workbench/PropertyPanel/types.ts` | TypeScript type definitions |
| `packages/snify/src/workbench/shared/SetterRenderer/index.tsx` | Setter type → component mapping |

---

## ComponentConfig Schema

Each `{Name}.json` file is a `ComponentConfig` object with these top-level fields:

```json
{
  "disabledCommonProps": [],
  "visibleWhenOverrides": {},
  "propertyStyleOverrides": {},
  "customGroups": [],
  "customProperties": [],
  "supportedEvents": [],
  "supportedActions": []
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `disabledCommonProps` | `string[]` | Yes | Common property keys to hide (e.g. `["common_rotation"]`) |
| `visibleWhenOverrides` | `Record<string, VisibilityRule \| null>` | Yes | Override common property visibility conditions. **Set to `null` to explicitly clear a common property's original `visibleWhen`** (makes it always visible). |
| `propertyStyleOverrides` | `Record<string, object>` | Yes | Override common property presentation styles |
| `customGroups` | `PropertyGroup[]` | Yes | Custom property group definitions |
| `customProperties` | `PropertySchema[]` | Yes | Custom property definitions |
| `supportedEvents` | `string[]` | No | Events bindable in the interaction panel |
| `supportedActions` | `string[]` | No | Actions triggerable in the interaction panel |

> ⚠️ All 5 required fields must be present even if empty (`[]` or `{}`).
> Missing `supportedEvents`/`supportedActions` means the interaction panel shows nothing.

---

## Category System (6 Fixed Tabs)

The editor sidebar has **6 fixed category tabs**. You MUST use these exact keys:

| categoryKey | Label | Tab Content | isCommon? |
|---|---|---|---|
| `layout` | 布局 | Position, size, rotation | ✅ Common |
| `shapeFill` | 形状填充与线条 | Fill color, gradient, stroke | ✅ Common |
| `shapeEffect` | 形状效果 | Shadow, border radius | ✅ Common |
| `textEffect` | 文字效果 | Font family, size, color | ✅ Common |
| `textBox` | 文本框 | Text alignment, padding | ✅ Common |
| `component` | 组件功能 | Component-specific properties | ❌ Component-specific |

> ⚠️ **DO NOT create new categoryKey values!** The runtime only renders tabs for these 6 keys.
> Custom properties almost always use `"categoryKey": "component"`.

---

## Custom Groups (`customGroups`)

Groups organize properties into collapsible sections within a category tab.

```json
{
  "customGroups": [
    {
      "key": "inputBasic",
      "label": "输入框",
      "categoryKey": "component"
    },
    {
      "key": "inputTitle",
      "label": "标题",
      "categoryKey": "component"
    }
  ]
}
```

| Field | Type | Description |
|---|---|---|
| `key` | `string` | Unique group identifier. Use semantic naming: `{componentName}{GroupPurpose}` |
| `label` | `string` | Display name shown in the panel |
| `categoryKey` | `string` | Must be one of the 6 fixed category keys |

### Naming Rules for Group Keys

| ✅ New convention | ❌ Legacy (do not use) |
|---|---|
| `switchBasic` | `group_1773797916109` |
| `inputTitle` | `group_1769068323086` |
| `cascaderPopup` | `group_1770453205745` |

---

## Custom Properties (`customProperties`)

Each property maps to a UI control (setter) in the panel.

### Full PropertySchema

```json
{
  "key": "input_maxlength",
  "label": "最大字数",
  "fieldName": "maxlength",
  "type": "NumberInput",
  "defaultValue": 100,
  "groupKey": "inputBasic",
  "categoryKey": "component",
  "unit": "px",
  "dropdown": true,
  "placeholder": "请输入",
  "options": [],
  "radioStyle": "button",
  "visibleWhen": {},
  "linkedFields": {},
  "suffixIcon": ""
}
```

### Required Fields

| Field | Type | Description |
|---|---|---|
| `key` | `string` | **Globally unique** property identifier |
| `label` | `string` | Display label in the panel |
| `fieldName` | `string` | Storage key in `attributes`. **Must be unique across ALL properties (common + custom)** |
| `type` | `string` | Setter type (see Setter Type Catalog below). **Must exist in SETTER_MAP** — unknown types silently fall back to `InputSetter` (fake-success risk). |
| `defaultValue` | `PropertyValue` | Default value. Type is `string \| number \| boolean \| null \| string[] \| number[] \| VariableRefValue \| Record<string, unknown>`. Format must match setter type (see defaultValue Formats below). |
| `groupKey` | `string` | Must reference a key from `customGroups` |
| `categoryKey` | `string` | Must be one of the 6 fixed category keys |

### Optional Fields

| Field | Type | Used by | Description |
|---|---|---|---|
| `unit` | `string` | `NumberInput` | Unit suffix: `"px"`, `"rpx"`, `"%"`, `"°"` |
| `dropdown` | `boolean` | `NumberInput` | Show unit dropdown selector |
| `placeholder` | `string` | `TextInput`, `TextArea`, `NumberInput` | Placeholder text |
| `options` | `PropertyOption[]` | `Select`, `RadioGroup`, `CheckboxGroup` | Selection options |
| `radioStyle` | `string` | `RadioGroup` | `"button"` (segmented) or `"radio"` (circles) |
| `rows` | `number` | `TextArea` | Visible text rows |
| `min` / `max` / `step` | `number` | `NumberInput`, `Slider` | Value constraints |
| `suffixIcon` | `string` | `TextInput` | Suffix icon name |
| `suffix` | `string` | `Slider` | Suffix text after slider value |
| `description` | `string` | All types | Description text (shown below the setter) |
| `tooltip` | `string` | All types | Tooltip text (question-mark icon, hover to show) |
| `layout` | `string` | All types | `"horizontal"` (default) or `"vertical"` (label above, control below) |
| `buttonText` | `string` | `Button` | Button display text |
| `action` | `string` | `Button` | Action identifier when button is clicked |
| `visibleWhen` | `VisibilityRule` | All types | Conditional visibility |
| `linkedFields` | `LinkedFields` | All types | Value linking |
| `allowedTypes` | `VariablePrimitiveType[]` | `VariableRefSelector` | Allowed variable types, e.g. `["string"]` for image URL/text-like binding |
| `allowedScopes` | `VariableScope[]` | `VariableRefSelector` | Allowed variable scopes, e.g. `["global", "page", "component"]` |
| `deprecated` | `boolean` | All types | Marks a legacy compatibility field |
| `deprecatedMessage` | `string` | All types | Migration hint shown for deprecated fields |

### Naming Rules

**Property key** format: `{componentName}_{fieldName}`

| ✅ New convention | ❌ Legacy (do not use for new properties) |
|---|---|
| `input_maxlength` | `custom_1769073439027` |
| `switch_color` | `custom_1773798189059` |
| `tabbar_iconSize` | `custom_1765875844137` |

**fieldName** constraints:
- Must be a valid JavaScript identifier (camelCase preferred)
- **Must be globally unique** across common properties AND custom properties within the same component
- **DO NOT use a hardcoded list to check uniqueness.** Read fieldNames dynamically from `commonProperties.json`:

```bash
# Extract all common fieldNames (run from mini_workspace root)
node -e "const d=JSON.parse(require('fs').readFileSync('packages/snify/src/config/commonProperties.json','utf8')); d.properties.forEach(p=>console.log(p.fieldName))"
```

Current common fieldNames (as of 2026-04-28, **always re-read before use**):

```
x, xRelative, y, yRelative, width, height, rotation,
fillType, fillColor, gradient, fillOpacity,
strokeType, strokeColor, strokeWidth, strokeStyle,
shadow, borderRadius,
wordWrap, breakMode, maxLines, maxChars, textShadow,
textAlign, verticalAlign, writingMode,
paddingLeft, paddingRight, paddingTop, paddingBottom,
name, hidden, showHeight, locked, disabled,
color, fontSize, fontFamily, fontStyle, letterSpacing, lineHeight, fontWeight
```

> ⚠️ This list may drift as common properties evolve. Always use the dynamic extraction command above for authoritative results.

---

## Setter Type Catalog

### Basic Input

| type | Description | Extra fields |
|---|---|---|
| `TextInput` | Single-line text input | `placeholder`, `suffixIcon` |
| `TextArea` | Multi-line text input | `rows`, `placeholder` |
| `NumberInput` | Numeric input with optional unit | `min`, `max`, `step`, `unit`, `dropdown` |

### Selection

| type | Description | Extra fields |
|---|---|---|
| `Switch` | Boolean toggle | — |
| `Select` | Dropdown selector | `options: [{label, value, disabled?}]` |
| `DynamicSelect` | Dynamic dropdown (options from sibling field) | `optionsFrom: "fieldName"`, `placeholder` |
| `OptionList` | Visual option list editor (label + value pairs) | — |
| `RadioGroup` | Radio button group | `options`, `radioStyle: "button" \| "radio"` |
| `CheckboxGroup` | Checkbox group | `options` |

### Color & Style

| type | Description | Extra fields |
|---|---|---|
| `ColorPicker` | Color picker (rgb format) | — |
| `GradientPicker` | Gradient picker | — |
| `FillPicker` | Fill type picker (solid/gradient) | — |
| `Slider` | Slider control | `min`, `max`, `step` |

### Advanced

| type | Description | Extra fields |
|---|---|---|
| `Shadow` | Shadow editor (color + offsets + blur) | — |
| `Border` | Border editor (width + color + style) | — |
| `Spacing` | Padding/margin editor | — |
| `Size` | Width/height editor | — |
| `Radius` | Four-corner radius editor | — |
| `Font` | Font family/size/weight editor | — |
| `Position` | X/Y position editor | — |
| `Button` | Action trigger button | — |
| `VariableRefSelector` | Variable binding selector that stores `VariableRef` | `allowedTypes`, `allowedScopes` |

### Layout

| type | Description | Extra fields |
|---|---|---|
| `AlignHorizontal` | Horizontal alignment (left/center/right) | — |
| `AlignVertical` | Vertical alignment (top/center/bottom) | — |
| `TextDirection` | Text direction (horizontal/vertical) | — |

### Specialized

| type | Description | Extra fields |
|---|---|---|
| `TabItems` | Tab item list editor (with icon/badge) | — |

> **Prefer existing setter types**. Only request a new custom setter if none above fits.

### VariableRefSelector

Use `VariableRefSelector` for new component property bindings. It stores a `VariableRef`
object in `attributes.{fieldName}` and lets the editor choose or create variables without
typing IDs by hand.

```json
{
  "key": "image_srcRef",
  "label": "图片变量",
  "fieldName": "srcRef",
  "type": "VariableRefSelector",
  "defaultValue": null,
  "groupKey": "imageBasic",
  "categoryKey": "component",
  "allowedTypes": ["string"],
  "allowedScopes": ["global", "page", "component"],
  "tooltip": "优先使用变量选择器绑定，保存 VariableRef。"
}
```

Legacy string bindings such as `variableKey`, `activeStateVariable`, `name`, or
`nodeId::name` must not be introduced for new properties. When maintaining existing
components, keep them only as fallbacks and mark them:

```json
{
  "key": "image_variableKey",
  "label": "变量 Key（旧）",
  "fieldName": "variableKey",
  "type": "TextInput",
  "defaultValue": "",
  "groupKey": "imageBasic",
  "categoryKey": "component",
  "deprecated": true,
  "deprecatedMessage": "variableKey 为旧格式，建议尽快迁移到 variableRef。"
}
```

### Adding a New Setter Type (Full Sync Procedure)

A new setter requires **4 files** updated in sync:

| # | File | Change |
|---|---|---|
| 1 | `workbench/shared/SetterRenderer/setters/*.tsx` | Create the setter React component |
| 2 | `workbench/shared/SetterRenderer/index.tsx` | Register in `SETTER_MAP` |
| 3 | `workbench/PropertyPanel/types.ts` | Add to `SetterType` union |
| 4 | `config/components/component-config.schema.json` | Add to `PropertySchema.type` enum |

Optionally also update `PanelEditor/constants.ts` → `SETTER_CATEGORIES` for the drag-and-drop toolbox.

> ⚠️ If any of these 4 files drifts, the system silently degrades:
> - Missing from SETTER_MAP → falls back to `InputSetter` (fake-success)
> - Missing from Schema → validation won't catch typos
> - Missing from SetterType → TypeScript won't catch type errors

---

## defaultValue Formats (Per Setter Type)

> ⚠️ **Type constraint**: `defaultValue` must be `PropertyValue` = `string | number | boolean | null | string[] | number[] | VariableRefValue | Record<string, unknown>`.
> For ordinary setters, complex data should still be serialized as JSON string unless that setter explicitly accepts an object. `VariableRefSelector` is the canonical object-valued setter.

| Setter Type | Required Format | Example | Notes |
|---|---|---|---|
| `TextInput` | `string` | `"请输入"` | |
| `TextArea` | `string` | `"多行文本"` | |
| `NumberInput` (with `unit`) | `[string, string]` tuple **or** plain `number` | `["44", "rpx"]` or `0` | Setter auto-initializes unit from `property.unit` when given plain number. Both forms are valid. |
| `NumberInput` (no `unit`) | `number` | `100` | |
| `Switch` | `boolean` or `""` | `true`, `false`, `""` | `""` treated as falsy |
| `Select` | Must match one `options[].value` | `"bottom"` | |
| `RadioGroup` | Must match one `options[].value` | `"row"` | |
| `DynamicSelect` | Must match one value from the `optionsFrom` source field | `"option1"` | Options are dynamically parsed from the JSON string in the referenced field. Falls back to TextInput when JSON parse fails. |
| `OptionList` | JSON-serialized `[{label, value}]` string | `"[{\"label\":\"选项一\",\"value\":\"option1\"}]"` | Parsed via `safeParseJson<OptionItem[]>`. Visual list editor for adding/removing/editing option pairs. |
| `CheckboxGroup` | Comma-separated `string` **or** `string[]` | `"a,b"` or `["a", "b"]` | Setter reads both forms via `value.split(',')` / `Array.isArray`. onChange writes back comma-separated string. Prefer `""` for empty default. |
| `ColorPicker` | CSS color string | `"rgb(25,137,250)"`, `"#cccccc"` | |
| `GradientPicker` | JSON-serialized `GradientValue` string | `"{\"type\":\"linear\",...}"` | Parsed via `safeParseJson<GradientValue>`. CSS gradient strings like `"linear-gradient(...)"` are NOT valid — must be the component's internal JSON shape. |
| `FillPicker` | JSON-serialized `FillValue` string | `"{\"type\":\"solid\",\"color\":\"#fff\"}"` | Parsed via `safeParseJson<FillValue>` |
| `Slider` | `number` within `[min, max]` | `100` | |
| `Shadow` | JSON-serialized `ShadowValue` string | `"{\"preset\":\"none\",\"color\":\"#000\",\"opacity\":0,\"offsetX\":0,\"offsetY\":0,\"blur\":0,\"spread\":0,\"inset\":false}"` | Parsed via `safeParseJson<ShadowValue>` |
| `Radius` | `number` (uniform) **or** JSON-serialized `BorderRadiusValue` string | `0` or `"{\"tl\":4,\"tr\":4,\"bl\":4,\"br\":4}"` | Setter handles both via `safeParseJson` with `typeof value === 'number'` fallback |
| `Font` | `string` (FontStyleValue) | `""` | Empty string = default font style |
| `AlignHorizontal` | `"left"` \| `"center"` \| `"right"` | `"left"` | |
| `AlignVertical` | `"top"` \| `"middle"` \| `"bottom"` | `"middle"` | |
| `TextDirection` | `"horizontal-tb"` \| `"vertical-lr"` \| `"vertical-rl"` | `"horizontal-tb"` | These are the only 3 valid button values. Setter shows `"horizontal"` on empty/invalid value but that won't match any button — always use a real option. |
| `Border` | JSON-serialized `BorderValue` string | `"{\"width\":1,\"color\":\"#000\",\"style\":\"solid\"}"` | Parsed via `safeParseJson<BorderValue>` |
| `Spacing` | JSON-serialized `SpacingValue` string | `"{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0}"` | Parsed via `safeParseJson<SpacingValue>` |
| `Position` | JSON-serialized `PositionValue` string | `"{\"x\":0,\"y\":0,\"xRelative\":\"left\",\"yRelative\":\"top\"}"` | Parsed via `safeParseJson<PositionValue>` |
| `Size` | `SizePosition` value (string) | — | Passed directly as SizePosition type |
| `TabItems` | JSON-serialized `TabItem[]` string | `"[{\"name\":\"Tab1\"}]"` | Parsed via `safeParseJson<TabItem[]>` |
| `Button` | N/A (not stored) | `""` | |
| `VariableRefSelector` | `null` or `VariableRefValue` object | `null` | New bindings should be created through the editor selector. Hand-written object values must include `variableId`, `variableName`, `scope`, and `varType`. |

---

## Conditional Visibility (`visibleWhen`)

Show/hide properties based on other property values.

### Structure

```json
{
  "visibleWhen": {
    "conditions": [
      { "field": "showTitle", "operator": "==", "value": true },
      { "field": "titleIcon", "operator": "!=", "value": "no" }
    ],
    "logic": "and"
  }
}
```

### Supported Operators

| Operator | Description | Example |
|---|---|---|
| `==` | Equals | `{ "field": "type", "operator": "==", "value": "text" }` |
| `!=` | Not equals | `{ "field": "rules", "operator": "!=", "value": "no" }` |
| `in` | Value in array | `{ "field": "size", "operator": "in", "value": ["sm", "md"] }` |
| `notIn` | Value not in array | `{ "field": "mode", "operator": "notIn", "value": ["hidden"] }` |

### Logic

| logic | Description |
|---|---|
| `"and"` | All conditions must be true |
| `"or"` | At least one condition must be true |

### Rules

- `field` refers to `fieldName` of another property (common or custom, same component)
- When referenced field doesn't exist, the condition evaluates to `true` (show by default)
- `visibleWhen` only controls display; the value persists even when hidden

---

## Value Linking (`linkedFields`)

Auto-update related properties when a value changes.

```json
{
  "linkedFields": {
    "valueMap": {
      "preset-a": { "opacity": 80, "blur": 4 },
      "preset-b": { "opacity": 100, "blur": 8 }
    }
  }
}
```

When this property's value changes to a key in `valueMap`, the mapped fieldName-value pairs are automatically written.

---

## Common Property Controls

### Disabling Common Properties

Hide specific common properties for a component:

```json
{
  "disabledCommonProps": [
    "common_rotation",
    "common_shadow"
  ]
}
```

Use the `key` from `commonProperties.json` (not `fieldName`).

### Overriding Common Property Visibility

```json
{
  "visibleWhenOverrides": {
    "common_fillColor": {
      "conditions": [
        { "field": "fillType", "operator": "==", "value": "solid" }
      ],
      "logic": "and"
    },
    "common_gradient": null
  }
}
```

> Setting a key to `null` **clears** the common property's original `visibleWhen`, making it always visible.
> This is different from omitting the key (which keeps the original rule intact).

### Overriding Common Property Presentation

```json
{
  "propertyStyleOverrides": {
    "common_fillType": {
      "radioStyle": "radio"
    }
  }
}
```

---

## Events & Actions

### supportedEvents

Declares which events appear in the editor's interaction panel for this component.

```json
{
  "supportedEvents": ["click", "change", "focus", "blur"]
}
```

**Available event contract keys** (from `core/interaction/contract/registry.ts`):

| Event Key | Title | Category |
|---|---|---|
| `click` | 点击时 | mouse |
| `change` | 值改变 | form |
| `input` | 输入中 | form |
| `focus` | 获得焦点 | form |
| `blur` | 失去焦点 | form |

> ⚠️ Use contract `key` values (e.g. `"click"`), NOT React handler names (e.g. ~~`"onClick"`~~).

### supportedActions

Declares which actions can be triggered by this component's events.

```json
{
  "supportedActions": ["setVariable", "setNavigationBarTitle"]
}
```

**Active action contract keys** (status = active AND editorConfigurable = true):

| Action Key | Canonical? | Title | Status |
|---|---|---|---|
| `setVariable` | ✅ | 设置变量 | ✅ Active |
| `setNavigationBarTitle` | ✅ Canonical | 设置页面标题 | ✅ Active |
| `setPageTitle` | ❌ Legacy alias | 同上 | ✅ Active (use `setNavigationBarTitle` for new configs) |
| `setAuthenticationSession` | ✅ | 登录态操作 | ✅ Active (debug) |

> ⚠️ **New configs must use canonical action key `setNavigationBarTitle`**, not `setPageTitle`.
> `setPageTitle` is retained only for backward compatibility with existing configs.

> ⚠️ Do NOT list planned actions (`request`, `setState`, `navigateTo`, `showToast`, etc.).
> They have no runtime handlers and will silently fail.

> ⚠️ **MetadataService silently filters invalid event/action keys.** If you list an event or action
> that doesn't exist in `contract/registry.ts`, it won't error — the interaction panel will simply
> show no options for it. Always verify keys against the contract registry.

### Event/Action Checklist

Before declaring events/actions, verify:

1. **Event forwarding**: Component must call the injected handler (`onChange?.()`, `onClick?.()`, etc.)
2. **withCustomWrapper**: Component must be wrapped with `withCustomWrapper` HOC (auto-intercepts DOM events)
3. **Not in EXCLUDED_COMPONENTS**: Check `SchemaField.ts` blacklist — layout/passive components are excluded
4. **Contract exists**: Verify the event/action key exists in `contract/registry.ts`

---

## Registration

After creating `{Name}.json`, register it:

**File**: `packages/snify/src/config/components/index.ts`

```ts
// Add import:
import {Name} from './{Name}.json'

// Add to mapping:
export const componentConfigs: Record<string, ComponentConfig> = {
  // ... existing
  {Name},
}
```

> ⚠️ Skip this step = property panel, event panel, action panel ALL BLANK!

---

## Mandatory Validation Pipeline

Before finalizing a config, execute **all** of the following steps. Do NOT skip any.

### Step V1: JSON Syntax

```bash
node -e "JSON.parse(require('fs').readFileSync('packages/snify/src/config/components/{Name}.json','utf8'));console.log('OK')"
```

### Step V2: Key Uniqueness

Verify all `key` values are unique within the file (no duplicates).

### Step V3: fieldName Global Uniqueness

```bash
# Extract common fieldNames and check for conflicts:
node -e "
const common=JSON.parse(require('fs').readFileSync('packages/snify/src/config/commonProperties.json','utf8'));
const comp=JSON.parse(require('fs').readFileSync('packages/snify/src/config/components/{Name}.json','utf8'));
const cFields=new Set(common.properties.map(p=>p.fieldName));
const conflicts=(comp.customProperties||[]).filter(p=>cFields.has(p.fieldName));
if(conflicts.length){console.log('CONFLICT:',conflicts.map(p=>p.fieldName));process.exit(1)}
console.log('OK: no fieldName conflicts');
"
```

### Step V4: Setter Type Exists in SETTER_MAP

Verify every `type` value in `customProperties` exists as a key in `SetterRenderer/index.tsx` SETTER_MAP.
Unknown types **silently degrade** to `InputSetter` (a text field), creating a fake-success appearance.

### Step V5: groupKey References

Every `groupKey` in `customProperties` must match a `key` in `customGroups`.

### Step V6: categoryKey Values

Every `categoryKey` must be one of: `layout`, `shapeFill`, `shapeEffect`, `textEffect`, `textBox`, `component`.

### Step V7: defaultValue Format

Verify each property's `defaultValue` matches the format in the **defaultValue Formats** table above.

### Step V8: visibleWhen Field References

Every `visibleWhen.conditions[].field` must reference an existing `fieldName` (common or custom, same component).

### Step V9: Comprehensive Validation Script

Use the project validation script that **dynamically reads** `contract/registry.ts`, `SETTER_MAP`, and `commonProperties.json`:

```bash
# New configs (default: --strict) — rejects legacy aliases and common fieldName collisions
node scripts/validate-component-config.mjs {Name}

# Existing configs — downgrades legacy aliases and fieldName collisions to warnings
node scripts/validate-component-config.mjs {Name} --legacy
```

**Mode selection:**

| Mode | When to use | Legacy alias | Common fieldName collision |
|---|---|---|---|
| `--strict` (default) | New configs, Add-Component Mode | ✗ Error | ✗ Error |
| `--legacy` | Maintaining existing configs | ⚠ Warning (exit 0) | ⚠ Warning (exit 0) |

> `--legacy` relaxes **only** the two columns above. All other checks (missing required fields, invalid setter types, orphan groupKey, bad categoryKey, etc.) remain hard errors in both modes.

**What the script validates:**
- Event keys exist in `eventContracts` (from `registry.ts`)
- Action keys are canonical + active + editorConfigurable + runtimeSupported
- Legacy action aliases rejected (strict) or warned (legacy)
- Per-property **required fields**: `key`, `label`, `fieldName`, `type`, `defaultValue`, `groupKey`, `categoryKey`
- Setter `type` exists in `SETTER_MAP` (unknown → silent `InputSetter` fallback)
- `fieldName` uniqueness across custom props + common props
- `categoryKey` is one of the 6 valid values
- `groupKey` references a key in `customGroups`
- `key` uniqueness within the file
- Exits non-zero on any error (warnings do NOT cause failure)

> The script reads source files directly — no hardcoded snapshot lists to drift.

### Step V10: Registration

Verify `{Name}` is imported and mapped in `config/components/index.ts`. Missing = all panels blank.

### Step V11: Lint

```bash
pnpm run lint
```

Expect: 0 errors. Existing warnings are acceptable.

---

## Complete Examples

### Minimal (No custom properties)

```json
{
  "disabledCommonProps": [],
  "visibleWhenOverrides": {},
  "propertyStyleOverrides": {},
  "customProperties": [],
  "customGroups": [],
  "supportedEvents": ["click"],
  "supportedActions": ["setVariable"]
}
```

### Simple (Button — style override only)

> ⚠️ This example shows the **recommended new config pattern**. Existing `Button.json` in the repo
> still uses legacy `setPageTitle` — do NOT copy that for new configs.

```json
{
  "disabledCommonProps": [],
  "visibleWhenOverrides": {},
  "propertyStyleOverrides": {
    "common_fillType": {
      "radioStyle": "radio"
    }
  },
  "customProperties": [],
  "customGroups": [],
  "supportedEvents": ["click"],
  "supportedActions": ["setVariable", "setNavigationBarTitle", "setAuthenticationSession"]
}
```

### Medium (Switch — basic custom properties)

```json
{
  "disabledCommonProps": [],
  "visibleWhenOverrides": {},
  "propertyStyleOverrides": {},
  "customGroups": [
    {
      "key": "switchBasic",
      "label": "开关",
      "categoryKey": "component"
    }
  ],
  "customProperties": [
    {
      "key": "switch_title",
      "label": "标题",
      "fieldName": "switchTitle",
      "type": "TextInput",
      "defaultValue": "标题",
      "groupKey": "switchBasic",
      "categoryKey": "component"
    },
    {
      "key": "switch_defaultChecked",
      "label": "默认值",
      "fieldName": "defaultChecked",
      "type": "Switch",
      "defaultValue": "",
      "groupKey": "switchBasic",
      "categoryKey": "component"
    },
    {
      "key": "switch_size",
      "label": "大小",
      "fieldName": "switchSize",
      "type": "NumberInput",
      "defaultValue": ["44", "rpx"],
      "groupKey": "switchBasic",
      "categoryKey": "component",
      "dropdown": true,
      "unit": "rpx"
    },
    {
      "key": "switch_color",
      "label": "颜色",
      "fieldName": "switchColor",
      "type": "ColorPicker",
      "defaultValue": "rgb(25,137,250)",
      "groupKey": "switchBasic",
      "categoryKey": "component"
    }
  ],
  "supportedEvents": ["change"],
  "supportedActions": ["setVariable"]
}
```

### Complex (with conditional visibility and multiple groups)

See `packages/snify/src/config/components/Input.json` for the most comprehensive example:
- 30+ properties across 4 groups
- `visibleWhen` with both `"and"` and `"or"` logic
- Nested conditional chains (e.g., icon settings visible only when showTitle=true AND titleIcon≠"no")
- Multiple setter types: `TextInput`, `TextArea`, `NumberInput`, `Switch`, `Select`, `RadioGroup`, `AlignHorizontal`, `ColorPicker`

---

## Execution Modes

This Skill can operate in two modes:

### Standalone Mode (现有组件补配置)

**Use when**: Component runtime already exists, you only need to add/modify the property panel config.

**Input**: Component name (`{Name}`), desired properties, events, actions.

**Output files**:
1. `packages/snify/src/config/components/{Name}.json` (create or modify)
2. `packages/snify/src/config/components/index.ts` (add import + mapping)

**Workflow**:
1. Read the component's runtime source to understand available props
2. Read `commonProperties.json` to extract current fieldNames
3. Generate the JSON config following this Skill
4. Run the Mandatory Validation Pipeline (Steps V1–V11)
   - **Creating a new config**: use `--strict` (default)
   - **Modifying an existing config**: use `--legacy` to relax **only** legacy action aliases and common fieldName collisions to warnings. Structural errors (missing required fields, invalid setter types, orphan groupKey, etc.) still fail — fix them before committing.

### Add-Component Mode (跨 Skill 调用)

**Use when**: Called from `add-component` Skill Step 4 during new component creation.

**Input contract** (provided by `add-component`):
- `Name`: PascalCase component name (e.g. `Progress`)
- `name`: camelCase for key prefixes (e.g. `progress`)
- `label`: Chinese display name (e.g. `进度条`)
- `runtime attributes`: List of `props.attributes[fieldName]` the component reads
- `event forwarding proof`: Which handlers the component calls (`onChange?.()`, `onClick?.()`, etc.)
- `withCustomWrapper`: Whether the HOC wraps the component

**Output contract** (returned to `add-component`):
- `{Name}.json` created at correct path
- `index.ts` registration added
- `supportedEvents` derived from event forwarding proof (NOT guessed)
- `supportedActions` only includes actions with active runtime handlers
- All validation steps V1–V11 passed

**Rules for Add-Component Mode**:
1. Only declare events that the component **provably forwards** (source code evidence required)
2. Property `fieldName` values must match the `attributes.xxx` reads in the component source
3. Use canonical action keys (`setNavigationBarTitle` not `setPageTitle`)
4. If component has no custom props but has events, create a minimal config with empty `customProperties`
5. New bindable props must use `VariableRefSelector`; legacy string bindings may remain only with `deprecated: true`

---

## Reference Files

| File | Purpose |
|---|---|
| `config/components/Button.json` | Minimal with style overrides |
| `config/components/Switch.json` | Basic custom properties |
| `config/components/TabBar.json` | TabItems setter, multiple colors |
| `config/components/Input.json` | Full complexity: visibility chains, multiple groups, all setter types |
| `config/components/Cascader.json` | Medium complexity with Select options |
| `config/components/Checkbox.json` | RadioGroup with options |
| `workbench/PropertyPanel/types.ts` | TypeScript type definitions (`PropertyValue`, `SetterType`, `ComponentConfig`) |
| `workbench/shared/SetterRenderer/index.tsx` | `SETTER_MAP` registry (unknown type → `InputSetter` fallback) |
| `core/interaction/contract/registry.ts` | Event/action contract definitions |
| `config/commonProperties.json` | Common property fieldNames (dynamic source of truth) |
| `config/components/component-config.schema.json` | JSON Schema for IDE validation |
| `scripts/validate-component-config.mjs` | **V9 validation script** — dynamically reads registry, SETTER_MAP, common fieldNames |
