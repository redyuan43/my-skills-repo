# Optimizer Memory

- `mx-xuangu` 是条件筛选入口，适合市值、估值、财务、行业、板块、指数成分、分红、增长、ROE 等组合筛选。
- 结果只用于候选集生成，需要事实核查时路由到 `mx-data` 和 `mx-search`。
- 涉及自选股或组合动作时必须显式切到带安全门的 `mx-zixuan` 或 `mx-moni`。
- eval 关注路由边界和不越权执行。
- selftest 只做结构和安全静态检查，不调用真实 API。
