---
name: financial-data-acquisition
description: "金融数据采集器 — 从 yfinance + SEC EDGAR + Finnhub + FRED + Baostock + Tushare + MX API (东方财富妙想) 获取结构化财报、10-K文本、Earnings Call、宏观经济、A股全面数据"
version: 2.2.0
author: Hermes Agent
---

# Financial Data Acquisition — 金融数据采集器

## 角色定位

此 skill 是 **financial-analysis skill 的数据前置层**。在分析一个标的之前，先调用此 skill 获取结构化的财务数据，然后传给 financial-analysis 进行9点深度审查。

## 触发条件
- "拉取 [代码] 的财务数据"
- "获取 [公司] 的财报信息"
- "查询 [股票] 的实时行情/财务指标"（会触发 mx-data 自然语言查询）
- 被 cfo 分析流程自动调用

## 数据源矩阵

```\n数据源       美股                  A股(.SS/.SZ)         港股(.HK)\n────────────────────────────────────────────────────────────────────\npolygon.io   行情 ✅ 财报 ✅       ❌                    ❌\n             SBC ✅ 回购 ✅\n             日K线 ✅ 分红 ✅ 拆分 ✅\n             (Free: 5calls/min, 需API Key)\nyfinance     行情 ✅ 财报 ✅      行情 ✅ 财报 ⚠️(缺SBC)   待测试\n             SBC ✅ 回购 ✅       分红 ❌ 回购 ❌ SBC ❌
baostock     ❌                  分红 ✅ 指数成分股 ✅      ❌
                                 历史K线 ✅ 行业 ✅
tushare      ❌                  前十大股东 ✅ 分红 ✅    ❌
                                 （120积分，可用free接口）
sec-edgar    10-K章节 ✅           ❌                     ❌
             Business/Risk/MD&A/ExecComp
finnhub      Earnings Call ✅       ❌                     ❌
            新闻 ✅ 内部交易 ✅
fred         宏观数据 ✅             ✅                     ✅
             国债利率/CPI/GDP/失业率/联邦基金利率
mx-api(妙想)  ❌                  行情 ✅ 财务 ✅ 股东 ✅  行情 ✅ 财务 ✅
                                  新闻 ✅ 公告 ✅ 选股 ✅  新闻 ✅ 公告 ✅
                                  自选股管理 ✅ 模拟组合 ✅
```

### yfinance — 主采集引擎（所有市场）
- 利润表/资产负债表/现金流量表 5年数据（美股完整，A股缺SBC/回购/分红）
- `info` 字典：实时股价、市值、PE、PB、股息率
- A 股后缀：上海 `.SS`，深圳 `.SZ`

### Tushare Pro — A 股补充数据（前十大股东 + 分红，需 API Token）

**状态：** 2026-05-06 接入，积分120。仅对 A 股（.SS/.SZ）生效。
**安装：** `pip install tushare`
**Token 配置：** `config/api_keys.json` 中 `tushare_token` 字段

**可获取的数据（当前积分可用）：**

| 接口 | 积分 | 状态 | 内容 |
|------|------|------|------|
| `dividend` | 200 | ✅ 实测可用 | 历年分红明细（除权除息日、每股税前/税后、送转股） |
| `top10_holders` | 200 | ✅ 实测可用 | 前十大股东（持股数量、持股比例、公告日期） |
| `daily` | 0 | ✅ 免费 | 日线行情 |
| `adj_factor` | 0 | ✅ 免费 | 复权因子 |
| `income` | 200 | ❌ 积分不足 | 利润表 |

**积分不够的接口：** `income`（利润表）、`balancesheet`（资产负债表）、`cashflow`（现金流）、`fina_indicator`（财务指标）、`fina_mainbz`（主营构成）—— 需要200+积分，当前120分不足。

**在 fetch_financials.py 中的调用位置：** `enrich_with_tushare(data)` — A 股(.SS/.SZ) 自动触发，输出至 `data["tushare"]`

### Baostock — A 股数据补充（pip install baostock，无需注册）

