---
name: polygon-data
description: "Polygon.io 金融数据采集器 — 美股行情/财报/K线/股息/拆分，作为 yfinance 的替代/补充数据源"
version: 1.0.0
author: Hermes Agent
env:
  - POLYGON_API_KEY: "Polygon.io API Key (https://polygon.io/dashboard/signup)"
---

# Polygon.io 金融数据采集器

## 定位

Polygon.io 是美股（含期权、加密货币）的专业数据源。在 CFO 分析流程中，它作为 **yfinance 的替代/补充** 角色加入数据源矩阵。

## 与现存数据源的关系

```
美股分析数据源优先级:

🥇 Polygon.io  ← 新增主力美股源（结构化财报+实时行情+K线）
    ↓ 不可用时
🥇 yfinance    ← 现有美股源（兜底）
    ↓ 美股定性
🥈 SEC EDGAR  ← 10-K文本/Risk/MD&A
🥈 Finnhub     ← Earnings Call转录
```

## 前置条件

```bash
# 1. 注册获取 API Key
#    https://polygon.io/dashboard/signup (Free tier: 5 calls/min)

# 2. 配置环境变量
export POLYGON_API_KEY="your_key_here"

# 3. 安装依赖
pip install requests
```

## API 端点总览

**⚠️ v3 财务端点不可用** — 实测 `/v3/reference/financials` 返回 404。所有财务数据走 v2 展平格式。

| 端点 | 频率限制(free) | 用途 |
|------|---------------|------|
| `/v2/aggs/ticker/{t}/prev` | 5/min | 上日收盘行情 |
| `/v2/aggs/ticker/{t}/range/1/day/{from}/{to}` | 5/min | 历史日K线 |
| **`/v2/reference/financials/{t}`** | 5/min | **结构化财报**（103+ 展平字段，含SBC） |
| `/v3/reference/tickers/{t}` | 5/min | 公司基本信息 |
| `/v2/reference/dividends/{t}` | 5/min | 分红历史（字段: amount/exDate/paymentDate） |
| `/v2/reference/splits/{t}` | 5/min | 拆股历史 |

## 用法

```bash
# 查询股票行情
python3 ~/.hermes/skills/polygon-data/polygon_data.py --ticker AAPL --type quote

# 查询财报
python3 ~/.hermes/skills/polygon-data/polygon_data.py --ticker AAPL --type financials --limit 5

# 查询历史K线
python3 ~/.hermes/skills/polygon-data/polygon_data.py --ticker AAPL --type bars --from 2023-01-01 --to 2025-12-31

# 查询分红
python3 ~/.hermes/skills/polygon-data/polygon_data.py --ticker AAPL --type dividends

# 批量查询
python3 ~/.hermes/skills/polygon-data/polygon_data.py --ticker AAPL --type all
```

## 输出结构

所有查询输出到 `~/.polygon_data/output/`，格式统一为 JSON + 终端预览。

## 加载 financial-data-acquisition

在 `financial-data-acquisition` 的 fetch_financials.py 中，Polygon 作为美股数据通道加入：
- 美股(.TO)时自动触发 Polygon 补充
- 输出至 `data["polygon"]`
- 覆盖 yfinance 可能缺失的字段：SBC、回购、分红明细

## 与 mx-data 的分工

| 市场 | 主力 | 备用 |
|------|------|------|
| A股 | mx-data | yfinance |
| 美股 | **Polygon.io** (新) | yfinance |
| 港股 | mx-data | yfinance |
| 加密货币 | Polygon.io | — |
