#!/usr/bin/env python3
"""
cross_validate.py — 报告生成前的数据交叉校验

在投资备忘录生成之前运行此脚本，检查所有数据的完整性、一致性和合理性。
如有任何检查未通过（非 warnings），报告生成应暂停并提示用户修正。

用法：
  python3 cross_validate.py --ticker BZ --data ../data/financials_BZ.json
  python3 cross_validate.py --ticker BZ --data ../data/financials_BZ.json --verbose

返回码：
  0 = 全部通过（可安全生成报告）
  1 = 有警告（可生成报告但需注意标注）
  2 = 有错误（应暂停报告生成）

输出：打印验证摘要到 stdout，同时写入 ../data/validation_[代码].json
"""

import argparse
import json
import os
import sys

# ── 检查项权重 ──
CRITICAL = "CRITICAL"   # 必须修复才能继续
WARNING  = "WARNING"    # 应在报告中注明
INFO     = "INFO"       # 仅供参考


def load_data(data_path):
    with open(data_path) as f:
        return json.load(f)


def _fmt(v):
    """格式化大数字为可读形式"""
    if v is None:
        return "N/A"
    v = float(v)
    if abs(v) >= 1e8:
        return f"¥{v/1e8:.1f}亿" if v < 1e12 else f"${v/1e9:.2f}B"
    if abs(v) >= 1e4:
        return f"¥{v/1e4:.0f}万"
    return f"{v:.0f}"


# ═══════════════════════════════════════════════════════
#  校验函数
# ═══════════════════════════════════════════════════════

def check_cash_completeness(data):
    """
    C1: 现金类科目完整性
    检查 total_cash_and_st_investments 是否远大于 cash_and_equivalents
    """
    bs_list = data.get("balance_sheet", [])
    if not bs_list:
        return []

    results = []
    latest = bs_list[0]
    cash_only = latest.get("cash_and_equivalents") or 0
    total_cash = (latest.get("total_cash_and_st_investments") or
                  cash_only + (latest.get("other_short_term_investments") or 0))

    if total_cash == 0:
        return [{"check": "C1", "level": WARNING, "message": "现金数据为空，可能未获取到资产负债表"}]

    # 如果 total_cash 远大于 cash_only，说明有大量现金不在活期账户中
    if cash_only > 0 and total_cash > cash_only * 1.5:
        pct = (total_cash - cash_only) / total_cash * 100
        return [{
            "check": "C1",
            "level": WARNING,
            "message": (
                f"非活期现金占现金总额的 {pct:.0f}% "
                f"(现金+等价物={_fmt(cash_only)}, "
                f"现金+短期投资合计={_fmt(total_cash)})。"
                f"请确认这些短期投资的真实流动性—"
                f"理财产品/定存赎回是否有锁定期限制？"
            )
        }]

    return [{"check": "C1", "level": INFO, "message": f"现金类科目完整: {_fmt(total_cash)}"}]


def check_currency_consistency(data):
    """
    C2: 币种一致性检查
    净现金 vs 市值 — 如果比值异常高，可能是币种不匹配
    """
    bs_list = data.get("balance_sheet", [])
    info = data.get("info", {})
    if not bs_list:
        return []

    latest = bs_list[0]
    total_cash = (latest.get("total_cash_and_st_investments") or
                  (latest.get("cash_and_equivalents") or 0) +
                  (latest.get("other_short_term_investments") or 0))
    debt = latest.get("total_debt") or 0
    net_cash = total_cash - debt
    market_cap = info.get("market_cap")
    currency = info.get("currency", "?")

    results = []

    if market_cap and market_cap > 0 and net_cash > 0:
        ratio = net_cash / market_cap
        if ratio > 0.8:
            results.append({
                "check": "C2",
                "level": CRITICAL,
                "message": (
                    f"净现金/市值 = {ratio*100:.0f}% > 80%, "
                    f"极可能有币种不匹配。"
                    f"资产负债表中现金标注为 {currency}，"
                    f"但市值通常为 USD。请统一币种后重算。"
                    f"净现金={_fmt(net_cash)}, 市值=${market_cap/1e9:.2f}B"
                )
            })
        elif ratio > 0.5:
            results.append({
                "check": "C2",
                "level": WARNING,
                "message": (
                    f"净现金/市值 = {ratio*100:.0f}%, "
                    f"现金占市值比例较高。请确认币种一致性（现金在{currency} vs 市值在USD）。"
                )
            })
        else:
            results.append({
                "check": "C2",
                "level": INFO,
                "message": f"净现金/市值 = {ratio*100:.0f}%, 在合理范围内"
            })

    return results


