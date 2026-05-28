# Optimizer Memory

- `mx-zixuan` 是自选股管理入口，查询动作低风险，add/delete 是外部状态变更。
- 安全门规则：默认拒绝变更，`--dry-run` 输出 payload，`--yes` 才真实执行。
- 自然语言中包含“查询、列表、我的自选、有哪些”时按查询处理，其余管理语义按变更处理。
- 需要选股候选集时先路由到 `mx-xuangu`，再由用户确认是否加入自选。
- selftest 要覆盖 dry-run 不触网和无 `--yes` 拒绝。
