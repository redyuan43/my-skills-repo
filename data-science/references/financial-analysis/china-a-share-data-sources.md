# 中国 A 股数据源指引

> ⚠️ 关键信号：当用户问「妙想的 skill」时，指的是 mx-* 前缀的全部技能（mx-data / mx-search / mx-xuangu / mx-zixuan / mx-moni），而非特定某个。切勿回答「没有妙想 skill」。

## 妙想 (mx-*) 技能全景

东方财富妙想 Skills Hub 提供了 5 个 mx-* skill，覆盖整个 A 股分析工作流：

| Skill | 文件名 | 用途 | 在 CFO 分析中的角色 |
|-------|--------|------|-------------------|
| **mx-data** | `mx-data/SKILL.md` | 金融数据查询（行情、财务、关联关系） | **主力数据源** — 覆盖 yfinance 缺失的 A 股 SBC/回购/分红/细分行业 ROE |
| **mx-search** | `mx-search/SKILL.md` | 妙想搜索 — 新闻、公告、研报、政策、事件解读 | **时效性信息** — 财报解读、机构观点、行业政策变化 |
| **mx-xuangu** | `mx-xuangu/SKILL.md` | 智能选股 — 按行情/财务指标筛选股票 | **筛选管道** — 初筛后由 financial-analysis 做深度分析 |
| **mx-zixuan** | `mx-zixuan/SKILL.md` | 自选股管理 — 查询/添加/删除 | **跟踪管理** — 维护观察列表 |
| **mx-moni** | `mx-moni/SKILL.md` | 模拟组合管理 — 买卖/撤单/持仓/资金查询 | **策略验证** — 模拟盘验证投资假设 |

**所有 mx-* 技能共用同一 API Key**：`MX_APIKEY`（从 https://dl.dfcfs.com/m/itc4 获取）。

调用方式 — 用 skill_view 加载后直接使用 mx_data.py / mx_search.py / mx_xuangu.py 等 Python 脚本，通过自然语言查询。

**在 CFO 分析中的推荐调用顺序：**
1. `mx-xuangu` → 初筛候选标的
2. `mx-search` → 获取标的近期新闻/研报/公告（补充管理层评估）
3. `mx-data` → 拉取精确财务数据（替代/校验 yfinance）
4. `mx-zixuan` → 将关注标的加入自选跟踪
5. `mx-moni` → 验证交易策略（可选）

> 适用场景：CFO 分析 A 股时选择最佳数据通道
> 版本：1.0 — 2026-05-13 实战经验总结

## 数据源质量分级

| 等级 | 数据源 | 覆盖范围 | 速度 | 海外可用 | 适用场景 |
|------|--------|---------|------|---------|---------|
| 🥇 | **mx-data (东方财富妙想API)** | A股全量 | 1-3s | ✅ 稳定 | **首选手工查询** |
| 🥇 | **yfinance** | 美股+A股基础 | 1-2s | ✅ | 美股主力，A股兜底 |
| 🥈 | **akshare (同花顺通道)** | A股财务 | 0.3-2s | ⚠️ 有时限 | A股财务数据 |
| 🥉 | **qt.gtimg.cn (腾讯行情)** | A/H/U 三市 | 0.1s | ✅ **最稳定** | 实时行情兜底 |
| ❌ | **push2.eastmoney.com** | A股实时 | — | ❌ 海外常被屏蔽 | **不要依赖** |

## 关键发现（macOS 海外/非大陆网络环境）

### push2.eastmoney.com 被屏蔽
这是 akshare A股数据的主路径。在海外网络/特定 VPN 下 SSL 握手失败。

**诊断命令：**
```bash
python3 -c "
import requests
try:
    r = requests.get('https://push2.eastmoney.com/api/qt/stock/get?secid=1.605499&fields=f43,f44,f45', timeout=5)
    print('OK' if r.ok else f'HTTP {r.status_code}')
except Exception as e:
    print(f'BLOCKED: {str(e)[:80]}')
"
```

### qt.gtimg.cn（腾讯行情）始终可用
作为 push2 兜底，无论在哪都能 0.1s 返回。支持三市场：
- A股：`sh605499` / `sz300059`
- 美股：`usBZ` / `usPDD`
- 港股：`hk00700`

```bash
curl -s "https://qt.gtimg.cn/q=sh605499" | iconv -f GBK -t UTF-8
```

### MX_APIKEY 是官方解法
东方财富妙想 Skills Hub 提供官方 API（`mkapi2.dfcfs.com`），绕过 push2。
- 申请：https://dl.dfcfs.com/m/itc4（需东方财富APP领取）
- 配置：`export MX_APIKEY=your_key`
- 测试：
```bash
curl -s -X POST "https://mkapi2.dfcfs.com/finskillshub/api/claw/query" \
  -H "Content-Type: application/json" \
  -H "apikey: $MX_APIKEY" \
  -d '{"toolQuery":"605499 最新价 总市值 PE"}' | python3 -m json.tool
```

