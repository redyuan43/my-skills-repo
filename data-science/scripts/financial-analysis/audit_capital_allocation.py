#!/usr/bin/env python3
"""
audit_capital_allocation.py — 资本配置审计

像CFO一样审视管理层如何分配公司的每一块钱：
  1. 经营现金流 → 钱从哪来
  2. CapEx → 投了多少在增长 vs 维护
  3. 收购 → 花了多少钱买公司
  4. 回购 → 回购是否在低价时进行
  5. 分红 → 分红率是否可持续
  6. 还债 → 是否在优化资本结构
  7. 冗余现金 → 账上是否有太多闲置资金

返回资本配置效率评分和质量判断。
"""

import json
import os
import sys
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data")


def audit(ticker, years=5):
    """资本配置审计主函数"""
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info or {}
    cf = t.cashflow
    bs = t.balance_sheet
    inc = t.income_stmt

    result = {
        "ticker": ticker.upper(),
        "company_name": info.get("longName") or info.get("shortName", ""),
        "audit_date": datetime.now().isoformat(),
    }

    if cf is None or cf.empty:
        result["error"] = "无法获取现金流量表"
        return result

    cf_years = sorted(cf.columns, reverse=True)[:years]

    # ── 逐年提取资本配置数据 ──
    yearly = []
    all_ocf, all_capex, all_acq, all_buyback, all_div, all_debt_pay = [], [], [], [], [], []

    for y in cf_years:
        year_str = str(y)[:10] if hasattr(y, 'strftime') else str(y)[:4]
        try:
            ocf = float(cf.loc["Operating Cash Flow", y]) if "Operating Cash Flow" in cf.index else 0
            capex = abs(float(cf.loc["Capital Expenditure", y])) if "Capital Expenditure" in cf.index else 0
            acq = abs(float(cf.loc["Purchase Of Business", y])) if "Purchase Of Business" in cf.index else 0
            buyback = abs(float(cf.loc["Repurchase Of Capital Stock", y])) if "Repurchase Of Capital Stock" in cf.index else 0
            div = abs(float(cf.loc["Cash Dividends Paid", y])) if "Cash Dividends Paid" in cf.index else 0
            div2 = abs(float(cf.loc["Common Stock Dividend Paid", y])) if "Common Stock Dividend Paid" in cf.index else 0
            debt_issue = float(cf.loc["Issuance Of Debt", y]) if "Issuance Of Debt" in cf.index else 0
            debt_pay = abs(float(cf.loc["Repayment Of Debt", y])) if "Repayment Of Debt" in cf.index else 0
            invest = abs(float(cf.loc["Purchase Of Investment", y])) if "Purchase Of Investment" in cf.index else 0
            sbc = abs(float(cf.loc["Stock Based Compensation", y])) if "Stock Based Compensation" in cf.index else 0
        except Exception as e:
            continue

        total_div = div or div2
        total_used = capex + acq + buyback + total_div + debt_pay + invest
        fcf = ocf - capex

        record = {
            "year": year_str,
            "operating_cash_flow": ocf,
            "free_cash_flow": fcf,
            "capex": capex,
            "acquisitions": acq,
            "buybacks": buyback,
            "dividends": total_div,
            "debt_repaid": debt_pay,
            "debt_issued": debt_issue,
            "investments": invest,
            "stock_based_comp": sbc,
            "total_cash_used": total_used,
            "fcf_to_ocf_pct": round(fcf / ocf * 100, 1) if ocf else 0,
            "buyback_to_fcf_pct": round(buyback / fcf * 100, 1) if fcf else 0,
            "div_to_fcf_pct": round(total_div / fcf * 100, 1) if fcf else 0,
        }

        # 每¥1经营现金流的分配
        if ocf:
            allocations = {}
            items = [
                ("维护性CapEx", min(capex, abs(float(cf.loc["Depreciation And Amortization", y]))
                    if "Depreciation And Amortization" in cf.index else capex)),
                ("增长性CapEx", max(0, capex - (abs(float(cf.loc["Depreciation And Amortization", y]))
                    if "Depreciation And Amortization" in cf.index else 0))),
                ("收购", acq), ("回购", buyback), ("分红", total_div),
                ("还债", debt_pay), ("投资", invest), ("SBC(员工)", sbc),
            ]
            record["per_dollar_allocation"] = {label: round(val / ocf * 100, 1) for label, val in items}

        yearly.append(record)
        all_ocf.append(ocf)
        all_capex.append(capex)
        all_acq.append(acq)
        all_buyback.append(buyback)
        all_div.append(total_div)
        all_debt_pay.append(debt_pay)

    result["yearly"] = yearly

    # ── 配置效率评分 ──
    result["score"] = _score_allocation(yearly, result)
    result["verdict"] = _verdict_allocation(result["score"])

    # ── 冗余现金分析 ──
    if bs is not None and not bs.empty:
        bs_year = sorted(bs.columns, reverse=True)[0]
        cash = float(bs.loc["Cash Cash Equivalents And Short Term Investments", bs_year]) if "Cash Cash Equivalents And Short Term Investments" in bs.index else (float(bs.loc["Cash And Cash Equivalents", bs_year]) if "Cash And Cash Equivalents" in bs.index else 0)
        debt = float(bs.loc["Total Debt", bs_year]) if "Total Debt" in bs.index else 0
        ni = 0
        if inc is not None and not inc.empty:
            inc_year = sorted(inc.columns, reverse=True)[0]
            ni = float(inc.loc["Net Income", inc_year]) if "Net Income" in inc.index else 0
        mkt_cap = info.get("marketCap", 0) or 0

        result["excess_cash"] = {
            "cash": cash,
            "total_debt": debt,
            "net_cash": cash - debt,
            "net_cash_to_mkt_cap_pct": round((cash - debt) / mkt_cap * 100, 1) if mkt_cap else 0,
            "years_of_ni_in_cash": round(cash / ni, 1) if ni else 99,
        }

    return result