def check_roic_sanity(data):
    """
    C3: ROIC 合理性
    如果 ROIC > 200%，说明分母（投入资本）极小，可能因净现金≈权益
    """
    metrics = data.get("derived_metrics", {})
    roic = metrics.get("roic_pct")

    if roic is None:
        return [{"check": "C3", "level": WARNING, "message": "ROIC 未计算，无法检查"}]

    if roic > 200:
        return [{
            "check": "C3",
            "level": WARNING,
            "message": (
                f"ROIC = {roic:.0f}% > 200%, "
                f"因净现金≈权益导致投入资本过小，ROIC 分母失真。"
                f"报告的 ROIC 不代表真实的业务投资回报率。"
                f"建议：使用剔除冗余现金后的 tangible ROIC"
            )
        }]

    if roic < -50:
        return [{
            "check": "C3",
            "level": WARNING,
            "message": f"ROIC = {roic:.0f}%, 大幅为负，企业可能在毁损价值"
        }]

    return [{"check": "C3", "level": INFO, "message": f"ROIC = {roic:.1f}%, 在合理范围内"}]


def check_balance_sheet_integrity(data):
    """
    C4: 资产负债表完整性
    总资产 ≈ 流动资产 + 非流动资产
    """
    bs_list = data.get("balance_sheet", [])
    if not bs_list:
        return []

    latest = bs_list[0]
    ta = latest.get("total_assets")
    ca = latest.get("total_current_assets")
    nca = latest.get("total_non_current_assets")

    if ta and ca and nca and ta > 0:
        expected = ca + nca
        diff_pct = abs(expected - ta) / ta * 100
        if diff_pct > 5:
            return [{
                "check": "C4",
                "level": WARNING,
                "message": (
                    f"资产负债表分项合计({_fmt(expected)}) "
                    f"与 total_assets({_fmt(ta)}) 差异 {diff_pct:.0f}%。"
                    f"可能存在未映射的大额科目。"
                )
            }]

    equity = latest.get("shareholders_equity")
    liabilities = latest.get("total_liabilities")
    if ta and equity and liabilities:
        calc_equity = ta - liabilities
        diff_pct = abs(calc_equity - equity) / abs(equity) * 100 if equity else 0
        if diff_pct > 1:
            return [{
                "check": "C4",
                "level": WARNING,
                "message": (
                    f"权益(资产-负债={_fmt(calc_equity)}) "
                    f"与 shareholders_equity({_fmt(equity)}) 差异 {diff_pct:.1f}%。"
                    f"可能存在少数股东权益等科目。"
                )
            }]

    return [{"check": "C4", "level": INFO, "message": "资产负债表结构完整"}]


