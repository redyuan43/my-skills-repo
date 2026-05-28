# CFO Check Gate Checklist

交付 CFO-style 分析前按此清单自查。

## 数据完整性

- 已确认公司、代码、市场和币种。
- 关键数据点记录了来源、抓取日期、单位和口径。
- 最新数据已实时查询；未查询时已明确说明。
- A 股核心数据优先使用 MX，必要时用公告、年报或其他源交叉检查。
- 美股或海外数据已使用 `$data-science`/Polygon/SEC 等合适入口。

## API 安全

- 没有把真实 `MX_APIKEY`、`POLYGON_API_KEY`、`FINNHUB_API_KEY`、`FRED_API_KEY`、`TUSHARE_TOKEN`、`NOTION_API_KEY` 写入可提交文件。
- 已说明 MX 查询会发送到 `mkapi2.dfcfs.com`。
- `$mx-zixuan`、`$mx-moni`、Notion 上传等外部状态变更只在用户明确要求时执行。

## 分析质量

- 事实、假设、推断分开写。
- 估值或敏感假设通过表格或脚本计算，不靠心算。
- 至少检查一个反证方向：现金流质量、ROIC-WACC、资本开支、SBC/回购/分红、资产负债表、治理、关联交易或监管风险。
- 结论包含 upside/downside 和能推翻结论的关键证据。

## Skill 结构

- `SKILL.md` 保持短而可执行。
- API 细节放在 `references/api-data-sources.md`。
- 结构自检通过：`bash scripts/selftest.sh`。