**核心用途：** 补 yfinance 缺失的 A 股分红数据，以及**在 yfinance 尚未更新时提前获取最新季度的净利润、净利率、EPS_TTM 等关键财务指标**（如2026 Q1数据，yfinance未收录时baostock已可用）。

**可获取的数据：**
- ✅ **每股现金分红**（税前/税后、除权日、宣告日）— `query_dividend_data()`
- ✅ **最新季度净利润、净利率、EPS_TTM、ROE** — `query_profit_data()`（比 yfinance 更及时）
- ✅ **指数成分股**：沪深300/中证500/上证50 — `query_hs300_stocks()` 等
- ✅ **历史日K线**：日/周/月 — `query_history_k_data_plus()`
- ✅ **股票基本信息**：上市日期、状态 — `query_stock_basic()`
- ✅ **杜邦ROE分解**：`query_dupont_data()`

**不能补：** 详细财报科目、SBC、回购

**在 fetch_financials.py 中的调用位置：** `enrich_with_baostock(data)` — A 股(.SS/.SZ) 自动触发，输出至 `data["baostock"]`

### SEC EDGAR — 美股10-K定性信息（免费、无需注册）
- CIK 查询：`sec.gov/files/company_tickers.json`（官方 ticker→CIK 映射）
- 10-K 提交信息：`data.sec.gov/submissions/CIK{cik}.json`
- 提取章节：Business(Item 1)、Risk Factors(Item 1A)、MD&A(Item 7)、Executive Compensation(Item 11)
- **章节长度：** 每章节最多提取 100,000 字符（约50页文本）。大公司的 MD&A 和 Risk Factors 可能触顶100K，但已足够定性分析使用。
- **注意：** 10-K 的 HTML 格式因公司而异（ITEM 1. vs ITEM I. vs 1. Business），正则提取可能不完美。部分 ExecComp 章节引用至 Proxy Statement（DEF 14A），需单独获取。

### Finnhub — 美股 Earnings Call + 新闻（需 API Key）
- 需要有效 API Key 在 `config/api_keys.json`
- 安装：`pip install finnhub-python`
- 注册：https://finnhub.io/register（免费 tier：60次/分钟）
- 数据内容：`latest_earnings`、`earnings_transcript`、`recent_news`、`insider_transactions`
- 输出位置：`data["finnhub"]`

### FRED（圣路易斯联储）— 宏观经济数据（需 API Key）
- 需要有效 API Key 在 `config/api_keys.json`
- 安装：`pip install fredapi`
- 注册：https://fred.stlouisfed.org/docs/api/api_key.html
- 数据内容：10年国债收益率、联邦基金利率、CPI同比、失业率、名义GDP
- 输出位置：`data["fred"]`
- 适用于所有市场（WACC 计算中的无风险利率 Rf 来源于此）

### MX API（东方财富妙想）— A 股官方数据通道（2026-05-13 新增）

**状态：** 2026-05-13 接入，无需积分、无需注册（通过东方财富APP或微信扫码免费领取 API Key）。
**适用市场：** A股 ✅ 港股 ✅ 美股 ❌
**安装：** 无需安装库，直接 HTTP POST 请求。

#### 可用接口

| 接口 | API 端点 | 功能 |
|------|---------|------|
| `mx-data` | `POST /finskillshub/api/claw/query` | 行情、财务、股东、关联关系数据查询 |
| `mx-search` | `POST /finskillshub/api/claw/news-search` | 新闻、公告、研报、政策搜索 |
| `mx-xuangu` | 智能选股 | 按行情/财务/技术指标筛选股票 |
| `mx-zixuan` | 自选管理 | 东方财富通行证自选股增删查 |
| `mx-moni` | 模拟组合 | 模拟买卖、持仓、委托、历史成交 |

#### 配置

```bash
# 环境变量
export MX_APIKEY="mkt_xxxxx"

# 申请地址
# https://dl.dfcfs.com/m/itc4 → 东方财富APP/微信扫码 → 免费领取
```

#### 使用方法（自然语言查询）

