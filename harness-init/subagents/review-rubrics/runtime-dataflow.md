# Review Rubric: 运行时引擎负责人 (Runtime & Dataflow Engineer)

## Review Scope

- 小程序渲染运行时
- 数据绑定与状态管理
- Action 执行引擎
- 补丁系统（生成/应用/回滚）
- 微信 API 集成

## Required Check Items

1. Schema 到 WXML/JS 转换是否正确
2. 数据绑定是否有响应式更新
3. Action 链执行是否有错误处理
4. 补丁生成/应用/回滚是否可靠
5. 微信 API 调用是否有异常处理
6. 运行时性能影响是否已评估（渲染、内存）
7. 是否影响小程序基础库兼容性

## Pass Criteria

- 数据绑定正确且响应式
- Action 执行有完整错误处理
- 补丁系统可靠（有回滚能力）
- 微信 API 有异常处理
- 无性能回归

## Reject Criteria

- 数据绑定逻辑错误
- Action 执行无错误处理
- 补丁系统无回滚能力
- 微信 API 无异常处理
- 引入明显性能问题

## Reference

- Routing: `subagents/routing-rules.yml`
- Roles: `subagents/roles.json` → runtime_dataflow_engineer
