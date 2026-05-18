---
name: strategic_target_search
description: "批量筛选管道（原 financial-screener 精简版）— 注：分析脚本已迁移至 financial-analysis"
version: 1.0.0
author: Hermes Agent
---

# Financial Screening — 批量筛选管道

## 说明

此 skill 原为 `financial-screener`（含筛选 + 分析脚本）。**分析脚本（8个深度分析 + 交叉校验 + 上传）已迁移至 `financial-analysis` skill。**

批量筛选管道脚本（`batch_fetcher.py` / `multi_stage_screener.py` / `pipeline.py`）目前已移除。如需恢复，可以从 git 历史找回。

## 推荐工作流

当前主要使用 **逐只深度分析** 模式，完整流程在 `financial-analysis` skill 中：

```bash
# 数据采集
python3 ~/.hermes/skills/data-science/financial-data-acquisition/scripts/fetch_financials.py --ticker [代码]

# 运行8个分析脚本 + 交叉校验
cd ~/.hermes/skills/data-science/financial-analysis/scripts
python3 calculate_reproduction_value.py --ticker [代码]
python3 cross_validate.py --ticker [代码]

# 生成报告（由 AI 完成）→ 上传 Notion
python3 upload_to_notion.py --ticker [代码]
```
