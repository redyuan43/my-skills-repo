#!/usr/bin/env python3
"""
calculate_reproduction_value.py — 资产重置价值(ARV)计算器

基于 Bruce Greenwald 的 Reproduction Value 框架，逐项计算企业资产的重置成本。

用法：
  python3 scripts/calculate_reproduction_value.py --ticker AAPL
  python3 scripts/calculate_reproduction_value.py --ticker 601398.SS --format markdown
  python3 scripts/calculate_reproduction_value.py --ticker CROX --output /tmp/arv.json

输出包含：
  - 资产负债表的每一项分别估算重置成本
  - 无形资产（品牌/专利）的特殊处理
  - 冗余现金的扣除
"""

import json
import os
import sys
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data")
os.makedirs(DATA_DIR, exist_ok=True)


def fetch_data(ticker_symbol):
    """从 yfinance 拉取资产负债表数据"""
    import yfinance as yf
    ticker = yf.Ticker(ticker_symbol)
    
    info = ticker.info or {}
    bs = ticker.balance_sheet
    inc = ticker.income_stmt
    
    data = {
        "ticker": ticker_symbol.upper(),
        "company_name": info.get("longName") or info.get("shortName", ""),
        "sector": info.get("sector", ""),
        "industry": info.get("industry", ""),
        "currency": info.get("financialCurrency", "USD"),
        "current_price": info.get("currentPrice") or info.get("regularMarketPrice"),
        "market_cap": info.get("marketCap"),
        "enterprise_value": info.get("enterpriseValue"),
        "shares_outstanding": info.get("sharesOutstanding"),
    }
    
    # 解析资产负债表（最近一年）
    if bs is not None and not bs.empty:
        years = sorted(bs.columns, reverse=True)
        latest_year = years[0]
        
        bs_items = {}
        for idx in bs.index:
            val = bs.loc[idx, latest_year]
            if val is not None and val == val:  # not NaN
                bs_items[str(idx)] = float(val)
        
        data["balance_sheet_year"] = str(latest_year)[:10] if hasattr(latest_year, 'strftime') else str(latest_year)[:10]
        data["balance_sheet"] = bs_items
    
    # 解析利润表（最近一年，用于品牌估值倍数）
    if inc is not None and not inc.empty:
        years = sorted(inc.columns, reverse=True)
        latest_year = years[0]
        for idx in inc.index:
            if str(idx) == "Net Income":
                data["net_income"] = float(inc.loc[idx, latest_year])
            elif str(idx) == "Operating Income":
                data["operating_income"] = float(inc.loc[idx, latest_year])
            elif str(idx) == "EBIT":
                data["ebit"] = float(inc.loc[idx, latest_year])
            elif str(idx) == "Total Revenue":
                data["revenue"] = float(inc.loc[idx, latest_year])
    
    return data


# ═══════════════════════════════════════════════════════
#  Reproduction Value 计算
# ═══════════════════════════════════════════════════════

