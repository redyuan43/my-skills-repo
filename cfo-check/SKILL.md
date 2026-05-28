---
name: cfo-check
description: Use when the user wants CFO-style company fundamental analysis, A-share/HK-share data checks, investment memo drafting, valuation sanity checks, Greenwald/Buffett/McKinsey-style review, or integration of 东方财富妙想 mx-* data into a rigorous financial analysis workflow.
---

# CFO Check

## 定位

用 CFO/买方研究视角做企业基本面分析：先拿可追溯数据，再做口径校验、经营质量判断、估值和风险拆解。结论要区分事实、假设和推断；涉及金额、比率、估值和敏感假设时，用脚本或表格计算，不靠心算。

本 skill 来自 `MichaelSun/cfo-check` 的核心工作流，并在本仓库中与 `data-science` 及 `mx-*` skills 打通。

## 工作流

1. 先判断市场、任务类型与数据源：
   - A 股/港股实时行情、财务、股东、关联关系：优先用 `$mx-data`。
   - 新闻、公告、研报、政策、事件催化：优先用 `$mx-search`。
   - 条件筛选和候选池：优先用 `$mx-xuangu`。
   - 自选股维护：只在用户明确要求时用 `$mx-zixuan`。
   - 模拟组合操作：只在用户明确要求时用 `$mx-moni`，并强调它不是实盘交易。
   - 美股、SEC、Polygon、宏观时间序列、完整投研报告：用 `$data-science`。
2. 需要 API 细节时读 `references/api-data-sources.md`，优先复用 `data-science` 的密钥查找顺序和脚本入口。
3. 用 `MX_APIKEY`、`POLYGON_API_KEY`、`FINNHUB_API_KEY`、`FRED_API_KEY`、`TUSHARE_TOKEN` 等环境变量或本机私有配置读取密钥；不要把真实 key 写入报告、README 或可提交文件。
4. 每个关键数据点记录来源、抓取日期、币种、单位和口径；A 股百分比字段要区分“4.06 = 4.06%”这类口径。
5. 对核心结论做反证检查：收入质量、毛利率/费用率趋势、现金流含金量、ROIC-WACC、资本开支、SBC/回购/分红、资产负债表风险、治理与资本配置。
6. 输出默认使用中文，保留必要英文财务术语，如 ROIC、WACC、NOPLAT、MoS、FCF。

## 数据/API 快速路由

- A 股单家公司数据：`$mx-data`，脚本入口通常是 `/home/ivan/github/my-skills-repo/mx-data/scripts/mx_data.py`，输出在 `~/.mx/mx-data/output/`。
- A 股事件、公告、研报、政策：`$mx-search`，输出在 `~/.mx/mx-search/output/`。
- A 股筛选候选池：`$mx-xuangu`，输出在 `~/.mx/mx-xuangu/output/`。
- 美股价格、财务和 Polygon：`$data-science` 的 `scripts/polygon-data/polygon_data.py`。
- 一般财务抓取和 Markdown 输出：`$data-science` 的 `scripts/financial-data-acquisition/fetch_financials.py`。
- 自选股和模拟组合属于外部状态变更；只有用户明确要求时才用 `$mx-zixuan` 或 `$mx-moni`。

## 报告骨架

- 结论先行：一句话判断 + 关键 upside/downside。
- 数据来源：列出本次实际使用的数据源和时间。
- Business quality：商业模式、增长驱动、竞争格局、护城河。
- Financial quality：收入、利润、现金流、ROIC、杠杆和资本开支。
- Management & capital allocation：治理、回购、分红、并购、SBC。
- Valuation：Greenwald 三阶段、McKinsey value driver 或 Reverse DCF，按任务选择其一或组合。
- Risks & falsification：列出能推翻结论的关键证据。
- Next actions：需要补抓的数据或需要持续跟踪的事件。

## 纪律

- 金融数据属于高时效信息；用户要“最新/今日/最近”时，必须实时查询或明确说明未查询。
- 不给无依据的买卖建议；如果涉及交易动作，明确区分分析、模拟交易和真实交易。
- 东方财富妙想 API 会把查询文本发送到 `mkapi2.dfcfs.com`，调用前确认任务确实需要外部数据。
- 对关键数据至少做一次交叉检查：同源重试、公告/年报核对、或用另一个数据源 sanity check。
- 交付前执行 `scripts/selftest.sh` 检查 skill 结构；真实研究任务还要按 `references/gate_checklist.md` 做报告级校验。
