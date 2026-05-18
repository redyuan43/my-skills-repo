# ADR 币种陷阱 — 当财务数据与股价在不同货币时

## 问题描述

中国 ADR 股票（如 BZ/ATHM/LI 等）在 yfinance 上的一个系统性问题：

| 数据 | yfinance 返回的币种 | 原因 |
|------|------------------|------|
| 利润表/资产负债表/现金流量表 | **CNY** (人民币) | 公司的 functional currency 是 CNY |
| 股价 (`info["currentPrice"]`) | **USD** (美元) | 股票在 NASDAQ/NYSE 以 USD 交易 |
| 市值 (`info["marketCap"]`) | **USD** | 同上 |

**所有分析脚本**（ARV、压力测试、ROIC-WACC、利润率分解等）都从 `yf.Ticker("XXX").info["currentPrice"]` 读取股价，得到的是 **USD**。但它们直接把这个值当作 **CNY**（¥）显示和计算，导致：

- ARV/ADS = ¥52（CNY） vs 股价 = $13.65（显示为 ¥13.65）→ **错！** 应该 ¥99.6
- 每股净现金 ¥50.3 vs 股价 $13.65 → 比较的是不同币种

## 对所有 ADR 的影响

| 脚本 | 影响 | 严重度 |
|------|------|--------|
| calculate_reproduction_value.py | 股价/ARV比低估 ~7.3x | 🔴 高 |
| stress_test_margin_of_safety.py | 安全边际虚高 | 🔴 高 |
| analyze_roic_wacc_spread.py | 使用 mkt_cap(USD) 与 CNY 报表混合 | 🟡 中 |
| audit_capital_allocation.py | 净现金/市值比率在 USD 下显示 | 🟡 中 (已在 fetch 中修复) |

## 修正方法

### 方法 A：在分析/报告生成时统一换算（推荐）

```python
rate = 7.3  # USD/CNY 汇率
price_cny = price_usd * rate        # $13.65 → ¥99.6
mcap_cny = mcap_usd * rate          # $6.2B → ¥452.6亿
```

全部计算使用 **CNY** 统一口径：
- 净现金/市值（CNY）= ¥197.9亿 / ¥452.6亿 = 43.7% ✅
- PE = ¥452.6亿 / ¥27.4亿 = 16.5x ✅
- EV = ¥452.6亿 - ¥197.9亿 = ¥254.7亿 ✅

### 方法 B：将 CNY 财务数据转为 USD（不推荐）

仅在需要与美股同行直接对比时使用。

### 汇率参考

当前 USD/CNY ≈ **7.3**（2026年5月）。建议每次分析时从 FRED 或 yfinance 获取最新汇率。

```python
# 从 yfinance 获取 USDCNY=X 汇率
import yfinance as yf
fx = yf.Ticker("USDCNY=X")
rate = fx.info.get("regularMarketPrice", 7.3)
```

## 受影响的中国 ADR 清单

| 代码 | 公司 | 交易所 | functional currency |
|------|------|--------|-------------------|
| BZ | BOSS直聘 | NASDAQ | CNY |
| LI | 理想汽车 | NASDAQ | CNY |
| ATHM | 汽车之家 | NYSE | CNY |
| BABA | 阿里巴巴 | NYSE | CNY |
| JD | 京东 | NASDAQ | CNY |
| NIO | 蔚来 | NYSE | CNY |
| XPEV | 小鹏 | NYSE | CNY |
| TAL | 好未来 | NYSE | CNY |
| EDU | 新东方 | NYSE | CNY |

**通用规律：** 所有注册在开曼/香港、运营在中国大陆、以 CNY 记账的 ADR 都适用此规则。

## 快速检查方法

观察交叉校验的 **C2** 输出：
- 如果净现金/市值 > 80% → 极大概率是币种不匹配
- 修复：将市值乘以 7.3（或当前汇率）得到 CNY 版本后再判断