```bash
# mx-data 查询
python3 ~/.hermes/skills/mx-data/mx_data.py "东鹏饮料 最新价 总市值 PE ROE"
# 输出：Excel + JSON + 终端预览

# mx-search 搜索
python3 ~/.hermes/skills/mx-search/mx_search.py "贵州茅台 2025年最新公告"

# mx-xuangu 选股
python3 ~/.hermes/skills/mx-xuangu/mx_xuangu.py "筛选PE<20且ROE>20%的消费股"
```

### Polygon.io — 美股替代数据通道（2026-05-13 新增）

**状态：** 2026-05-13 接入，需 API Key（Free tier: 5 calls/min）。
**⚠️ Free tier 局限：** 财务数据仅返回 2020 年前后记录，**最新季度数据不可用**。行情/K线/分红可用但数据年限受限。见 `skills/polygon-data/references/pitfalls.md`。
**适用市场：** 美股 ✅ A股 ❌ 港股 ❌ 加密货币 ✅

#### 配置

```bash
# 环境变量
export POLYGON_API_KEY="your_key_here"

# 申请地址
# https://polygon.io/dashboard/signup → Free/Basic/Starter/Pro 方案
```

#### 使用方法

```bash
# 查询行情
python3 ~/.hermes/skills/polygon-data/polygon_data.py --ticker AAPL --type all
# 输出：JSON 到 ~/.polygon_data/output/
```

#### 在美股分析中的作用

| 数据类型 | 替代目标 | 优势 |
|---------|---------|------|
| 结构化财报 | yfinance 财报 | 标准GAAP字段，含SBC/回购 |
| 日K线 | yfinance history | 原生JSON格式，稳定 |
| 分红/拆分 | yfinance 分红 | 结构化字段 |

**美股数据获取优先级（更新后）：**

| 优先级 | 数据源 | 适用场景 | 速度 | 可靠性 |
|--------|--------|---------|------|--------|
| 1 | **Polygon.io** | 美股行情/财报/K线/分红 | 1-3s | ✅ 结构化API稳定 |
| 2 | yfinance | 美股备用/快速查询 | 1-2s | ⚪ 偶有CAPTCHA |
| 3 | SEC EDGAR | 10-K文本（Business/Risk/MD&A） | 5-10s | ✅ 免费无限制 |
| 4 | Finnhub | Earnings Call转录 | 3-5s | ⚪ 免费tier有限 |

---

#### A股数据获取优先级

| 优先级 | 数据源 | 适用场景 | 速度 | 可靠性 |
|--------|--------|---------|------|--------|
| 1 | MX API（自然语言） | 快速查询行情/财务/股东 | 1-3s | ✅ 官方API非常稳定 |
| 2 | yfinance + Baostock | 5年财务报表历史趋势 | 10-30s | ⚪ A股缺SBC/回购 |
| 3 | Tushare | 前十大股东、分红明细 | 5-10s | ✅ 免费积分有限 |
| 4 | qt.gtimg.cn（腾讯） | 实时行情最终兜底(A/H/U) | 0.1s | ✅ 无反爬无需Key |
| 5 | Agent web search | 定性信息补充 | 不等 | ⚠️ 需手动校核 |

#### 已知问题与处理方式（2026-05-13 验证）

| 问题 | 原因 | 处理方式 |
|------|------|---------|
| push2.eastmoney.com 超时 | macOS/非大陆网络被屏蔽 | 改用 MX API 或 qt.gtimg.cn 兜底 |
| mx-data Python 脚本写 `/root/.openclaw/` | 默认路径硬编码 | 已修补到 `~/.mx_data/output/`；所有 5 个 mx-* 脚本同样已修补 |
| hermes skills install 不支持本地路径 | 只能接受 URL/hub ID | 手动 `cp -R` 到 `~/.hermes/skills/<name>/` |
| **环境变量在 terminal 子进程中不可见** | Hermes 过滤子进程环境，仅 `.env` 在 agent 启动时加载的变量可穿透 | 将 API Key 写入 profile 的 `.env`（如 `profile/cfo/.env`）后重启 agent；或在同一命令行 export 再执行脚本 |

