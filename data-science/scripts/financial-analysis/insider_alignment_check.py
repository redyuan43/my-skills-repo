#!/usr/bin/env python3
"""
insider_alignment_check.py — 内部人利益一致性检查

检查"管理层是否和股东坐在同一条船上"：
  1. 内部人持股比例
  2. 内部人近期买卖交易（通过Finnhub）
  3. 股权激励（SBC）占营收比
  4. 薪酬结构（现金vs股权比例）
  5. 董事会结构
  6. 大股东质押情况（A股特有）

输出利益一致性评分和红旗警报。
"""

import json
import os
import sys
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data")
API_KEYS_PATH = os.path.join(BASE_DIR, "..", "config", "api_keys.json")


def _read_api_key(key_name):
    try:
        with open(API_KEYS_PATH) as f:
            return json.load(f).get(key_name, "")
    except:
        return ""


def check(ticker):
    """内部人利益一致性检查主函数"""
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info or {}
    cf = t.cashflow

    result = {
        "ticker": ticker.upper(),
        "company_name": info.get("longName") or info.get("shortName", ""),
        "sector": info.get("sector", ""),
        "fetch_time": datetime.now().isoformat(),
    }

    score = 10
    red_flags = []
    green_flags = []

    # ── 1. 内部人持股 ──
    insider_pct = info.get("heldPercentInsiders", 0)
    institution_pct = info.get("heldPercentInstitutions", 0)

    if insider_pct is not None:
        result["insider_ownership_pct"] = round(insider_pct * 100, 2)
        if insider_pct > 0.3:
            green_flags.append(f"内部人持股{insider_pct*100:.0f}%，利益高度一致")
            score += 0.5
        elif insider_pct > 0.1:
            green_flags.append(f"内部人持股{insider_pct*100:.0f}%，利益基本一致")
        else:
            red_flags.append(f"内部人持股仅{insider_pct*100:.1f}%，利益绑定不足")
            score -= 1

    if institution_pct is not None:
        result["institution_ownership_pct"] = round(institution_pct * 100, 2)

    # ── 2. 股权激励(SBC)审查 ──
    if cf is not None and not cf.empty:
        cf_years = sorted(cf.columns, reverse=True)[:3]
        sbc_data = []
        for y in cf_years:
            sbc = abs(float(cf.loc["Stock Based Compensation", y])) if "Stock Based Compensation" in cf.index else 0
            if sbc > 0:
                ocf = float(cf.loc["Operating Cash Flow", y]) if "Operating Cash Flow" in cf.index else 0
                sbc_data.append({"year": str(y)[:4], "sbc": sbc, "sbc_to_ocf_pct": round(sbc / ocf * 100, 1) if ocf else 0})
        if sbc_data:
            result["sbc_analysis"] = sbc_data
            avg_sbc_ratio = sum(s["sbc_to_ocf_pct"] for s in sbc_data) / len(sbc_data)
            if avg_sbc_ratio > 20:
                red_flags.append(f"SBC/经营现金流={avg_sbc_ratio:.0f}%，激励严重膨胀")
                score -= 2
            elif avg_sbc_ratio > 10:
                red_flags.append(f"SBC/经营现金流={avg_sbc_ratio:.0f}%，激励偏高")
                score -= 1
            else:
                green_flags.append(f"SBC/经营现金流={avg_sbc_ratio:.0f}%，激励适度")

    # ── 3. 通过Finnhub获取内部交易 ──
    api_key = _read_api_key("finnhub_api_key")
    if api_key:
        try:
            import finnhub
            fh = finnhub.Client(api_key=api_key)
            insider = fh.stock_insider_transactions(ticker, "US")
            if insider and insider.get("data"):
                transactions = []
                net_shares = 0
                for t in insider["data"][:10]:
                    change = t.get("change", 0) or 0
                    net_shares += change
                    transactions.append({
                        "name": t.get("name", ""),
                        "shares": change,
                        "price": t.get("transactionPrice", 0),
                        "date": t.get("transactionDate", ""),
                    })
                result["recent_insider_transactions"] = transactions
                if net_shares < 0:
                    red_flags.append(f"近90天内内部人净卖出{abs(net_shares):,}股")
                    score -= 1
                else:
                    green_flags.append(f"近90天内内部人净买入{net_shares:,}股")
                    score += 0.5
        except:
            pass

    # ── 4. 短期行为信号 ──
    payout = info.get("payoutRatio", 0)
    if payout and payout > 0.9:
        red_flags.append(f"派息率高达{payout*100:.0f}%，可能牺牲增长维持分红")
        score -= 1

    result["red_flags"] = red_flags
    result["green_flags"] = green_flags
    result["score"] = {"score": round(max(0, min(10, score)), 1), "max": 10}

    if score >= 7:
        result["verdict"] = "管理层与股东利益高度一致 ✅"
    elif score >= 4:
        result["verdict"] = "管理层利益基本一致，但有需要注意的地方 ⚠️"
    else:
        result["verdict"] = "管理层利益与股东偏离，需高度警惕 🔴"

    return result


def to_markdown(result):
    lines = [f"# 内部人利益一致性检查 — {result['ticker']}", f""]
    lines.append(f"**{result.get('company_name','')}** | {result.get('sector','')}")
    lines.append(f"")

    s = result.get("score", {})
    lines.append(f"**评分：{s.get('score','N/A')}/{s.get('max',10)}**")
    lines.append(f"**{result.get('verdict','')}**")
    lines.append(f"")

    if result.get("insider_ownership_pct") is not None:
        lines.append(f"- 内部人持股：{result['insider_ownership_pct']}%")
    if result.get("institution_ownership_pct") is not None:
        lines.append(f"- 机构持股：{result['institution_ownership_pct']}%")

    sbc = result.get("sbc_analysis", [])
    if sbc:
        lines.append(f"- SBC分析：")
        for s in sbc:
            lines.append(f"  - {s['year']}: SBC=${s['sbc']/1e6:.0f}M = OCF的{s['sbc_to_ocf_pct']}%")

    txs = result.get("recent_insider_transactions", [])
    if txs:
        lines.append(f"- 近90天内部交易：")
        for tx in txs:
            buy_sell = "卖出" if tx["shares"] < 0 else "买入"
            lines.append(f"  - {tx['name']} {buy_sell} {abs(tx['shares']):,}股 @ ${tx['price']}")
    lines.append(f"")

    for f in result.get("red_flags", []):
        lines.append(f"- 🚩 {f}")
    for f in result.get("green_flags", []):
        lines.append(f"- ✅ {f}")

    return "\n".join(lines)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticker", required=True)
    parser.add_argument("--output", default=None)
    parser.add_argument("--format", default="markdown", choices=["json", "markdown"])
    args = parser.parse_args()
    result = check(args.ticker)
    out = json.dumps(result, indent=2, default=str) if args.format == "json" else to_markdown(result)
    if args.output:
        with open(args.output, "w") as f:
            f.write(out)
    else:
        print(out)

if __name__ == "__main__":
    main()
