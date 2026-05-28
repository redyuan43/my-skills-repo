# CFO Check API/Data Sources

本文件只记录 `cfo-check` 需要调用和路由的数据能力。更完整的数据工程说明保留在 `$data-science`，本 skill 只做 CFO 研究任务的最小可用索引。

## 密钥读取顺序

优先沿用 `$data-science` 的配置习惯：

1. 当前进程环境变量：`MX_APIKEY`、`POLYGON_API_KEY`、`FINNHUB_API_KEY`、`FRED_API_KEY`、`TUSHARE_TOKEN`、`NOTION_API_KEY`
2. `/home/ivan/github/my-skills-repo/data-science/scripts/config/api_keys.json`
3. `/home/ivan/github/my-skills-repo/data-science/.env.local`
4. `~/.hermes/skills/data-science/financial-data-acquisition/config/api_keys.json`
5. `~/.hermes/.env`

不要把真实 key 写进本目录。可提交文件里只能出现变量名或占位说明。

## 东方财富妙想 MX

MX 是 A 股优先数据源，适合行情、财务、股东、行业、公告、研报、政策、筛选和模拟组合。官方接口会向 `https://mkapi2.dfcfs.com/finskillshub/api/claw/query` 发送请求，请求头使用 `apikey: $MX_APIKEY`，请求体核心字段是 `toolQuery`。

| 任务 | 首选 skill | 本地脚本 | 输出目录 |
| --- | --- | --- | --- |
| 公司行情、财务、股东、关联关系 | `$mx-data` | `/home/ivan/github/my-skills-repo/mx-data/scripts/mx_data.py` | `~/.mx/mx-data/output/` |
| 新闻、公告、研报、政策、事件催化 | `$mx-search` | `/home/ivan/github/my-skills-repo/mx-search/scripts/mx_search.py` | `~/.mx/mx-search/output/` |
| 条件选股、行业/指数/估值/分红筛选 | `$mx-xuangu` | `/home/ivan/github/my-skills-repo/mx-xuangu/scripts/mx_xuangu.py` | `~/.mx/mx-xuangu/output/` |
| 自选股查询/新增/删除 | `$mx-zixuan` | `/home/ivan/github/my-skills-repo/mx-zixuan/scripts/mx_zixuan.py` | `~/.mx/mx-zixuan/output/` |
| 模拟组合持仓/下单/撤单/发帖 | `$mx-moni` | `/home/ivan/github/my-skills-repo/mx-moni/scripts/mx_moni.py` | `~/.mx/mx-moni/output/` |

常用命令模板：

```bash
MX_APIKEY="$MX_APIKEY" python3 "/home/ivan/github/my-skills-repo/mx-data/scripts/mx_data.py" "贵州茅台 600519 2021-2025 年报 营收 净利润 经营现金流 ROE 毛利率 资本开支 分红"
MX_APIKEY="$MX_APIKEY" python3 "/home/ivan/github/my-skills-repo/mx-search/scripts/mx_search.py" "贵州茅台 2025 年报 公告 分红 回购 经营风险"
MX_APIKEY="$MX_APIKEY" python3 "/home/ivan/github/my-skills-repo/mx-xuangu/scripts/mx_xuangu.py" "A股 食品饮料 ROE连续三年大于15% 股息率大于2% 市值大于500亿"
```

使用注意：

- 单家公司查询要带中文名、代码、年份、报表类型和指标名，避免一次请求过宽。
- MX 返回有随机性；关键查询可重试 2-3 次，并记录采用哪次结果。
- JSON 原始结果常见数据表路径是 `data.data.searchDataResultDTO.dataTableDTOList`。
- A 股百分比字段通常已经是百分数，例如 `4.06` 表示 `4.06%`。
- yfinance 对 A 股 SBC、回购、分红、ROE、行业分类经常不完整，A 股优先用 MX。
- A+H 公司要核对 H 股报告，特别是折旧摊销、少数股东权益和分部口径。
- `$mx-zixuan` 和 `$mx-moni` 会改变外部状态；只有用户明确要求时才执行，模拟组合必须说明不是实盘。

## Data Science

`$data-science` 是美股、Polygon、通用财务抓取、宏观数据和完整投研流水线的主入口。

| 任务 | 推荐入口 | 需要密钥 |
| --- | --- | --- |
| Polygon 美股行情、财务、新闻 | `/home/ivan/github/my-skills-repo/data-science/scripts/polygon-data/polygon_data.py` | `POLYGON_API_KEY` |
| 通用财务抓取到 Markdown | `/home/ivan/github/my-skills-repo/data-science/scripts/financial-data-acquisition/fetch_financials.py` | 视数据源而定 |
| Finnhub 数据 | `$data-science` 配置和脚本 | `FINNHUB_API_KEY` |
| FRED 宏观时间序列 | `$data-science` 配置和脚本 | `FRED_API_KEY` |
| Tushare 补充 A 股数据 | `$data-science` 配置和脚本 | `TUSHARE_TOKEN` |
| Notion 上传 | 只在用户明确要求时使用 | `NOTION_API_KEY` |

常用命令模板：

```bash
set -a; test -f "/home/ivan/github/my-skills-repo/data-science/.env.local" && source "/home/ivan/github/my-skills-repo/data-science/.env.local"; set +a
python3 "/home/ivan/github/my-skills-repo/data-science/scripts/polygon-data/polygon_data.py" --ticker AAPL --type all
python3 "/home/ivan/github/my-skills-repo/data-science/scripts/financial-data-acquisition/fetch_financials.py" --ticker AAPL --format markdown
```

## CFO 分析取数清单

单家公司研究至少覆盖：

- 收入、毛利、营业利润、净利润、EPS、股本变化。
- 经营现金流、资本开支、FCF、营运资本变化。
- ROE、ROIC、资产周转、毛利率、费用率、税率、负债率。
- 分红、回购、SBC、并购、重大关联交易。
- 分业务/分地区收入和利润，必要时补公告或年报原文。
- 同业估值、历史估值区间、利率或宏观假设。

交付报告时，每个关键表格都要包含来源、抓取日期、币种、单位和口径。
