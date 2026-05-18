#!/usr/bin/env python3
"""
margin_decomposition.py — 利润率分解分析器

逐层拆解企业的利润结构，追溯利润率变化的根本原因：

  营收 100%
    - 营业成本 (COGS)
  = 毛利润 → 毛利率
    - 销售费用 (SG&A)
    - 研发费用 (R&D)
    - 折旧摊销 (D&A)
  = 营业利润 → 营业利润率
    - 利息费用 + 其他
  = 税前利润
    - 所得税
  = 净利润 → 净利率

趋势分析（5年）+ 同业对比 + 利润质量评分
"""

import json
import os
import sys
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data")


# ═══════════════════════════════════════════════════════
#  利润率分解
# ═══════════════════════════════════════════════════════

def decompose_margin(ticker):
    """
    利润率分解主函数
    
    从 yfinance 获取5年利润表数据，逐层拆解利润率
    
    返回 dict 包含：
    - 每年度的逐层利润率分解
    - 5年趋势
    - 利润质量评分
    - 风险信号
    """
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info or {}
    inc = t.income_stmt
    cf = t.cashflow

    result = {
        "ticker": ticker.upper(),
        "company_name": info.get("longName") or info.get("shortName", ""),
        "sector": info.get("sector", ""),
        "industry": info.get("industry", ""),
        "currency": info.get("financialCurrency", "USD"),
    }

    if inc is None or inc.empty:
        result["error"] = "无法获取利润表数据"
        return result

    years = sorted(inc.columns, reverse=True)[:5]

    yearly = []
    for year in years:
        year_str = str(year)[:10] if hasattr(year, 'strftime') else str(year)[:4]
        row = {"year": year_str}

        try:
            revenue = float(inc.loc["Total Revenue", year]) if "Total Revenue" in inc.index else 0
        except:
            revenue = 0
        if revenue == 0:
            continue
        row["revenue"] = revenue

        # ── 各利润层级 ──
        try:
            row["cost_of_revenue"] = float(inc.loc["Cost Of Revenue", year]) if "Cost Of Revenue" in inc.index else 0
        except:
            row["cost_of_revenue"] = 0

        try:
            row["gross_profit"] = float(inc.loc["Gross Profit", year]) if "Gross Profit" in inc.index else 0
        except:
            row["gross_profit"] = revenue - row["cost_of_revenue"]

        # 营业费用
        try:
            row["rd_expense"] = float(inc.loc["Research And Development", year]) if "Research And Development" in inc.index else 0
        except:
            row["rd_expense"] = 0

        try:
            row["sga_expense"] = float(inc.loc["Selling General And Administration", year]) if "Selling General And Administration" in inc.index else 0
        except:
            row["sga_expense"] = 0

        # 营业利润
        try:
            row["operating_income"] = float(inc.loc["Operating Income", year]) if "Operating Income" in inc.index else 0
        except:
            row["operating_income"] = 0

        # 净利率
        try:
            row["net_income"] = float(inc.loc["Net Income", year]) if "Net Income" in inc.index else 0
        except:
            row["net_income"] = 0

        # 利息与税收
        try:
            row["interest_expense"] = float(inc.loc["Interest Expense", year]) if "Interest Expense" in inc.index else 0
        except:
            row["interest_expense"] = 0

        try:
            row["interest_income"] = float(inc.loc["Interest Income", year]) if "Interest Income" in inc.index else 0
        except:
            row["interest_income"] = 0

        try:
            row["tax_provision"] = float(inc.loc["Tax Provision", year]) if "Tax Provision" in inc.index else 0
        except:
            row["tax_provision"] = 0

        # ── 计算利润率 ──
        row["gross_margin_pct"] = round(row["gross_profit"] / revenue * 100, 2)
        row["rd_to_revenue_pct"] = round(abs(row["rd_expense"]) / revenue * 100, 2)
        row["sga_to_revenue_pct"] = round(abs(row["sga_expense"]) / revenue * 100, 2)
        row["operating_margin_pct"] = round(row["operating_income"] / revenue * 100, 2)
        row["net_margin_pct"] = round(row["net_income"] / revenue * 100, 2)
        row["effective_tax_rate_pct"] = round(abs(row["tax_provision"]) / (abs(row["net_income"]) + abs(row["tax_provision"])) * 100, 1) if row["net_income"] != 0 else 0

        # ── 增量分析（每赚¥1营收的分配） ──
        row["per_dollar_breakdown"] = {
            "cost_of_goods": round(row["cost_of_revenue"] / revenue * 100, 1),
            "rd": round(abs(row["rd_expense"]) / revenue * 100, 1),
            "sga": round(abs(row["sga_expense"]) / revenue * 100, 1),
            "interest_net": round((abs(row["interest_expense"]) - row["interest_income"]) / revenue * 100, 1),
            "tax": round(abs(row["tax_provision"]) / revenue * 100, 1),
            "net_profit": row["net_margin_pct"],
        }

        yearly.append(row)

    result["yearly"] = yearly

    # ── 5年趋势摘要 ──
    if len(yearly) >= 2:
        result["trends"] = _calc_trends(yearly)
        result["signals"] = _detect_signals(yearly)
        result["quality_score"] = _quality_score(yearly)

    # ── 营收质量（从现金流量表验证） ──
    if cf is not None and not cf.empty:
        cf_years = sorted(cf.columns, reverse=True)[:5]
        cash_quality = []
        for cy in cf_years:
            cy_str = str(cy)[:10] if hasattr(cy, 'strftime') else str(cy)[:4]
            try:
                ocf = float(cf.loc["Operating Cash Flow", cy]) if "Operating Cash Flow" in cf.index else 0
                ni_for_year = None
                for yd in yearly:
                    if yd["year"] == cy_str:
                        ni_for_year = yd["net_income"]
                        break
                if ni_for_year and ni_for_year != 0:
                    ratio = round(ocf / ni_for_year, 2)
                    tag = "✅ 优质" if ratio > 1.0 else "⚠️ 存疑" if ratio > 0.5 else "❌ 危险"
                    cash_quality.append({"year": cy_str, "ocf": ocf, "net_income": ni_for_year, "ocf_to_ni_ratio": ratio, "tag": tag})
            except:
                pass
        result["cash_quality"] = cash_quality

    return result


