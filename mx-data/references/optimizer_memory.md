# Optimizer Memory

- `mx-data` 是 A/H 股数据查询入口，适合行情、财务指标、公司信息、股东和经营数据。
- 输出标准是 Excel、description 和 raw JSON，默认写到 `~/.mx/mx-data/output/`。
- 自然语言查询层可能非确定；关键查询需要保留 raw JSON 并考虑改写问句。
- 需要新闻、公告、研报时路由到 `mx-search`。
- 需要状态变更时不要在本 skill 内执行，改用带安全门的 `mx-zixuan` 或 `mx-moni`。
