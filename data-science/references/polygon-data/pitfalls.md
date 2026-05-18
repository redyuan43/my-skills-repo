# Polygon.io 实际使用陷阱（2026-05-14 实测）

## Free tier 核心限制

| 限制 | 实际表现 | 影响 |
|------|---------|------|
| **5 calls/min** | 硬限制，超限返回 429 | 全量分析需 ~45 秒（5 calls × 12秒间隔） |
| **财务数据年限** | Free tier 只返回 2020 年前后数据 | **不可用于当前季度分析！**必须切换到 yfinance 补充。 |
| **K线范围** | 最近 2 年 | 够用（5年需要 Basic+） |

**核心问题：Free tier 的财务数据严重过期。** 如 Intel 最新的 Polygon 财报记录停在 2020-03-31。对于需要 TTM/最新季度数据的分析，必须用 yfinance 补充。

## 关键 API 端点与字段

### 行情 (`/v2/aggs/ticker/{t}/prev`)

```
results[0]:
  c: 昨收价
  h: 当日最高
  l: 当日最低
  o: 开盘价
  v: 成交量
  t: 时间戳(ms)
```

### 财务数据 (`/v2/reference/financials/{ticker}`)

**展平结构**（非嵌套），核心字段：

| 字段名 | 含义 | EPA计算用途 |
|--------|------|-------------|
| `revenues` | 营收 | 利润率基准 |
| `costOfRevenue` | 营业成本 | 毛利率计算 |
| `grossProfit` | 毛利 |  |
| `netIncome` | 净利润 | |
| `netCashFlowFromOperations` | 经营现金流 | FCF计算 |
| `capitalExpenditure` | 资本支出（负值） | FCF = OCF + CapEx |
| `freeCashFlow` | **自由现金流（预计算）** | 直接使用 |
| `shareBasedCompensation` | **SBC 股权激励** | 真实FCF调整 |
| `assets` | 总资产 | |
| `totalLiabilities` | 总负债 | |
| `shareholdersEquity` | 股东权益 | ROE计算 |
| `enterpriseValue` | 企业价值 | |
| `marketCapitalization` | 市值 | |
| `priceToEarningsRatio` | PE | |
| `priceToBookValue` | PB | |
| `weightedAverageShares` | 加权平均股数 | 每股计算 |

**注意：** 所有金额为原始美元值（如 `revenues: 58313000000` = $58.3B）。

### 分红 (`/v2/reference/dividends/{ticker}`)

```
results[]:
  amount: 每股分红金额
  exDate: 除权除息日
  paymentDate: 付款日
  recordDate: 登记日
```

**不要引用 `cash_amount`、`ex_dividend_date`** — 这些是旧版字段，当前 API 返回的字段名是 camelCase。

## 容错策略（Free tier 下的最佳实践）

```
美股分析:
  [1] Polygon.io → type quote + type dividends + type bars
      (行情/分红/K线可用，免费版有效)
  [2] yfinance → financials + info
      (财报必须用 yfinance，Polygon 免费版数据过时)
  [3] combine: Polygon(行情) + yfinance(财报)
```

## 其他

- SBC 字段 (`shareBasedCompensation`) 是 Polygon 对比 yfinance 的核心优势，但在免费版中只能看到历史数据。最新 SBC 数据仍需 yfinance 补充。
- 脚本中的 `api_get()` 函数自动捕获 401（Key 无效）和 429（频率限制）。