def _calc_trends(yearly):
    """计算5年趋势"""
    first = yearly[-1]
    last = yearly[0]

    metrics = [
        ("revenue", "营收"),
        ("gross_margin_pct", "毛利率"),
        ("operating_margin_pct", "营业利润率"),
        ("net_margin_pct", "净利率"),
        ("rd_to_revenue_pct", "研发费用率"),
        ("sga_to_revenue_pct", "销售管理费用率"),
    ]

    trends = []
    for key, label in metrics:
        start = first.get(key, 0)
        end = last.get(key, 0)
        if start != 0:
            if key.endswith("_pct") or key.endswith("_rate_pct"):
                change = round(end - start, 2)
                direction = "↑" if change > 0 else "↓" if change < 0 else "→"
            else:
                change = round((end - start) / abs(start) * 100, 1)
                direction = "↑" if change > 0 else "↓" if change < 0 else "→"
            trends.append({"metric": label, "start": start, "end": end, "change": change, "direction": direction})

    return trends


def _detect_signals(yearly):
    """检测利润率相关的风险信号"""
    signals = []

    # 信号1：毛利率连续下降
    gms = [y["gross_margin_pct"] for y in yearly[:4]]
    if len(gms) >= 3 and gms[0] < gms[1] < gms[2]:
        signals.append({"type": "⚠️", "signal": "毛利率连续2年下降", "detail": f"{gms[2]}% → {gms[1]}% → {gms[0]}%"})

    # 信号2：SG&A占比持续上升
    sgas = [y["sga_to_revenue_pct"] for y in yearly[:4]]
    if len(sgas) >= 3 and sgas[0] > sgas[1] > sgas[2]:
        signals.append({"type": "⚠️", "signal": "管理费用率持续上升", "detail": f"{sgas[2]}% → {sgas[1]}% → {sgas[0]}%"})

    # 信号3：营业利润率 vs 毛利率背离
    if len(yearly) >= 2:
        gm_diff = yearly[0]["gross_margin_pct"] - yearly[-1]["gross_margin_pct"]
        om_diff = yearly[0]["operating_margin_pct"] - yearly[-1]["operating_margin_pct"]
        if gm_diff > 0 and om_diff < 0:
            signals.append({"type": "🔴", "signal": "毛利率上升但营业利润率下降", "detail": "费用端失控，需检查SG&A和R&D趋势"})
        if gm_diff < 0 and om_diff > 0:
            signals.append({"type": "✅", "signal": "毛利率下降但营业利润率上升", "detail": "费用管控改善，或规模效应显现"})

    # 信号4：净利率波动过大
    nms = [y["net_margin_pct"] for y in yearly[:4]]
    if len(nms) >= 3:
        max_nm, min_nm = max(nms), min(nms)
        if max_nm - min_nm > 10:
            signals.append({"type": "⚠️", "signal": "净利率波动过大", "detail": f"5年内最高{max_nm}%→最低{min_nm}%，幅度>{10}%：可能存在非经常性损益"})

    # 信号5：研发费用率异常
    rds = [y["rd_to_revenue_pct"] for y in yearly[:3]]
    if len(rds) >= 2 and all(r < 1.0 for r in rds[:2]):
        signals.append({"type": "ℹ️", "signal": "研发费用率低于1%", "detail": "这是典型的重营销/轻研发模式，关注技术迭代风险"})

    return signals