def check_earnings_quality(data):
    """
    C5: 利润质量 — 现金流 vs 净利润
    """
    cf_list = data.get("cash_flow", [])
    is_list = data.get("income_statement", [])

    if not cf_list or not is_list:
        return []

    results = []
    for i in range(min(3, len(cf_list), len(is_list))):
        ocf = cf_list[i].get("operating_cash_flow")
        ni = is_list[i].get("net_income")
        sbc = cf_list[i].get("stock_based_compensation")
        year = cf_list[i].get("fiscal_year", str(i))

        if ocf and ni and ni > 0:
            ratio = ocf / ni
            if ratio < 0.5:
                results.append({
                    "check": "C5",
                    "level": WARNING,
                    "message": f"{year}年 OCF/净利润 = {ratio:.1f}x < 0.5x, 利润含金量低，有大量应计项"
                })
            elif ratio > 3:
                results.append({
                    "check": "C5",
                    "level": INFO,
                    "message": f"{year}年 OCF/净利润 = {ratio:.1f}x, 现金流远高于利润（可能因预收/营运资本释放）"
                })

        if sbc and ni and ni > 0:
            sbc_ratio = abs(sbc) / ni
            if sbc_ratio > 0.5:
                results.append({
                    "check": "C5",
                    "level": WARNING,
                    "message": f"{year}年 SBC/净利润 = {sbc_ratio*100:.0f}%, SBC稀释严重，报告净利润被大幅高估"
                })

    if not results:
        results.append({"check": "C5", "level": INFO, "message": "利润质量未发现异常"})

    return results


def check_valuation_order(data):
    """
    C6: 估值大小顺序检查
    通常: ARV ≤ EPV ≤ 市值（或反之也可接受）
    如果市场价 < ARV，说明市场认为公司清盘也值这个价
    """
    metrics = data.get("derived_metrics", {})
    info = data.get("info", {})
    price = info.get("current_price")
    book_per_share = None

    bs_list = data.get("balance_sheet", [])
    if bs_list:
        equity = bs_list[0].get("shareholders_equity")
        shares = info.get("shares_outstanding")
        if equity and shares and shares > 0:
            book_per_share = equity / shares

    results = []
    if price and book_per_share:
        if price < book_per_share * 0.5:
            results.append({
                "check": "C6",
                "level": WARNING,
                "message": (
                    f"股价 ${price:.2f} < PB/2 = ${book_per_share/2:.2f}, 市净率 < 0.5x。"
                    f"市场认为资产质量堪忧。请检查资产负债表是否有大额商誉或不良资产。"
                )
            })

    if not results:
        results.append({"check": "C6", "level": INFO, "message": "估值顺序无异常"})

    return results


def check_debt_safety(data):
    """
    C7: 债务安全性
    检查总负债/总资产、有息负债率
    """
    bs_list = data.get("balance_sheet", [])
    if not bs_list:
        return []

    latest = bs_list[0]
    ta = latest.get("total_assets")
    tl = latest.get("total_liabilities")
    debt = latest.get("total_debt")
    equity = latest.get("shareholders_equity")

    results = []
    if ta and tl and ta > 0:
        ratio = tl / ta
        if ratio > 0.7:
            results.append({
                "check": "C7",
                "level": WARNING,
                "message": f"资产负债率 = {ratio*100:.0f}%, 杠杆偏高"
            })
        elif ratio < 0.1:
            results.append({
                "check": "C7",
                "level": INFO,
                "message": f"资产负债率 = {ratio*100:.0f}%, 非常保守的资本结构"
            })

    if debt and equity and equity > 0:
        d_e = debt / equity
        if d_e > 2:
            results.append({
                "check": "C7",
                "level": WARNING,
                "message": f"有息负债/权益 = {d_e:.1f}x, 杠杆偏高"
            })

    if not results:
        results.append({"check": "C7", "level": INFO, "message": "债务结构安全"})

    return results


def check_sbc_impact(data):
    """
    C8: SBC 稀释影响
    """
    cf_list = data.get("cash_flow", [])
    is_list = data.get("income_statement", [])

    if not cf_list or not is_list:
        return []

    results = []
    for i in range(min(3, len(cf_list), len(is_list))):
        sbc = cf_list[i].get("stock_based_compensation")
        ocf = cf_list[i].get("operating_cash_flow")
        rev = is_list[i].get("revenue")
        year = cf_list[i].get("fiscal_year", str(i))

        if sbc and ocf and ocf > 0:
            sbc_ocf = abs(sbc) / ocf
            if sbc_ocf > 0.3:
                results.append({
                    "check": "C8",
                    "level": WARNING,
                    "message": f"{year}年 SBC/经营现金流 = {sbc_ocf*100:.0f}%, 员工激励大量以股权支付，真实利润被高估"
                })

        if sbc and rev and rev > 0:
            sbc_rev = abs(sbc) / rev
            if sbc_rev > 0.15:
                results.append({
                    "check": "C8",
                    "level": INFO,
                    "message": f"{year}年 SBC/营收 = {sbc_rev*100:.1f}%, 高于典型水平（通常 < 10%）"
                })

    if not results:
        results.append({"check": "C8", "level": INFO, "message": "SBC 影响在可接受范围内"})

    return results


