# Finnhub API 使用指南

## 注册 & API Key
- 注册：https://finnhub.io/register（邮箱 + 密码）
- 免费 tier：60 API calls/分钟
- Key 存入 `config/api_keys.json`
- 安装：`pip install finnhub-python`

## 集成方式
在 `fetch_financials.py` 中自动执行 `enrich_with_finnhub(data)`，结果写入 `data["finnhub"]`。

## 数据内容

### latest_earnings — 最新财报摘要
```python
{
  "date": "2026-04-30",
  "eps_actual": 2.99,
  "eps_estimate": 2.83,
  "revenue_actual": 921000000,
  "revenue_estimate": 919000000
}
```

### earnings_transcript — Earnings Call 完整记录
```python
"earnings_transcript": "Good afternoon, everyone...（前5000字）"
```
- 部分公司可能没有免费 tier 的 Transcript 数据

### recent_news — 近90天内新闻（前5条）
```python
[{"source": "Yahoo", "headline": "Crocs beats Q1 expectations...", "url": "...", "date": 1745964000}]
```

### insider_transactions — 内部人交易（前5条）
```python
[{"name": "Andrew Rees", "change": -6687, "share": 6687, "transaction_price": 79.63}]
```

## 已知限制
- 免费 tier 可能无法获取所有公司的 Transcript
- 每只股票约消耗 2-4 次 API 调用
- 免费 tier 60次/分钟 ≈ 单次分析 15-30 只股票