def _quality_score(yearly):
    """利润质量评分（0-10）"""
    score = 10
    reasons = []

    # 扣分项
    gms = [y["gross_margin_pct"] for y in yearly[:4]]
    om = [y["operating_margin_pct"] for y in yearly[:4]]
    nms = [y["net_margin_pct"] for y in yearly[:4]]

    if len(gms) >= 3 and gms[0] < gms[-1]:
        score -= 1
        reasons.append(f"毛利率趋势下降: {gms[-1]}%→{gms[0]}%")

    # 毛利率绝对值
    avg_gm = sum(gms[:3]) / len(gms[:3]) if gms else 0
    if avg_gm < 20:
        score -= 1
        reasons.append(f"毛利率偏低({avg_gm:.1f}%)")
    elif avg_gm > 40:
        score += 0  # 不扣分

    # SG&A占比
    avg_sga = sum([y["sga_to_revenue_pct"] for y in yearly[:3]]) / 3
    if avg_sga > 30:
        score -= 1
        reasons.append(f"SG&A占比偏高({avg_sga:.1f}%)")

    # 净利率稳定性
    if len(nms) >= 3 and max(nms[:3]) - min(nms[:3]) > 5:
        score -= 1
        reasons.append("净利率波动较大")

    # 运营利润率
    avg_om = sum(om[:3]) / len(om[:3]) if om else 0
    if avg_om < 5:
        score -= 1
        reasons.append(f"营业利润率偏低({avg_om:.1f}%)")

    score = max(0, min(10, score))
    return {"score": score, "max": 10, "reasons": reasons}


# ═══════════════════════════════════════════════════════
#  输出
# ═══════════════════════════════════════════════════════