def calc_reproduction_value(data):
    """
    格林沃尔德 Reproduction Value 计算核心逻辑
    
    逐项估算：
    1. 现金及现金等价物 → 按账面值（100%）
    2. 短期投资 → 按账面值（95%，扣除交易成本）
    3. 应收账款 → 账面值 × 90%（回收折扣）
    4. 存货 → 账面值 × 60-90%（按行业调整）
    5. 固定资产(PP&E) → 账面值 × (1 + 通胀调整)
    6. 无形资产(可辨认) → 账面值 × 50%（内部研发价值打折）
    7. 商誉 → 0（不予重置）
    8. 长期投资 → 账面值 × 80%
    9. 其他资产 → 账面值 × 50%
    """
    bs = data.get("balance_sheet", {})
    sector = data.get("sector", "")
    industry = data.get("industry", "")
    
    result = {
        "ticker": data["ticker"],
        "company_name": data["company_name"],
        "currency": data.get("currency", "USD"),
        "balance_sheet_year": data.get("balance_sheet_year", ""),
        "items": [],
        "summary": {},
    }
    
    total_book = 0       # 账面值合计
    total_repro = 0      # 重置值合计
    
    # ── 辅助函数 ──
    def add_item(name, book_value, repro_pct, repro_value, note=""):
        nonlocal total_book, total_repro
        book = book_value or 0
        repro = repro_value or 0
        total_book += abs(book)
        total_repro += abs(repro)
        result["items"].append({
            "item": name,
            "book_value": round(book, 2),
            "reproduction_pct": repro_pct,
            "reproduction_value": round(repro, 2),
            "note": note,
        })
    
    def g(key):
        return bs.get(key, 0)
    
    # ── 1. 现金 ──
    cash = g("Cash And Cash Equivalents") or g("Cash Equivalents") or 0
    add_item("现金及现金等价物", cash, "100%", cash, "按账面值")
    
    # ── 2. 短期投资 ──
    st_inv = g("Short Term Investments") or 0
    st_inv_val = st_inv * 0.95 if st_inv else 0
    add_item("短期投资", st_inv, "95%", st_inv_val, "扣除交易成本")
    
    # ── 3. 应收账款 ──
    receivables = g("Net Receivables") or g("Accounts Receivable") or 0
    # 行业调整：不同行业的应收可回收率不同
    if "Technology" in sector or "Software" in industry:
        rec_pct = 0.85
        rec_note = "科技行业应收回收率较低"
    elif "Bank" in sector or "Financial" in sector:
        rec_pct = 0.95
        rec_note = "金融行业应收质量较高"
    else:
        rec_pct = 0.90
        rec_note = "通用应收回收率90%"
    add_item("应收账款", receivables, f"{int(rec_pct*100)}%", receivables * rec_pct, rec_note)
    
    # ── 4. 存货 ──
    inventory = g("Inventory") or 0
    if "Technology" in sector or "Semiconductor" in industry:
        inv_pct = 0.60
        inv_note = "科技存货贬值快"
    elif "Consumer Defensive" in sector or "Food" in industry or "Beverage" in industry:
        inv_pct = 0.85
        inv_note = "快消品存货周转快"
    elif "Energy" in sector or "Oil" in industry:
        inv_pct = 0.75
        inv_note = "大宗商品价格波动大"
    elif "Retail" in sector or "Fashion" in industry:
        inv_pct = 0.50
        inv_note = "时尚/零售存货过季贬值严重"
    else:
        inv_pct = 0.80
        inv_note = "通用存货80%"
    add_item("存货", inventory, f"{int(inv_pct*100)}%", inventory * inv_pct, inv_note)
    
    # ── 5. 固定资产（PP&E） ──
    ppe = g("Property Plant Equipment") or g("PP&E Net") or g("Net PPE") or 0
    if ppe:
        # 制造业PP&E重置需加通胀溢价，但考虑折旧后的账面值可能已低于重置值
        ppe_repro = ppe * 1.5  # 保守估计重置成本比账面值高50%
        add_item("固定资产(PP&E)", ppe, "150%", ppe_repro, "重置成本溢价50%（通胀+技术升级）")
    
    # ── 6. 商誉 ──
    goodwill = g("Goodwill") or 0
    if goodwill:
        add_item("商誉(Goodwill)", goodwill, "0%", 0, "商誉不予重置——Greenwald原则")
    
    # ── 7. 无形资产（不含商誉） ──
    intangibles = g("Intangible Assets") or g("Intangibles") or 0
    if intangibles:
        # 可辨认无形资产（专利、版权等）按50%重置
        add_item("无形资产(不含商誉)", intangibles, "50%", intangibles * 0.50, "内部研发形成的无形资产重置价值打折")
    
    # ── 8. 长期投资 ──
    lt_inv = g("Long Term Investments") or g("Investments") or 0
    if lt_inv:
        add_item("长期投资", lt_inv, "80%", lt_inv * 0.80, "长期投资按80%重置")
    
    # ── 9. 其他流动资产 ──
    oca = g("Other Current Assets") or 0
    if oca:
        add_item("其他流动资产", oca, "70%", oca * 0.70, "其他流动资产打7折")
    
    # ── 10. 其他非流动资产 ──
    # 计算"其他非流动资产" = 总资产 - 以上已列出的所有资产
    total_assets = g("Total Assets") or 0
    listed_assets = (
        cash + st_inv + receivables + inventory + ppe + goodwill + intangibles + lt_inv + oca
    )
    other_assets = total_assets - listed_assets if total_assets > listed_assets else 0
    if other_assets > 0:
        add_item("其他未分类资产", other_assets, "50%", other_assets * 0.50, "其他资产按50%保守估算")
    
    # ── 负债扣除 ──
    total_liab = g("Total Liabilities Net Minority Interest") or g("Total Liabilities") or 0
    add_item("总负债(扣除)", -total_liab, "100%", -total_liab, "负债按账面值100%扣除")
    
    # ── 少数股东权益 ──
    minority = g("Minority Interest") or 0
    if minority:
        add_item("少数股东权益(扣除)", -minority, "100%", -minority, "扣除少数股东权益")
    
    # ── 摘要 ──
    total_book = round(total_book, 2)
    total_repro = round(total_repro, 2)
    
    shares = data.get("shares_outstanding", 0)
    mkt_cap = data.get("market_cap", 0)
    ev = data.get("enterprise_value", 0)
    
    result["summary"] = {
        "total_book_value": total_book,
        "total_reproduction_value": total_repro,
        "reproduction_to_book_ratio": round(total_repro / total_book, 4) if total_book else 0,
        "reproduction_per_share": round(total_repro / shares, 2) if shares else 0,
        "current_price": data.get("current_price"),
        "market_cap": mkt_cap,
        "enterprise_value": ev,
        "price_to_reproduction_ratio": round(mkt_cap / total_repro, 4) if total_repro and mkt_cap else None,
        "premium_to_reproduction_pct": round((mkt_cap / total_repro - 1) * 100, 1) if total_repro and mkt_cap else None,
        "shares_outstanding": shares,
    }
    
    return result


