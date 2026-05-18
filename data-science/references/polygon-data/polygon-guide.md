# Polygon.io 数据源参考

> 美股结构化数据源，作为 yfinance 的替代/补充
> 版本：1.0 — 2026-05-13

## 数据能力矩阵

| 数据类 | Polygon REST 端点 | Free tier | 付费 tier |
|--------|------------------|-----------|-----------|
| 实时行情 | `/v2/aggs/ticker/{t}/prev` | ✅ 5/min | ✅ 无限制 |
| 日K线 | `/v2/aggs/ticker/{t}/range/1/day/{from}/{to}` | ✅ 5/min | ✅ 无限制 |
| 分钟K线 | `/v2/aggs/ticker/{t}/range/1/min/{from}/{to}` | ❌ | ✅ |
| 财报(10-K/Q) | `/v2/reference/financials/{t}` | ✅ 5/min | ✅ 无限制 |
| 公司信息 | `/v3/reference/tickers/{t}` | ✅ 5/min | ✅ 无限制 |
| 分红 | `/v2/reference/dividends/{t}` | ✅ 5/min | ✅ 无限制 |
| 拆股 | `/v2/reference/splits/{t}` | ✅ 5/min | ✅ 无限制 |
| 新闻 | `/v2/reference/news` | ❌ | ✅ |

> ⚠️ v3 财务端点不可用: `/v3/reference/financials` 返回 404。必须用 `/v2/reference/financials/{ticker}`。

## 财报数据结构（核心 v2 API）

Polygon `/v2/reference/financials/{ticker}` 返回展平 JSON（单层，103+ 字段），核心字段：

```
results[]
├── ticker              # AAPL
├── period              # QA(季度)/Q1/Q2/Q3/Q4/FY
├── calendarDate        # 2024-12-31
├── reportPeriod        # 报告期
├── revenues            # 营业收入
├── costOfRevenue       # 营业成本
├── grossProfit         # 毛利
├── operatingExpenses   # 经营费用
├── netIncome           # 净利润
├── netCashFlowFromOperations  # 经营现金流
├── capitalExpenditure  # 资本支出
├── freeCashFlow        # 自由现金流（预计算）
├── shareBasedCompensation     # ✅ SBC 股权激励（yfinance缺这个）
├── assets              # 总资产
├── totalLiabilities    # 总负债
├── shareholdersEquity  # 股东权益
├── enterpriseValue     # 企业价值
├── marketCapitalization # 市值
├── priceToEarningsRatio # PE
├── priceToBookValue    # PB
└── weightedAverageShares     # 加权平均股数
```

## 分红数据结构

```
results[]
├── ticker         # AAPL
├── amount         # 每股分红金额 (0.27)
├── exDate         # 除权日 (2026-05-11)
├── paymentDate    # 付款日 (2026-05-14)
└── recordDate     # 登记日 (2026-05-11)
```

## 关键陷阱

### 陷阱1: 环境变量隔离

Hermes Agent 的 `terminal` tool 对子进程进行环境变量过滤。脚本 `os.environ.get("POLYGON_API_KEY")` 在以下情况会拿到空值：

```
❌ export POLYGON_API_KEY=xxx → 仅在agent进程有效，terminal不可见
❌ 写在 ~/.bashrc 中 → terminal 不加载 shell init files
✅ 写在 profile 的 .env 中 → agent 启动时加载，terminal 可见
✅ 用同一命令行 export + 执行 → export POLYGON_API_KEY=xxx && python3 script.py
```

**修复方式：** 将 `POLYGON_API_KEY` 写入 `/Users/michael/.hermes/profiles/cfo/.env`，重启 agent。

### 陷阱2: `~` 路径解析

在 cfo profile 下，`~` 展开为 `/Users/michael/.hermes/profiles/cfo/home/` 而非 `/Users/michael/`。

```python
# 实际路径
os.path.expanduser("~/.polygon_data/output/")
# → /Users/michael/.hermes/profiles/cfo/home/.polygon_data/output/
```

脚本中不建议使用硬编码路径，用 `~/.polygon_data/output/` 可靠（profile home 下可读写）。

### 陷阱3: v3 API 不可用

- `/v3/reference/financials` → 404 (Not Found)
- `/v2/reference/financials/{ticker}` → 200 (OK)
- 如需未来切换到 v3，先测试端点可用性再迁移

### 陷阱4: Free tier 频率限制

5 calls/min。`--type all` 会调用 4 个端点（quote + financials + bars + dividends），可能需要 48s+ 才能完成。建议用 `sleep 12` 间隔或只查需要的类型。

## 与 yfinance 的关键差异

| 维度 | Polygon.io | yfinance |
|------|-----------|----------|
| **SBC字段** | ✅ `shareBasedCompensation` | ❌ 有时缺失 |
| **回购字段** | ✅ `treasury_stock_value` | ⚠️ 不完整 |
| **可靠性** | ✅ 官方API，无反爬 | ⚠️ 偶有CAPTCHA/变更 |
| **免费限制** | 5 calls/min | 无频率限制但非官方 |
| **数据结构** | 展平JSON（单层103字段） | 嵌套DataFrame |

## 已知限制

1. **Free tier 5 calls/min** — 批量分析时需串行调用
2. **不支持 A 股/港股** — 仅美股+加密货币
3. **财报映射略有延迟** — 10-K/Q 提交后通常 24-48h 上链
4. **付费方案较贵** — Basic $29/月起