> ⚠️ **环境变量穿透规则：** `terminal` tool 的子进程继承经过滤的环境。仅在 agent 启动时从 `.env` 加载的变量（MX_APIKEY, NOTION_API_KEY 等）在 terminal 中可见。直接用 `export` 设的变量仅在 agent 进程内有效。如需临时测试，用 `export KEY=val && python3 script.py` 单行命令。

## API Key 配置

所有 API Key 集中在 `.hermes/.env` 或对应 profile 的 `.env` 中：

```
# MX_APIKEY 在 profile 的 .env 中配置
MX_APIKEY=mkt_xxxxx

# 经典数据源的 key 在 config/api_keys.json
finnhub_api_key=your_key_here
fred_api_key=your_key_here
```

## 脚本：fetch_financials.py

### 用法
```bash
python3 scripts/fetch_financials.py --ticker AAPL                  # 美股（yfinance + SEC + Finnhub + FRED）
python3 scripts/fetch_financials.py --ticker AAPL --format markdown # 人类可读版
python3 scripts/fetch_financials.py --ticker 601398.SS              # A 股（yfinance + baostock + FRED）
```

### 数据获取流水线（按顺序执行）

```
yfinance 采集 → 派生指标计算 → baostock补充(A股专属) → SEC EDGAR补充(美股专属)
→ Finnhub补充(美股专属) → FRED补充(通用) → 输出JSON
```

如需 A 股完整数据（行情+财务+新闻+股东），建议同时用 MX API 补充：
```python
# 在 fetch_financials.py 中或分析时手动调
from lib.mx_api import MXClient
client = MXClient()
snapshot = client.fetch_snapshot("605499")  # 实时行情+估值
data = client.query("605499 东鹏饮料 2025年营业收入 净利润 毛利率")
```

### 输出 JSON 结构
```json
{
  "ticker": "CROX",
  "income_statement": [...],          ← yfinance: 5年利润表
  "balance_sheet": [...],             ← yfinance: 5年资产负债表
  "cash_flow": [...],                 ← yfinance: 5年现金流量表
  "derived_metrics": {...},           ← 计算: FCF收益率/ROIC/毛利率趋势等
  "baostock": {                       ← A股专属: 分红明细
    "dividends": [...],
    "latest_dividend_per_share": 0.3064
  },
  "sec_edgar": {                      ← 美股专属: 10-K文本章节
    "cik": "1334036",
    "latest_10k": {"period": "2025-12-31"},
    "sections": {"business_description": "...", "risk_factors": "...", ...}
  },
  "finnhub": {                        ← 美股专属: Earnings Call + 新闻
    "latest_earnings": {...},
    "recent_news": [...],
    "insider_transactions": [...]
  },
  "fred": {                           ← 通用: 宏观经济
    "10y_treasury_yield_pct": 4.36,
    "cpi_yoy_change_pct": 3.29
  }
}
```

## A 股注意事项（已验证）

- SBC/回购：yfinance 上几乎全为 N/A（A股公司不单独披露）
- 分红：yfinance 字段不统一，需用 baostock 补充。**caution: 即使 yfinance 有 dividends_paid 字段（cashflow 表），A 股公司这字段也经常为空**，必须依赖 Baostock query_dividend_data() 或 MX API。
- 银行/保险资产负债表：科目映射不准，总负债可能偏低
- 股息率格式：A股返回百分比（4.06=4.06%），美股返回小数（0.0038=0.38%）
- `industry` 字段在 baostock 中当前返回为空（列名映射待修复）
- **accounts_receivable 字段缺失**：部分 A 股（纺织、消费行业常见）的 BS 中没有 accounts_receivable 键，被归入未映射的 other_current_assets。ARV 计算时需手动核对或跳过。
- **ROIC 脚本对 A 股返回 None**：analyze_roic_wacc_spread.py 对 A 股的特殊科目（递延所得税、专项储备）映射不完全，可能返回 None。回退到从 financials JSON 手动计算 NOPLAT/投入资本。

## 已知陷阱

### `~` 路径解析陷阱（cfo profile 专属）

在 cfo profile 下，`~` 展开为 `/Users/michael/.hermes/profiles/cfo/home/` 而非 `/Users/michael/`。