def to_markdown(result):
    lines = []

    if "error" in result:
        return f"# ❌ 利润率分解失败\n\n{result['error']}"

    lines.append(f"# 利润率分解 — {result['ticker']}")
    lines.append(f"")
    lines.append(f"**{result.get('company_name','')}** | {result.get('sector','')} | {result.get('industry','')}")
    lines.append(f"")

    yearly = result.get("yearly", [])

    # ── 逐层分解表 ──
    lines.append(f"## 利润率逐层分解（5年）")
    lines.append(f"")
    lines.append(f"| 指标 | {' | '.join([y['year'] for y in yearly])} |")
    lines.append(f"|------|{'|'.join(['---']*len(yearly))}|")

    rows = [
        ("revenue", "营收", True),
        ("cost_of_revenue", "减：营业成本", True),
        ("gross_profit", "毛利润", True),
        ("gross_margin_pct", "毛利率", False),
        ("rd_expense", "减：研发费用", True),
        ("sga_expense", "减：销售管理费用", True),
        ("operating_income", "营业利润", True),
        ("operating_margin_pct", "营业利润率", False),
        ("net_income", "净利润", True),
        ("net_margin_pct", "净利率", False),
    ]

    for key, label, is_abs in rows:
        vals = [label]
        for y in yearly:
            v = y.get(key, 0)
            if v is None or v == 0:
                vals.append("-")
            elif not is_abs:
                vals.append(f"{v}%")
            else:
                if abs(v) >= 1e9:
                    vals.append(f"${v/1e9:.2f}B")
                elif abs(v) >= 1e6:
                    vals.append(f"${v/1e6:.2f}M")
                else:
                    vals.append(f"${v:,.0f}")
        lines.append(f"| {' | '.join(vals)} |")

    lines.append(f"")

    # ── 每¥1营收的分配 ──
    lines.append(f"## 每¥1营收的分配（最新年）")
    lines.append(f"")
    if yearly:
        bd = yearly[0].get("per_dollar_breakdown", {})
        lines.append(f"```")
        lines.append(f"  ¥1.00 营收")
        lines.append(f"  - ¥{bd.get('cost_of_goods',0)/100:.2f} 营业成本")
        lines.append(f"  - ¥{bd.get('rd',0)/100:.2f} 研发")
        lines.append(f"  - ¥{bd.get('sga',0)/100:.2f} 销售管理")
        lines.append(f"  - ¥{bd.get('interest_net',0)/100:.2f} 利息")
        lines.append(f"  - ¥{bd.get('tax',0)/100:.2f} 税")
        lines.append(f"  ─────────────────")
        lines.append(f"  = ¥{bd.get('net_profit',0)/100:.2f} 净利润")
        lines.append(f"```")
        lines.append(f"")

    # ── 趋势 ──
    trends = result.get("trends", [])
    if trends:
        lines.append(f"## 5年趋势")
        lines.append(f"")
        lines.append(f"| 指标 | 最早 | 最近 | 变化 | 方向 |")
        lines.append(f"|------|------|------|------|------|")
        for t in trends:
            start = t["start"]
            end = t["end"]
            if isinstance(start, float):
                start_s = f"{start:.2f}%"
                end_s = f"{end:.2f}%"
            else:
                start_s = f"${start/1e9:.1f}B" if abs(start) >= 1e9 else str(start)
                end_s = f"${end/1e9:.1f}B" if abs(end) >= 1e9 else str(end)
            lines.append(f"| {t['metric']} | {start_s} | {end_s} | {t['change']} | {t['direction']} |")
        lines.append(f"")

    # ── 信号 ──
    signals = result.get("signals", [])
    if signals:
        lines.append(f"## 风险信号")
        lines.append(f"")
        for sig in signals:
            lines.append(f"- {sig['type']} **{sig['signal']}**")
            lines.append(f"  - {sig['detail']}")
        lines.append(f"")

    # ── 利润质量 ──
    qs = result.get("quality_score", {})
    if qs:
        score = qs.get("score", 0)
        bar = "█" * score + "░" * (10 - score)
        lines.append(f"## 利润质量评分")
        lines.append(f"")
        lines.append(f"**{score}/10** [{bar}]")
        if qs.get("reasons"):
            for r in qs["reasons"]:
                lines.append(f"- 扣分：{r}")
        lines.append(f"")

    # ── 现金流验证 ──
    cq = result.get("cash_quality", [])
    if cq:
        lines.append(f"## 现金流验证（OCF/净利比）")
        lines.append(f"")
        lines.append(f"| 年份 | 经营现金流 | 净利润 | OCF/净利 | 评价 |")
        lines.append(f"|------|-----------|-------|---------|------|")
        for c in cq:
            lines.append(f"| {c['year']} | ${c['ocf']/1e9:.2f}B | ${c['net_income']/1e9:.2f}B | {c['ocf_to_ni_ratio']}x | {c['tag']} |")
        lines.append(f"")

    return "\n".join(lines)


# ═══════════════════════════════════════════════════════
#  CLI
# ═══════════════════════════════════════════════════════

def main():
    import argparse
    parser = argparse.ArgumentParser(description="利润率分解分析器")
    parser.add_argument("--ticker", type=str, required=True, help="股票代码")
    parser.add_argument("--output", type=str, default=None, help="输出路径")
    parser.add_argument("--format", type=str, default="markdown", choices=["json", "markdown"])
    args = parser.parse_args()

    result = decompose_margin(args.ticker)

    if args.format == "markdown":
        output = to_markdown(result)
    else:
        output = json.dumps(result, indent=2, default=str)

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"[margin] ✅ 已写入 {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