def to_markdown(result):
    """输出人类可读的 Markdown 版本"""
    lines = []
    s = result["summary"]
    
    lines.append(f"# 资产重置价值(ARV) — {result['ticker']}")
    lines.append(f"")
    lines.append(f"**{result['company_name']}**")
    lines.append(f"报表日期: {result['balance_sheet_year']}")
    lines.append(f"")
    lines.append(f"## 逐项重置计算")
    lines.append(f"")
    lines.append(f"| 科目 | 账面值 | 重置比例 | 重置价值 | 说明 |")
    lines.append(f"|------|--------|---------|---------|------|")
    
    for item in result["items"]:
        bv = _fmt(item["book_value"], result["currency"])
        rv = _fmt(item["reproduction_value"], result["currency"])
        lines.append(f"| {item['item']} | {bv} | {item['reproduction_pct']} | {rv} | {item['note']} |")
    
    lines.append(f"")
    lines.append(f"## 汇总")
    lines.append(f"")
    lines.append(f"| 指标 | 数值 |")
    lines.append(f"|------|------|")
    lines.append(f"| 账面净资产合计 | {_fmt(s['total_book_value'], result['currency'])} |")
    lines.append(f"| **重置价值合计** | **{_fmt(s['total_reproduction_value'], result['currency'])}** |")
    lines.append(f"| 重置/账面比 | {s['reproduction_to_book_ratio']}x |")
    lines.append(f"| 每股重置价值 | {_fmt_per_share(s['reproduction_per_share'], result['currency'])} |")
    lines.append(f"| 当前股价 | {_fmt_per_share(s.get('current_price'), result['currency'])} |")
    lines.append(f"| 股价/重置价值比 | {s.get('price_to_reproduction_ratio', 'N/A')}x |")
    lines.append(f"| 市值溢价于重置值 | {s.get('premium_to_reproduction_pct', 'N/A')}% |")
    lines.append(f"")
    
    if s.get("premium_to_reproduction_pct") is not None:
        prem = s["premium_to_reproduction_pct"]
        if prem < 0:
            lines.append(f"**结论：当前股价低于重置价值 {abs(prem):.1f}%——格林沃尔德意义上的安全边际存在。**")
        elif prem < 30:
            lines.append(f"**结论：当前股价溢价 {prem:.1f}% 于重置价值——估值合理偏低，有适度安全边际。**")
        elif prem < 60:
            lines.append(f"**结论：当前股价溢价 {prem:.1f}% 于重置价值——估值在市场合理区间，需继续看EPV和FV。**")
        else:
            lines.append(f"**结论：当前股价溢价 {prem:.1f}% 于重置价值——远高于ARV地板，价值主要来自盈利能力和增长预期。**")
    
    return "\n".join(lines)


def _fmt(v, currency="USD"):
    if v is None or v == 0:
        return f"{currency}0"
    try:
        v = float(v)
        symbol = "$" if currency == "USD" else "¥" if currency == "CNY" else currency + " "
        if abs(v) >= 1e12:
            return f"{symbol}{v/1e12:.2f}T"
        elif abs(v) >= 1e9:
            return f"{symbol}{v/1e9:.2f}B"
        elif abs(v) >= 1e6:
            return f"{symbol}{v/1e6:.2f}M"
        else:
            return f"{symbol}{v:,.0f}"
    except:
        return str(v)


def _fmt_per_share(v, currency="USD"):
    if v is None:
        return "N/A"
    symbol = "$" if currency == "USD" else "¥" if currency == "CNY" else currency + " "
    return f"{symbol}{float(v):.2f}"


# ═══════════════════════════════════════════════════════
#  CLI
# ═══════════════════════════════════════════════════════

def main():
    import argparse
    parser = argparse.ArgumentParser(description="格林沃尔德资产重置价值(ARV)计算器")
    parser.add_argument("--ticker", type=str, required=True,
                        help="股票代码 (e.g., AAPL, 601398.SS)")
    parser.add_argument("--output", type=str, default=None,
                        help="输出文件路径")
    parser.add_argument("--format", type=str, default="json",
                        choices=["json", "markdown"],
                        help="输出格式 (default: json)")
    args = parser.parse_args()

    print(f"[arv] 正在获取 {args.ticker} 的资产负债表...")
    data = fetch_data(args.ticker)
    
    if not data.get("balance_sheet"):
        print(f"[arv] ❌ 未能获取资产负债表数据", file=sys.stderr)
        sys.exit(1)
    
    print(f"[arv] 计算重置价值...")
    result = calc_reproduction_value(data)
    
    print(f"[arv]   账面净资产: {_fmt(result['summary']['total_book_value'], data.get('currency','USD'))}")
    print(f"[arv]   重置价值:   {_fmt(result['summary']['total_reproduction_value'], data.get('currency','USD'))}")
    print(f"[arv]   每股重置值: {_fmt_per_share(result['summary']['reproduction_per_share'], data.get('currency','USD'))}")
    prem = result['summary'].get('premium_to_reproduction_pct', None)
    if prem is not None:
        print(f"[arv]   市值溢价:   {prem:.1f}%")
    
    if args.format == "markdown":
        output = to_markdown(result)
    else:
        output = json.dumps(result, indent=2, default=str)
    
    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"[arv] ✅ 已写入 {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
