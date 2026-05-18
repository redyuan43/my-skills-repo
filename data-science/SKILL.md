---
name: data-science
description: Financial data science workflows for market data acquisition, Polygon.io queries, MX API A-share research, reproducible Python/Jupyter exploration, valuation scripts, Buffett-style investment review, critical review, reasoning trace generation, and optional Notion upload. Use when Codex needs to fetch financial data, analyze stocks, build investment memos, run the bundled finance scripts, or inspect the imported data-science references from data-science.zip.
---

# Data Science

## 快速入口

先确认密钥来自环境变量，不要把真实 key 写入输出报告或可提交文件：

```bash
set -a
source data-science/.env.local
set +a
```

本 skill 已从 `data-science.zip` 整理为一个可发现的 Codex skill。长说明保留在 `references/original-skills/`，执行脚本保留在 `scripts/`。

## 任务选择

- 拉取基础财务数据：读 `references/original-skills/financial-data-acquisition.md`，优先运行 `scripts/financial-data-acquisition/fetch_financials.py`。
- 查询 Polygon.io：读 `references/original-skills/polygon-data.md`，运行 `scripts/polygon-data/polygon_data.py`，必须设置 `POLYGON_API_KEY`。
- A 股自然语言查询或东方财富妙想：读 `references/financial-data-acquisition/mx-api-guide.md` 和 `references/financial-analysis/china-a-share-data-sources.md`，必须设置 `MX_APIKEY`。
- 生成投资备忘录或估值分析：读 `references/original-skills/financial-analysis.md`，按里面的脚本顺序运行 `scripts/financial-analysis/`。
- 巴菲特视角、批判性审查、推理追踪：分别读 `references/original-skills/buffett-review.md`、`critical-review.md`、`reasoning-review.md`。
- Jupyter 交互式探索：读 `references/original-skills/jupyter-live-kernel.md`，仅在需要持久 Python 状态时使用。
- Notion 上传：只在用户明确要求上传时读 `references/original-skills/notion-upload.md`，并要求 `NOTION_API_KEY`。

## 密钥与配置

`data-science/.env.local` 可保存本机私有密钥，已被 `.gitignore` 忽略。可提交的模板是 `data-science/.env.example`。

部分旧脚本会从 `scripts/config/api_keys.json` 读取 Finnhub、FRED、Tushare 等 key。不要提交真实文件；需要时复制模板：

```bash
cp data-science/scripts/config/api_keys.example.json data-science/scripts/config/api_keys.json
```

## 常用命令

Polygon 全量查询：

```bash
set -a; source data-science/.env.local; set +a
python3 data-science/scripts/polygon-data/polygon_data.py --ticker AAPL --type all
```

yfinance/SEC/Finnhub/FRED 财务数据采集：

```bash
python3 data-science/scripts/financial-data-acquisition/fetch_financials.py --ticker AAPL --format markdown
```

深度分析脚本一般以采集出的 JSON 作为输入。执行前先读 `references/original-skills/financial-analysis.md`，再按目标选择 `scripts/financial-analysis/` 下的脚本。

## 纪律

- 所有金额、比率、估值计算必须用 Python、脚本或可复现命令完成，不要在正文里心算。
- 每个外部数据点都要记录来源、抓取时间、币种和单位。
- 当现金/市值、ROIC、WACC、汇率或币种出现异常值时，先做数据一致性检查，再写结论。
- Notion 上传、外部 API 调用和联网采集前，先确认用户确实需要当前数据。