## CFO 分析 A 股时的数据获取策略

按优先级选择：

```
A股手工查询 → 用 mx_data.py（自然语言，覆盖最全）
   ↓ 不可用时
A股自动采集 → yfinance（基础数据）+ akshare 同花顺通道（财务数据）
   ↓ 行情缺失
腾讯 qt.gtimg.cn 兜底（实时价/市值）
```

### mx_data.py 用法

```bash
cd ~/.hermes/skills/mx-data
MX_APIKEY=your_key python3 mx_data.py "东鹏饮料 最新价 总市值 PE ROE 营收增速"
```

输出：
- 终端预览前20行
- Excel 文件存储到 `~/.mx_data/output/`
- 原始 JSON 到 `~/.mx_data/output/mx_data_{query}_raw.json`

### mx-data 原始 JSON 数据提取指南

脚本的输出文件 `mx_data_{query}_raw.json` 的 JSON 结构为三层嵌套：

```python
d['data']['data']['searchDataResultDTO']['dataTableDTOList']
```

每个 `dataTableDTO` 包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `title` | str | 数据标题 |
| `entityName` | str | 证券全称 |
| `table` | dict | 表格数据 — `headName` 为行标签（年份），其他 key 为数据列 |
| `nameMap` | dict | 列名映射（编码→中文名） |
| `field` | dict | 指标元信息 |

**提取示例：**
```python
tables = d['data']['data']['searchDataResultDTO']['dataTableDTOList']
for t in tables:
    head_names = t['table'].get('headName', [])  # 行标签（如：['2025年报','2024年报','2023年报']）
    name_map = t.get('nameMap', {})
    for key, vals in t['table'].items():
        if key != 'headName':
            col_name = name_map.get(key, key)
            # vals 是对应年份的值列表
```

> ⚠️ `data` 字段在 JSON 中是嵌套的：顶层是 `{"success": true, "data": {"data": {...}}}`。
> 所以完整路径是 `d["data"]["data"]["searchDataResultDTO"]["dataTableDTOList"]`。

### 双地上市公司的数据陷阱（A+H 重大差异）

中国移动等 A+H 双地上市公司，A 股报表与港股报表的**折旧摊销（D&A）口径完全不同**：

| 项目 | 600941 A股 | 0941.HK 港股 |
|------|-----------|-------------|
| 折旧摊销(2024) | ¥66.3亿（仅无形资产摊销） | HK$2,064亿（含固定资产折旧+无形资产摊销） |
| 差异原因 | A股只披露"摊销"行，折旧藏在营业成本中 | 港股按 HK GAAP 单独列出折旧与摊销 |
| CapEx(2024) | ¥1,560亿 | HK$2,000亿 |

**教训：分析双地上市的中国公司时，永远不要只信 A 股披露的 D&A 数字。** A 股利润表中的"折旧摊销"可能只含摊销，不含固定资产折旧。必须交叉验证港股报表或从资产负债表推算。

**快速推算方法：**
```python
# 从固定资产原值变动估算年折旧
pp_e_begin = 22946  # 上年末固定资产原值
pp_e_end = 23617    # 本年末固定资产原值
additions = 1570    # 当年 CapEx（购建固定/无形资产支付的现金）
implied_depreciation = pp_e_begin + additions - pp_e_end
# = 22946 + 1570 - 23617 = 899亿（仅为部分折旧，含处置）
# 更准确：查看港股披露的"折旧与摊销"行
# 港股0941.HK 的"折旧与摊销"是完整数字
```

### 数据完整性注意事项

- **收益率格式**：A股返回百分比（4.06=4.06%），美股返回小数
- **SBC/回购/分红**：A股在 yfinance 上大多缺失，需用 mx-data 补充
- **行业分类**：yfinance 对 A 股的行业映射不准（多为 Beverages - Non-Alcoholic 等大分类），mx-data 返回东方财富的精确行业分类
- **ROE 数据**：yfinance 对 A 股的 ROE 可能异常（如东鹏饮料 yfinance 返回 8.4%，实际 32%），mx-data 返回更准确

## mx-data 安装检查

如果 mx-data 查询失败：

1. 确认 `MX_APIKEY` 环境变量已设置
2. 确认 `~/.hermes/skills/mx-data/mx_data.py` 存在
3. 确认输出路径已修正（非 `/root/.openclaw/...` 而是 `~/.mx_data/`）
4. 测试连通性：见上方 curl 命令
