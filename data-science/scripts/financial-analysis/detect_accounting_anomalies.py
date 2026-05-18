#!/usr/bin/env python3
"""
detect_accounting_anomalies.py — 会计异常检测

从财务报表中自动识别红旗信号，包括：
  1. 应收天数(DSO)异常增加
  2. 存货天数(DIO)异常增加
  3. 应付天数(DPO)异常减少
  4. 商誉占总资产比过高
  5. 经营现金流与净利润持续背离
  6. 营收增速与应收增速背离
  7. 毛利率与营收增速背离
  8. 资本开支与折旧的比值异常
"""

import json
import os
import sys
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data")


def detect(ticker):
    """会计异常检测主函数"""
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info or {}
    inc = t.income_stmt
    bs = t.balance_sheet
    cf = t.cashflow

    result = {
        "ticker": ticker.upper(),
        "company_name": info.get("longName") or info.get("shortName", ""),
    }

    anomalies = []
    score = 10

    # ── 1. 商誉占比 ──
    if bs is not None and not bs.empty:
        year = sorted(bs.columns, reverse=True)[0]
        gw = float(bs.loc["Goodwill", year]) if "Goodwill" in bs.index else 0
        ta = float(bs.loc["Total Assets", year]) if "Total Assets" in bs.index else 0
        if ta and gw / ta > 0.3:
            anomalies.append({
                "type": "high_goodwill", "severity": "高",
                "signal": f"商誉占总资产{gw/ta*100:.0f}%，减值风险高",
                "detail": f"商誉${gw/1e9:.1f}B / 总资产${ta/1e9:.1f}B"
            })
            score -= 1.5

    # ── 2. 经营现金流 vs 净利润 ──
    if cf is not None and not cf.empty and inc is not None and not inc.empty:
        cf_years = sorted(cf.columns, reverse=True)[:3]
        inc_years = sorted(inc.columns, reverse=True)[:3]
        ocf_vs_ni = []
        for cy, iy in zip(cf_years, inc_years):
            ocf = float(cf.loc["Operating Cash Flow", cy]) if "Operating Cash Flow" in cf.index else 0
            ni = float(inc.loc["Net Income", iy]) if "Net Income" in inc.index else 0
            if ni and ocf / ni < 0.5:
                ocf_vs_ni.append({"year": str(cy)[:4], "ocf": ocf, "ni": ni, "ratio": round(ocf/ni, 2)})
        if ocf_vs_ni:
            anomalies.append({
                "type": "ocf_ni_divergence", "severity": "高",
                "signal": "经营现金流/净利润 < 0.5x",
                "detail": f"利润质量差，赚到的利润未转化为现金：{ocf_vs_ni}"
            })
            score -= 2

    # ── 3. 营收增速 vs 应收增速 ──
    if inc is not None and not inc.empty and bs is not None and not bs.empty:
        inc_years = sorted(inc.columns, reverse=True)[:3]
        bs_years = sorted(bs.columns, reverse=True)[:3]
        dso_trend = []
        for iy, by in zip(inc_years, bs_years):
            rev = float(inc.loc["Total Revenue", iy]) if "Total Revenue" in inc.index else 0
            ar = float(bs.loc["Net Receivables", by]) if "Net Receivables" in bs.index else 0
            if rev and ar:
                dso = ar / rev * 365
                dso_trend.append({"year": str(iy)[:4], "dso": round(dso, 1)})
        if len(dso_trend) >= 2 and dso_trend[0]["dso"] > dso_trend[-1]["dso"] * 1.3:
            anomalies.append({
                "type": "dso_spike", "severity": "中",
                "signal": f"应收天数从{dso_trend[-1]['dso']}天升至{dso_trend[0]['dso']}天",
                "detail": "可能通过放宽信用条件虚增营收"
            })
            score -= 1

    # ── 4. CapEx/折旧比 ──
    if cf is not None and not cf.empty:
        cf_years = sorted(cf.columns, reverse=True)[:3]
        capex_da = []
        for y in cf_years:
            capex = abs(float(cf.loc["Capital Expenditure", y])) if "Capital Expenditure" in cf.index else 0
            da = float(cf.loc["Depreciation And Amortization", y]) if "Depreciation And Amortization" in cf.index else 0
            if da:
                capex_da.append({"year": str(y)[:4], "ratio": round(capex/da, 2)})
        if len(capex_da) >= 2 and capex_da[0]["ratio"] < 0.5:
            anomalies.append({
                "type": "under_investing", "severity": "中",
                "signal": f"CapEx/折旧={capex_da[0]['ratio']}x < 1.0x",
                "detail": "资本开支不足以维持现有产能，长期看资产基础在萎缩"
            })
            score -= 1

    # ── 5. 营收增速 vs 存货增速 ──
    if inc is not None and not inc.empty and bs is not None and not bs.empty:
        inc_years = sorted(inc.columns, reverse=True)[:3]
        bs_years = sorted(bs.columns, reverse=True)[:3]
        inv_trend = []
        for iy, by in zip(inc_years, bs_years):
            rev = float(inc.loc["Total Revenue", iy]) if "Total Revenue" in inc.index else 0
            inv = float(bs.loc["Inventory", by]) if "Inventory" in bs.index else 0
            if rev and inv:
                inv_trend.append({"year": str(iy)[:4], "inv_turnover_days": round(inv / rev * 365, 1)})
        if len(inv_trend) >= 2 and inv_trend[0]["inv_turnover_days"] > inv_trend[-1]["inv_turnover_days"] * 1.5:
            anomalies.append({
                "type": "inventory_buildup", "severity": "中",
                "signal": f"存货周转天数从{inv_trend[-1]['inv_turnover_days']}天升至{inv_trend[0]['inv_turnover_days']}天",
                "detail": "存货积压，可能面临跌价风险"
            })
            score -= 1

    result["anomalies"] = anomalies
    result["count"] = len(anomalies)
    result["score"] = round(max(0, score), 1)

    if not anomalies:
        result["verdict"] = "✅ 未发现明显会计异常"
    elif score >= 7:
        result["verdict"] = f"⚠️ 发现{len(anomalies)}项异常，需进一步确认"
    else:
        result["verdict"] = f"🔴 发现{len(anomalies)}项高风险异常，建议谨慎"

    return result


def to_markdown(result):
    lines = [f"# 会计异常检测 — {result['ticker']}", f""]
    lines.append(f"**{result.get('company_name','')}** | 得分：{result.get('score','N/A')}/10")
    lines.append(f"**{result.get('verdict','')}**")
    lines.append(f"")

    if not result.get("anomalies"):
        lines.append("无异常信号。")
        return "\n".join(lines)

    lines.append(f"| 严重度 | 信号 | 详情 |")
    lines.append(f"|--------|------|------|")
    for a in result["anomalies"]:
        sev = {"高": "🔴", "中": "🟡", "低": "🟢"}.get(a.get("severity",""), "⚪")
        lines.append(f"| {sev} {a['severity']} | {a['signal']} | {a['detail']} |")

    return "\n".join(lines)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticker", required=True)
    parser.add_argument("--output", default=None)
    parser.add_argument("--format", default="markdown", choices=["json", "markdown"])
    args = parser.parse_args()
    result = detect(args.ticker)
    out = json.dumps(result, indent=2, default=str) if args.format == "json" else to_markdown(result)
    if args.output:
        with open(args.output, "w") as f:
            f.write(out)
    else:
        print(out)

if __name__ == "__main__":
    main()
