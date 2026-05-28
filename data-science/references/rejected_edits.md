# Rejected Edits

- 不把 `data-science` 拆成多个过细入口；当前 skill 需要保留跨市场、分析脚本和产物链的总入口价值。
- 不默认触发 Notion 上传、微信发送或音频生成；这些都是外部状态动作，必须由用户明确要求。
- 不把真实 API Key 写入 `.env.example`、Markdown 示例或 eval 样例。
- 不用一次性长查询替代分阶段验证；金融数据源常有分页、限流和字段漂移。
- 不把 A 股实时数据能力复制进本 skill 主文档；优先引用 `mx-*` 专门 skill。
