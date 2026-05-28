# Rejected Edits

- 不把默认输出目录改回 `~/.mx_data/output`；统一口径是 `~/.mx/mx-data/output/`。
- 不在文档中硬编码 API Key 示例。
- 不把资讯搜索、选股、模拟交易接口塞进 `mx-data`。
- 不默认联网重试多次；重试应由用户或上层流程显式控制。
- 不把原始 JSON 删除；诊断时它是最可靠证据。
