# MX API（东方财富妙想）配置与使用指南

> 2026-05-13 接入验证。适用于 A 股 + 港股数据采集。

## 申请方式

1. 打开微信扫码 `https://dl.dfcfs.com/m/itc4`
2. 或东方财富 APP → 搜索"妙想Skills" → 免费领取
3. 领取 API Key（格式：`mkt_xxxxx`）

## 配置

```bash
# 写入 profile 的 .env
echo 'MX_APIKEY=mkt_xxxxx' >> /home/ivan/github/my-skills-repo/data-science/.env.local
```

## 5 个 MX 技能清单

| 技能名称 | 功能 | 安装路径 | 脚本 |
|---------|------|---------|------|
| mx-data | 行情/财务/股东/关联数据查询 | `/home/ivan/github/my-skills-repo/mx-data/` | `mx_data.py` |
| mx-search | 新闻/公告/研报/政策搜索 | `/home/ivan/github/my-skills-repo/mx-search/` | `mx_search.py` |
| mx-xuangu | 按条件选股（PE/ROE/行业等） | `/home/ivan/github/my-skills-repo/mx-xuangu/` | `mx_xuangu.py` |
| mx-zixuan | 东方财富自选股管理 | `/home/ivan/github/my-skills-repo/mx-zixuan/` | `mx_zixuan.py` |
| mx-moni | 模拟组合（买卖/持仓） | `/home/ivan/github/my-skills-repo/mx-moni/` | `mx_moni.py` |

## 使用示例

### 查询个股行情+财务

```bash
cd /home/ivan/github/my-skills-repo/mx-data
MX_APIKEY=mkt_xxxxx python3 mx_data.py "东鹏饮料 最新价 总市值 PE PB ROE 营收增速"
```

### 搜索新闻

```bash
cd /home/ivan/github/my-skills-repo/mx-search
MX_APIKEY=mkt_xxxxx python3 mx_search.py "贵州茅台 2025年最新公告 产能扩建"
```

### 智能选股

```bash
cd /home/ivan/github/my-skills-repo/mx-xuangu
MX_APIKEY=mkt_xxxxx python3 mx_xuangu.py "筛选PE<20且ROE>15%的白酒行业股票"
```

## Python 接口（推荐在分析脚本中使用）

```python
from lib.mx_api import MXClient

client = MXClient()  # 读取 MX_APIKEY 环境变量

# 快速查询
snapshot = client.fetch_snapshot("605499")
# → {"price": 192.83, "market_cap": "1115亿", "pe": 23.76, "pb": 5.32}

# 自然语言查询
data = client.query("605499 东鹏饮料 2025年营业收入 净利润 毛利率")
# → 解析 dataTableDTOList 获取表格数据

# 解析实体（股票名→代码）
hits = client.resolve_entity("东鹏饮料")
# → [{"fullName": "东鹏饮料", "secuCode": "605499", "entityType": "A股"}]

# 新闻搜索
news = client.news_search("东鹏饮料 最新公告")
```

## 输出文件说明

默认输出目录：`~/.mx/mx-data/output/`（已从旧 OpenClaw 硬编码路径修补）

每次查询生成：
- `mx_data_{query}.xlsx` — Excel 文件（多 sheet）
- `mx_data_{query}_description.txt` — 查询结果描述
- `mx_data_{query}_raw.json` — API 原始 JSON 响应

## 注意事项

1. **速率限制：** 每日免费调用次数有限（具体限额参见妙想页面）
2. **查询范围：** 不要一次查询太大数据（如"5年每日行情"），会导致返回内容过多
3. **参数名：** query 接口用 `{"toolQuery": "..."}` 而非 `{"query": "..."}`
4. **Hermes 集成：** `hermes skills install` 不支持本地路径，需要用 `cp -R` 手动安装
5. **Caching：** `lib.mx_api.py` 内置 30 分钟 TTL 缓存，通过 `lib.cache.cached` 实现
