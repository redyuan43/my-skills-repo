# Gate Checklist

- 确认任务确实需要金融数据科学工作流，而不是单次 A/H 股数据查询；后者优先路由到 `mx-data`、`mx-search` 或 `mx-xuangu`。
- 真实 API 请求前确认使用的凭据来源，禁止把 `MX_APIKEY`、`POLYGON_API_KEY`、Notion token 写入文件或终端记录。
- 生成研究产物时输出到 skill 本地 `out/` 或用户指定目录，不覆盖原始数据。
- 涉及投资结论时区分事实数据、估值假设和主观判断，不把模型推断写成确定事实。
- 对大范围行情或财务拉取先做小样本 smoke，再扩展到长区间任务。