```python
os.path.expanduser("~/.hermes/skills/")  
# → /Users/michael/.hermes/profiles/cfo/home/.hermes/skills/  # 错误！
# 实际脚本在: /Users/michael/.hermes/profiles/cfo/skills/     # 正确路径
```

**影响范围：** 所有在 terminal 中通过 `python3 ~/.hermes/skills/.../script.py` 执行的脚本。
**规则：** 引用 skill 自身文件用相对路径或脚本绝对路径。输出目录用 `os.path.expanduser("~/.polygon_data/output/")` 没问题（profile home 下可读写）。

### 银行股 FCF 陷阱

详见 `references/industry-data-pitfalls.md`：
- 银行股 FCF 陷阱（经营现金流 ≠ 可分配利润）
- 重资产企业 ROIC 偏低的常态 vs 边际回报率
- Web 搜索 CAPTCHA 拦截（Bing/Google 自动化搜索受限）
- 10-K HTML 章节格式不一致（ITEM 1 vs ITEM I vs Item 1）

### 中国互联网/科技公司现金数据遗漏

**问题:** yfinance 将中国公司的短期理财、定期存款放在 `Other Short Term Investments` 字段，而不是 `Short Term Investments`。脚本的 `BALANCE_MAP` 只映射了 `Cash And Cash Equivalents` 和 `Short Term Investments`，导致漏掉 ¥158亿（BZ案例：现金+短期投资实际 ¥199.5亿，只拿到 ¥41亿）。

### ADR 币种陷阱 — 不同币种间的估值比较

详见 `references/adr-currency-pitfalls.md`。

**核心规则：** 对于中国 ADR 股票，所有分析脚本从 `yf.info["currentPrice"]` 读取的是 **USD** 价格，而财务报表是 **CNY**。必须统一币种后才能进行估值比较（如净现金/市值、PE 等）。

**工作流中的强制检查：** 每次运行 `cross_validate.py` 时，C2 检查会检测净现金/市值 > 80%，这对 ADR 是**预期的、非致命的**。正确做法：
1. 收到 C2 错误 → 确认标的为 ADR → 执行 CNY 统一换算后继续
2. 非 ADR 标的的 C2 错误 → 才需要暂停修复

### 数据预警系统（`_warnings`）

`fetch_financials.py` 现在在 `derived_metrics` 中自动生成 `_warnings` 数组，覆盖以下场景：

| 触发条件 | 示例消息 | 含义 |
|---------|---------|------|
| 现金/市值 > 100% | ⚠️ 现金/市值=320% > 100%, 请检查币种一致性 | 现金和市值可能在不同币种（常见于中国ADR：现金在CNY，市值在USD） |
| ROIC > 200% | ⚠️ ROIC=810% > 200%, 投入资本过小, ROIC分母失真 | 净现金≈权益时ROIC计算无意义，需剔除冗余现金重算 |
| auto_total_cash 与 total_cash_and_st_investments 差异>1% | ⚠️ 现金合计不匹配: 自动汇总 vs yfinance合计 | 有未知现金类字段遗漏 |
| total_current_assets + total_non_current_assets ≠ total_assets | ⚠️ 资产负债表完整性: 差异>5% | 部分资产类别未覆盖 |

**使用方式：** `main()` 函数在计算派生指标后遍历并打印所有 `_warnings`。各 skill（financial-analysis/reasoning_review/buffett_review/critical_review）在读取 JSON 时也应检查此数组。

## 参考文档

- `references/mx-api-guide.md` — MX API（东方财富妙想）详细配置与使用指南
- `references/polygon-guide.md` — Polygon.io 美股数据源配置与使用指南
- `references/baostock-quarterly-timing.md` — Baostock 季度数据时效说明
- `references/baostock-guide.md` — Baostock 完整使用参考
- `references/adr-currency-pitfalls.md` — ADR 币种统一处理协议
- `references/industry-data-pitfalls.md` — 行业数据陷阱与处理
- `references/sec-edgar-guide.md` — SEC EDGAR 10-K 提取指南
- `references/finnhub-guide.md` — Finnhub API 使用指南
