# Optimizer Memory

- `mx-search` 负责金融资讯和外部证据，尤其适合新闻、公告、研报、政策、交易规则和事件解释。
- 依赖安装口径是 venv 优先：`python3 -m venv .venv` 后用 `python3 -m pip install requests`。
- 需要数值表、财务指标或行情时路由到 `mx-data`。
- 需要条件选股时路由到 `mx-xuangu`。
- 输出目录默认 `~/.mx/mx-search/output/`。