def _score_allocation(yearly, result):
    """资本配置效率评分 (0-10)"""
    score = 10
    details = []

    if not yearly:
        return {"score": 0, "details": ["无数据"]}

    latest = yearly[0]
    avg = {k: sum(y.get(k, 0) for y in yearly) / len(yearly) for k in ["buyback_to_fcf_pct", "div_to_fcf_pct"]}

    # 扣分项1：SBC > 回购（管理层在净卖出）
    sbc = latest.get("stock_based_comp", 0)
    buyback = latest.get("buybacks", 0)
    if sbc > buyback:
        score -= 2
        details.append(f"SBC(${sbc/1e6:.0f}M) > 回购(${buyback/1e6:.0f}M)：管理层净卖出")

    # 扣分项2：大量收购
    acq_ratio = latest.get("acquisitions", 0) / latest.get("total_cash_used", 1)
    if acq_ratio > 0.3:
        score -= 1
        details.append(f"收购占总现金使用{acq_ratio*100:.0f}%，关注收购回报率")

    # 扣分项3：大量冗余现金
    ec = result.get("excess_cash", {})
    if ec.get("net_cash_to_mkt_cap_pct", 0) > 20:
        score -= 1
        details.append(f"净现金占市值{ec['net_cash_to_mkt_cap_pct']}%，过多闲置")

    # 扣分项4：回购节奏差
    # （简化：检查股价趋势，但实际上要复杂得多）

    # 加分项1：持续回购+分红
    if avg["buyback_to_fcf_pct"] + avg["div_to_fcf_pct"] > 50:
        score += 1
        details.append(f"持续高股东回报(回购{avg['buyback_to_fcf_pct']:.0f}%+分红{avg['div_to_fcf_pct']:.0f}%FCF)")
    if avg["buyback_to_fcf_pct"] + avg["div_to_fcf_pct"] > 80:
        score += 0.5

    # 加分项2：FCF转化率高
    if latest.get("fcf_to_ocf_pct", 0) > 60:
        score += 0.5
        details.append(f"FCF/OCF={latest['fcf_to_ocf_pct']}%，现金转化率优秀")

    score = max(0, min(10, score))

    return {"score": round(score, 1), "details": details}


def _verdict_allocation(score_obj):
    score = score_obj.get("score", 0)
    if score >= 8:
        return {"grade": "A", "text": "资本配置优秀。管理层是优秀的资本配置者，每一块钱都用在刀刃上。"}
    elif score >= 6:
        return {"grade": "B", "text": "资本配置良好。整体合理，但有一两个领域可以改进。"}
    elif score >= 4:
        return {"grade": "C", "text": "资本配置平庸。有改进空间，特别关注减分项。"}
    else:
        return {"grade": "F", "text": "资本配置糟糕。管理层在毁灭股东价值，特别警惕SBC和盲目收购。"}


def to_markdown(result):
    if "error" in result:
        return f"# 资本配置审计失败\n\n{result['error']}"
    
    lines = [f"# 资本配置审计 — {result['ticker']}", f"", f"**{result.get('company_name','')}**", f""]
    lines.append(f"**评分：{result.get('score',{}).get('score','N/A')}/10** | 等级：{result.get('verdict',{}).get('grade','N/A')}")
    lines.append(f"")
    
    s = result.get("score", {})
    for d in s.get("details", []):
        lines.append(f"- {d}")
    lines.append(f"")
    lines.append(f"> {result.get('verdict',{}).get('text','')}")
    lines.append(f"")

    yearly = result.get("yearly", [])
    if yearly:
        lines.append(f"## 年度资本配置明细")
        lines.append(f"")
        lines.append(f"| 项目 | {' | '.join([y['year'] for y in yearly])} |")
        lines.append(f"|------|{'|'.join(['---']*len(yearly))}|")
        for key, label in [("operating_cash_flow", "经营现金流"), ("free_cash_flow", "自由现金流"),
            ("capex", "资本开支"), ("acquisitions", "收购"), ("buybacks", "回购"),
            ("dividends", "分红"), ("debt_repaid", "还债"), ("stock_based_comp", "SBC")]:
            vals = [label]
            for y in yearly:
                v = y.get(key, 0)
                vals.append(f"${v/1e6:.0f}M" if v else "-")
            lines.append(f"| {' | '.join(vals)} |")
        lines.append(f"")

    ec = result.get("excess_cash", {})
    if ec:
        lines.append(f"## 冗余现金分析")
        lines.append(f"")
        lines.append(f"- 账面现金：${ec.get('cash',0)/1e6:.0f}M")
        lines.append(f"- 总负债：${ec.get('total_debt',0)/1e6:.0f}M")
        lines.append(f"- 净现金：${ec.get('net_cash',0)/1e6:.0f}M")
        lines.append(f"- 净现金/市值：{ec.get('net_cash_to_mkt_cap_pct',0)}%")
        lines.append(f"- 现金可覆盖净利润：{ec.get('years_of_ni_in_cash',0)}年")

    return "\n".join(lines)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticker", required=True)
    parser.add_argument("--years", type=int, default=5)
    parser.add_argument("--output", default=None)
    parser.add_argument("--format", default="markdown", choices=["json", "markdown"])
    args = parser.parse_args()
    result = audit(args.ticker, args.years)
    out = json.dumps(result, indent=2, default=str) if args.format == "json" else to_markdown(result)
    if args.output:
        with open(args.output, "w") as f:
            f.write(out)
    else:
        print(out)

if __name__ == "__main__":
    main()
