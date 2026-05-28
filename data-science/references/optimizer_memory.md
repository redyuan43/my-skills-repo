# Optimizer Memory

- `data-science` 是重工作流入口，适合可复现投研、脚本分析、估值复核、SEC/Polygon/Notion 等跨工具任务。
- A/H 股即时数据查询走 `mx-data`，金融资讯和公告走 `mx-search`，选股条件筛选走 `mx-xuangu`。
- 外部状态动作需要显式用户意图：上传、投递、发布、买卖、watchlist 或 portfolio 改动都不自动执行。
- 轻量质量门禁是 `scripts/selftest.sh --safe` 加 `quick_validate.py`。
- 保持文档薄入口，细节放 references，避免 `SKILL.md` 变成长手册。
