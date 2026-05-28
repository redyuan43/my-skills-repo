# Optimizer Memory

本文件记录 `cfo-check` 后续迭代时应保留的经验，避免把同样的问题反复改回去。

## 已确认方向

- `cfo-check` 的定位是 CFO/买方研究路由和质量门禁，不是替代 `$data-science`、`$mx-data` 或其他数据 skill。
- 主 `SKILL.md` 要短，适合模型快速加载；长 API 细节放进 `references/`。
- A 股优先走 MX；美股、Polygon、宏观和完整数据科学流水线优先走 `$data-science`。
- 自选股、模拟组合、Notion 上传属于外部状态变更，必须等待用户明确要求。

## 易错点

- 不要把真实 API key 写入 skill、README、eval 或报告模板。
- 不要把金融分析写成无来源的投资建议。
- 不要只给估值结论；必须列出可推翻结论的证据。
- 不要把 MX 的百分比字段当小数二次换算。
- A+H 公司不要只看 A 股口径，关键会计科目要核对 H 股报告。

## 后续可评估的问题

- 是否需要把常见 CFO 表格做成脚本模板。
- 是否需要加入 Reverse DCF/Greenwald/McKinsey value driver 的最小计算器。
- 是否需要为 A 股、港股、美股分别建立报告示例。
