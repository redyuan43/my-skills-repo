#!/usr/bin/env python3
"""
stress_test_margin_of_safety.py — 安全边际压力测试

基于格林沃尔德三段估值框架，对内在价值进行多情景压力测试。

测试场景：
  - 基准场景：当前假设不变
  - 衰退场景：营收下降 + 利润率收窄
  - 竞争场景：ROIC回归 + 护城河缩短
  - 极端场景：最坏情况组合

输出每场景下的内在价值和安全边际变化。
"""

import json
import os
import sys
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data")


def stress_test(ticker):
    """
    安全边际压力测试
    
    从 yfinance 获取数据后，构建格林沃尔德三段的基准估值，
    然后对关键变量施加冲击，生成多情景下的内在价值和安全边际。
    """
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info or {}
    inc = t.income_stmt
    bs = t.balance_sheet
    cf = t.cashflow

    result = {
        "ticker": ticker.upper(),
        "company_name": info.get("longName") or info.get("shortName", ""),
        "current_price": info.get("currentPrice"),
        "market_cap": info.get("marketCap"),
    }

    # ── 获取基准参数 ──
    if inc is None or inc.empty:
        result["error"] = "数据不足"
        return result

    iy = sorted(inc.columns, reverse=True)[0]
    by = sorted(bs.columns, reverse=True)[0] if bs is not None and not bs.empty else iy

    revenue = float(inc.loc["Total Revenue", iy]) if "Total Revenue" in inc.index else 1
    ebit = float(inc.loc["EBIT", iy]) if "EBIT" in inc.index else 0
    op_inc = float(inc.loc["Operating Income", iy]) if "Operating Income" in inc.index else ebit
    tax_r = 0.20  # 默认税率

    cash = float(bs.loc["Cash Cash Equivalents And Short Term Investments", by]) if bs is not None and "Cash Cash Equivalents And Short Term Investments" in bs.index else (float(bs.loc["Cash And Cash Equivalents", by]) if bs is not None and "Cash And Cash Equivalents" in bs.index else 0)
    debt = float(bs.loc["Total Debt", by]) if bs is not None and "Total Debt" in bs.index else 0
    equity = float(bs.loc["Stockholders Equity", by]) if bs is not None and "Stockholders Equity" in bs.index else 0

    nopat = op_inc * (1 - tax_r)
    invested_capital = debt + equity - cash
    roic = nopat / invested_capital if invested_capital else 0.10

    # CapEx拆分
    capex = 0
    da = 0
    if cf is not None and not cf.empty:
        cy = sorted(cf.columns, reverse=True)[0]
        capex = abs(float(cf.loc["Capital Expenditure", cy])) if "Capital Expenditure" in cf.index else 0
        da = float(cf.loc["Depreciation And Amortization", cy]) if "Depreciation And Amortization" in cf.index else 0
        sbc = abs(float(cf.loc["Stock Based Compensation", cy])) if "Stock Based Compensation" in cf.index else 0
    else:
        sbc = 0
    maint_capex = min(da, capex) if da else capex * 0.7
    growth_capex = max(0, capex - maint_capex)

    # ── 基准场景参数 ──
    base = {
        "nopat": nopat,
        "roic": roic,
        "wacc": 0.09,
        "growth_b": growth_capex / nopat if nopat else 0,
        "moat_years": 10,
    }

    scenarios = {
        "基准场景(Base Case)": {
            "desc": "当前假设不变",
            "params": base,
        },
        "温和衰退(Mild Recession)": {
            "desc": "营收-15%，毛利率-3%，OPM-2%",
            "params": {
                "nopat": nopat * 0.75,
                "roic": max(0.05, roic * 0.7),
                "wacc": 0.10,
                "growth_b": base["growth_b"] * 0.5,
                "moat_years": 7,
            },
        },
        "激烈竞争(Competition)": {
            "desc": "ROIC腰斩、护城河缩短",
            "params": {
                "nopat": nopat * 0.65,
                "roic": max(0.03, roic * 0.4),
                "wacc": 0.11,
                "growth_b": base["growth_b"] * 0.3,
                "moat_years": 3,
            },
        },
        "极端情况(Worst Case)": {
            "desc": "营收-30%、利润率砍半",
            "params": {
                "nopat": nopat * 0.4,
                "roic": max(0.01, roic * 0.2),
                "wacc": 0.14,
                "growth_b": 0,
                "moat_years": 0,
            },
        },
    }

    price = info.get("currentPrice") or info.get("regularMarketPrice", 0)
    shares = info.get("sharesOutstanding", 1)

    # ── 对每个场景计算内在价值 ──
    scenario_results = []
    for name, sc in scenarios.items():
        p = sc["params"]

        # ARV（简化版：净资产×调整系数）
        arv = (cash + (equity - cash) * 0.7 - debt) / shares if shares else 0

        # EPV
        epv = p["nopat"] / p["wacc"] / shares if shares and p["wacc"] else 0

        # FV
        spread = p["roic"] - p["wacc"]
        if spread > 0 and p["growth_b"] > 0:
            ann_val = p["nopat"] * p["growth_b"] * spread / p["wacc"]
            annuity = (1 - 1 / (1 + p["wacc"]) ** p["moat_years"]) / p["wacc"]
            fv = ann_val * annuity / shares if shares else 0
        else:
            fv = 0

        intrinsic = arv + epv + fv
        safety = round((intrinsic - price) / intrinsic * 100, 1) if intrinsic > 0 else -999

        scenario_results.append({
            "scenario": name,
            "description": sc["desc"],
            "assumptions": {
                "nopat_adjusted_pct": round(p["nopat"] / nopat * 100 - 100, 1) if nopat else 0,
                "roic_pct": round(p["roic"] * 100, 1),
                "wacc_pct": round(p["wacc"] * 100, 1),
                "spread_pct": round(spread * 100, 1),
                "moat_years": p["moat_years"],
            },
            "valuation": {
                "arv_ps": round(arv, 2),
                "epv_ps": round(epv, 2),
                "fv_ps": round(fv, 2),
                "intrinsic_ps": round(intrinsic, 2),
                "current_price": price,
                "safety_margin_pct": safety,
            },
        })

    result["scenarios"] = scenario_results
    result["base_case"] = scenario_results[0]

    return result