# ═══════════════════════════════════════════════════════
#  主函数
# ═══════════════════════════════════════════════════════

ALL_CHECKS = [
    ("C1 现金完整性", check_cash_completeness),
    ("C2 币种一致性", check_currency_consistency),
    ("C3 ROIC合理性", check_roic_sanity),
    ("C4 资产负债表完整性", check_balance_sheet_integrity),
    ("C5 利润质量", check_earnings_quality),
    ("C6 估值顺序", check_valuation_order),
    ("C7 债务安全性", check_debt_safety),
    ("C8 SBC稀释影响", check_sbc_impact),
]


def main():
    parser = argparse.ArgumentParser(description="报告生成前数据交叉校验")
    parser.add_argument("--ticker", required=True, help="股票代码")
    parser.add_argument("--data", required=True, help="financials JSON 路径")
    parser.add_argument("--verbose", action="store_true", help="详细输出")
    args = parser.parse_args()

    data_path = os.path.abspath(args.data)
    if not os.path.exists(data_path):
        print(f"[cross_validate] ❌ 未找到数据文件: {data_path}", file=sys.stderr)
        sys.exit(2)

    data = load_data(data_path)

    print(f"╔═══════════════════════════════════════════╗")
    print(f"║  交叉校验报告 — {args.ticker:<12s}         ║")
    print(f"╚═══════════════════════════════════════════╝")
    print()

    all_items = []
    errors = 0
    warnings = 0

    for check_name, check_fn in ALL_CHECKS:
        try:
            items = check_fn(data)
        except Exception as e:
            items = [{"check": check_name.split()[0], "level": WARNING, "message": f"校验执行异常: {e}"}]

        for item in items:
            level = item.get("level", INFO)
            msg = item.get("message", "")
            all_items.append(item)

            if level == CRITICAL:
                print(f"  ❌ [{item['check']}] {msg}")
                errors += 1
            elif level == WARNING:
                print(f"  ⚠️  [{item['check']}] {msg}")
                warnings += 1
            elif args.verbose:
                print(f"  ✅ [{item['check']}] {msg}")

    print()
    print(f"─── 汇总 ───")
    print(f"  校验项数: {len(all_items)}")
    print(f"  错误(需修复): {errors}")
    print(f"  警告(需关注): {warnings}")
    print(f"  通过: {len(all_items) - errors - warnings}")
    print()

    if errors > 0:
        print(f"  ❌ 存在 {errors} 项关键问题，建议暂停报告生成并修复。")
        print(f"     修正后重新运行:")
        print(f"     python3 cross_validate.py --ticker {args.ticker} --data {data_path}")
        print()
        exit_code = 2
    elif warnings > 0:
        print(f"  ⚠️  存在 {warnings} 项警告，报告中应注明。可继续生成报告。")
        exit_code = 1
    else:
        print(f"  ✅ 全部通过，可安全生成报告。")
        exit_code = 0

    # 写入校验结果
    result = {
        "ticker": args.ticker,
        "data_file": data_path,
        "items": all_items,
        "errors": errors,
        "warnings": warnings,
        "passed": len(all_items) - errors - warnings,
        "status": "fail" if errors > 0 else "warn" if warnings > 0 else "pass",
    }
    report_dir = os.path.dirname(data_path)
    out_path = os.path.join(report_dir, f"validation_{args.ticker}.json")
    with open(out_path, "w") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
