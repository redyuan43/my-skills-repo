# Baostock 最新季度数据获取指南

## 背景

yfinance 对 A 股季度数据的更新通常有 1-3 个月的延迟。Baostock 的 `query_profit_data()` 可以在 yfinance 尚未更新时提供最新的季度的净利润、净利率、EPS_TTM 和 ROE。

## 已验证的用例（2026年5月1日）

yfinance 季度数据截止到 2025-12-31，而 Baostock 已提供 2026 Q1 数据。

```python
import baostock as bs
lg = bs.login()
rs = bs.query_profit_data(code='sh.605499', year='2026', quarter=1)
df = rs.get_data()
if not df.empty:
    row = df.iloc[0]
    print(f"营收(MBRevenue): {row.get('MBRevenue', 'N/A')}")
    print(f"净利(netProfit): {row.get('netProfit', 'N/A')}")
    print(f"净利率(npMargin): {row.get('npMargin', 'N/A')}")
    print(f"EPS_TTM: {row.get('epsTTM', 'N/A')}")
    print(f"ROE平均: {row.get('roeAvg', 'N/A')}")
bs.logout()
```

## 已知限制

| 字段 | Q1 | Q2 | Q3 | Q4 |
|------|-----|-----|-----|-----|
| netProfit（净利润） | ✅ | ✅ | ✅ | ✅ |
| MBRevenue（营收） | ⚠️ 常为空 | ✅ H1累计 | ⚠️ 常为空 | ✅ 全年 |
| npMargin（净利率） | ✅ | ✅ | ✅ | ✅ |
| epsTTM | ✅ | ✅ | ✅ | ✅ |
| roeAvg | ✅ | ✅ | ✅ | ✅ |

**注意：** MBRevenue 在 Q1 和 Q3 经常为空。营收需通过其他方式推算（如 netProfit / npMargin）。

## 在 fetch_financials.py 中的调用位置

`enrich_with_baostock(data)` 函数会在 yfinance 数据采集后自动运行（仅对 .SS/.SZ 后缀的 A 股 ticker）。

当前仅获取分红数据和基本信息。最新季度数据需要手动调用——`fetch_financials.py` 尚未将该逻辑集成到自动流水线中（future improvement）。