def to_markdown(result):
    if "error" in result:
        return f"# 压力测试失败\n\n{result['error']}"

    lines = [f"# 安全边际压力测试 — {result['ticker']}", f""]
    lines.append(f"**{result.get('company_name','')}**")
    lines.append(f"**当前价格：** {result.get('current_price')} | **市值：** {result.get('market_cap')}")
    lines.append(f"")

    lines.append(f"## 多情景内在价值对比")
    lines.append(f"")
    lines.append(f"| 场景 | ROIC | WACC | Spread | 护城河 | ARV | EPV | FV | 内在价值 | 安全边际 |")
    lines.append(f"|------|------|------|--------|-------|-----|-----|-----|---------|---------|")

    for sc in result.get("scenarios", []):
        a = sc["assumptions"]
        v = sc["valuation"]
        sm = v.get("safety_margin_pct", 0)
        sm_s = f"{sm:+}%" if sm > -999 else "N/A"
        color = "✅" if sm > 20 else "⚠️" if sm > 0 else "🔴"
        lines.append(f"| {sc['scenario']} | {a['roic_pct']}% | {a['wacc_pct']}% | {a['spread_pct']:+}% | {a['moat_years']}年 | ${v['arv_ps']} | ${v['epv_ps']} | ${v['fv_ps']} | **${v['intrinsic_ps']}** | {color} {sm_s} |")

    lines.append(f"")

    # 可视化：安全边际分布
    lines.append(f"## 可视化")
    lines.append(f"")
    lines.append(f"```")
    for sc in result.get("scenarios", []):
        v = sc["valuation"]
        sm = v.get("safety_margin_pct", 0)
        bar_len = 30
        if sm > 0:
            bars = int(sm / 100 * bar_len) if sm < 100 else bar_len
            bar = "🟩" * bars + "⬜" * (bar_len - bars)
        else:
            bars = min(int(abs(sm) / 100 * bar_len), bar_len)
            bar = "⬜" * (bar_len - bars) + "🟥" * bars
        lines.append(f"{sc['scenario'][:12]:<12} |{bar}| ${v['intrinsic_ps']:>6.0f}")
    lines.append(f"```")

    return "\n".join(lines)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticker", required=True)
    parser.add_argument("--output", default=None)
    parser.add_argument("--format", default="markdown", choices=["json", "markdown"])
    args = parser.parse_args()
    result = stress_test(args.ticker)
    out = json.dumps(result, indent=2, default=str) if args.format == "json" else to_markdown(result)
    if args.output:
        with open(args.output, "w") as f:
            f.write(out)
    else:
        print(out)

if __name__ == "__main__":
    main()
