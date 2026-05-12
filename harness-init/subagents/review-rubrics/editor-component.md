# Review Rubric: 编辑器与组件生态负责人 (Editor & Component Specialist)

## Review Scope

- 编辑器 UI 与交互逻辑
- 画布渲染与拖拽系统
- 组件注册与字典管理
- 属性面板配置
- 样式系统与 CSS 变量

## Required Check Items

1. 组件注册是否遵循组件字典规范
2. 画布交互是否影响已有拖拽/选中/缩放逻辑
3. 属性面板字段类型与校验规则是否正确
4. 样式变量是否遵循语义层命名规范
5. 组件元数据格式是否与运行时对齐
6. 是否有对应的组件预览/测试

## Pass Criteria

- 组件注册符合字典规范
- 画布交互无回归
- 属性面板校验规则完整
- 样式变量命名规范
- 元数据与运行时一致

## Reject Criteria

- 组件注册不符合规范且无说明
- 破坏已有画布交互
- 属性面板缺少必要校验
- 样式变量命名混乱
- 元数据与运行时不一致

## Reference

- Routing: `subagents/routing-rules.yml`
- Roles: `subagents/roles.json` → editor_component_specialist
