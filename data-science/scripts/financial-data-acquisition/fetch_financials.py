#!/usr/bin/env python3
"""
fetch_financials.py — 金融数据采集器

从 yfinance 拉取过去 5 年完整财报数据，输出结构化 JSON。
对 yfinance 缺失的数据字段标记为 null，由调用方通过 web 搜索补充。

用法：
  python3 scripts/fetch_financials.py --ticker AAPL
  python3 scripts/fetch_financials.py --ticker AAPL --output /path/to/output.json
  python3 scripts/fetch_financials.py --ticker 600519.SS --format markdown
  python3 scripts/fetch_financials.py --ticker GOOGL --years 3
"""

import json
import os
import sys
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(BASE_DIR)
DATA_DIR = os.path.join(SKILL_DIR, "..", "data")  # financial-screener/data
# 如果没有 financial-screener，存在自身 skill 目录下
FALLBACK_DIR = os.path.join(BASE_DIR, "..", "data")
os.makedirs(DATA_DIR, exist_ok=True)


# ═══════════════════════════════════════════════════════
#  yfinance 财务报表字段映射
# ═══════════════════════════════════════════════════════

# 利润表字段映射 (yfinance item name -> 标准输出名)
INCOME_MAP = {
    "Total Revenue": "revenue",
    "Cost Of Revenue": "cost_of_revenue",
    "Gross Profit": "gross_profit",
    "Research And Development": "rd_expense",
    "Selling General And Administration": "sga_expense",
    "Operating Expenses": "operating_expenses",
    "Operating Income": "operating_income",
    "EBIT": "ebit",
    "Interest Expense": "interest_expense",
    "Interest Income": "interest_income",
    "Other Income Expense": "other_income",
    "Income Before Tax": "pretax_income",
    "Tax Provision": "tax_provision",
    "Net Income": "net_income",
    "Net Income From Continuing Ops": "net_income_continuing",
    "Minority Interest": "minority_interest",
    "Basic EPS": "basic_eps",
    "Diluted EPS": "diluted_eps",
    "Diluted Average Shares": "diluted_shares",
    "Basic Average Shares": "basic_shares",
}

# 资产负债表字段映射
BALANCE_MAP = {
    "Cash And Cash Equivalents": "cash_and_equivalents",
    "Short Term Investments": "short_term_investments",
    "Other Short Term Investments": "other_short_term_investments",
    "Cash Cash Equivalents And Short Term Investments": "total_cash_and_st_investments",
    "Cash And Short Term Investments": "cash_and_investments",
    "Net Receivables": "accounts_receivable",
    "Inventory": "inventory",
    "Other Current Assets": "other_current_assets",
    "Total Current Assets": "total_current_assets",
    "Property Plant Equipment": "pp_and_e",
    "Goodwill": "goodwill",
    "Intangible Assets": "intangible_assets",
    "Goodwill And Intangible Assets": "goodwill_and_intangibles",
    "Long Term Investments": "long_term_investments",
    "Other Non Current Assets": "other_non_current_assets",
    "Total Non Current Assets": "total_non_current_assets",
    "Total Assets": "total_assets",
    "Accounts Payable": "accounts_payable",
    "Short Long Term Debt": "short_term_debt",
    "Current Debt": "current_debt",
    "Other Current Liabilities": "other_current_liabilities",
    "Total Current Liabilities": "total_current_liabilities",
    "Long Term Debt": "long_term_debt",
    "Total Debt": "total_debt",
    "Deferred Revenue": "deferred_revenue",
    "Other Non Current Liabilities": "other_non_current_liabilities",
    "Total Non Current Liabilities": "total_non_current_liabilities",
    "Total Liabilities Net Minority Interest": "total_liabilities",
    "Stockholders Equity": "shareholders_equity",
    "Retained Earnings": "retained_earnings",
    "Accumulated Other Comprehensive Income": "accumulated_oci",
}

# 现金流量表字段映射
CASHFLOW_MAP = {
    "Operating Cash Flow": "operating_cash_flow",
    "Investing Cash Flow": "investing_cash_flow",
    "Financing Cash Flow": "financing_cash_flow",
    "Capital Expenditure": "capital_expenditures",
    "Free Cash Flow": "free_cash_flow",
    "Stock Based Compensation": "stock_based_compensation",
    "Dividends Paid": "dividends_paid",
    "Common Stock Dividend Paid": "common_dividends",
    "Repurchase Of Capital Stock": "share_repurchases",
    "Issuance Of Capital Stock": "share_issuance",
    "Change In Working Capital": "change_in_working_capital",
    "Depreciation And Amortization": "depreciation_and_amortization",
    "Net Borrowings": "net_borrowings",
    "Cash From Discontinued Ops": "cash_from_discontinued",
    "Other Financing Activities": "other_financing",
}


def _safe_val(val):
    """安全取值，NaN/None -> None"""
    if val is None:
        return None
    try:
        if isinstance(val, float) and (val != val):  # NaN check
            return None
        return int(val) if abs(val) > 1e9 else float(val)
    except (ValueError, TypeError, OverflowError):
        return None


def extract_financials(ticker_symbol):
    """
    从 yfinance 提取 5 年财报数据

    返回 dict:
    {
        "ticker": "...",
        "company_name": "...",
        "source": "yfinance",
        "income_statement": [{...}, ...],
        "balance_sheet": [{...}, ...],
        "cash_flow": [{...}, ...],
        "info": {...}
    }
    """
    import yfinance as yf

    ticker = yf.Ticker(ticker_symbol)

    # ── 基本信息 ──
    info = {}
    try:
        raw_info = ticker.info or {}
        info = {
            "company_name": raw_info.get("longName") or raw_info.get("shortName", ""),
            "sector": raw_info.get("sector", ""),
            "industry": raw_info.get("industry", ""),
            "current_price": raw_info.get("currentPrice") or raw_info.get("regularMarketPrice"),
            "market_cap": raw_info.get("marketCap"),
            "enterprise_value": raw_info.get("enterpriseValue"),
            "shares_outstanding": raw_info.get("sharesOutstanding"),
            "fiscal_year_end": raw_info.get("fiscalYearEnd", ""),
            "trailing_pe": raw_info.get("trailingPE"),
            "forward_pe": raw_info.get("forwardPE"),
            "price_to_book": raw_info.get("priceToBook"),
            "dividend_yield": raw_info.get("dividendYield"),
            "payout_ratio": raw_info.get("payoutRatio"),
            "beta": raw_info.get("beta"),
            "fifty_two_week_high": raw_info.get("fiftyTwoWeekHigh"),
            "fifty_two_week_low": raw_info.get("fiftyTwoWeekLow"),
            "employees": raw_info.get("fullTimeEmployees"),
            "country": raw_info.get("country"),
            "exchange": raw_info.get("exchange"),
            "currency": raw_info.get("financialCurrency", "USD"),
        }
    except Exception as e:
        info = {"error": str(e)}

    # ── 利润表 ──
    income_stmt = []
    try:
        raw_income = ticker.income_stmt
        if raw_income is not None and not raw_income.empty:
            years = sorted(raw_income.columns, reverse=True)[:5]
            for year in years:
                record = {"fiscal_year": str(year)[:4] if hasattr(year, 'strftime') else str(year)[:4]}
                for yf_name, out_name in INCOME_MAP.items():
                    if yf_name in raw_income.index:
                        record[out_name] = _safe_val(raw_income.loc[yf_name, year])
                income_stmt.append(record)
    except Exception as e:
        print(f"[fetch] ⚠️  利润表读取失败: {e}", file=sys.stderr)

    # ── 资产负债表 ──
    balance_sheet = []
    try:
        raw_bs = ticker.balance_sheet
        if raw_bs is not None and not raw_bs.empty:
            years = sorted(raw_bs.columns, reverse=True)[:5]
            for year in years:
                record = {"fiscal_year": str(year)[:4]}
                # ── 白名单映射 ──
                for yf_name, out_name in BALANCE_MAP.items():
                    if yf_name in raw_bs.index:
                        record[out_name] = _safe_val(raw_bs.loc[yf_name, year])

                # ── 自动发现未映射字段（特别是现金/投资类） ──
                CASH_KEYWORDS = ['cash', 'short_term_investment', 'short term investment']
                for idx in raw_bs.index:
                    if idx not in BALANCE_MAP:
                        idx_lower = idx.lower()
                        if any(kw in idx_lower for kw in CASH_KEYWORDS):
                            safe_name = idx.lower().replace(' ', '_').replace('-', '_')
                            if safe_name not in record:
                                record["unmapped_" + safe_name] = _safe_val(raw_bs.loc[idx, year])
                                if record["unmapped_" + safe_name] is not None:
                                    print(f"[fetch] 🔍 自动发现未映射的现金类字段: {idx} = {record['unmapped_' + safe_name]:,}", file=sys.stderr)

                # ── 现金自动汇总 ──
                cash_field_keys = ['cash_and_equivalents', 'short_term_investments',
                                   'other_short_term_investments', 'cash_and_investments']
                existing_cash_keys = [k for k in cash_field_keys if k in record and record[k] is not None]
                unmapped_cash_keys = [k for k in sorted(record.keys()) if k.startswith('unmapped_') and ('cash' in k.lower() or 'short_term' in k.lower())]

                auto_total_cash = sum(record[k] for k in existing_cash_keys if record.get(k)) + \
                                  sum(record[k] for k in unmapped_cash_keys if record.get(k) and k not in existing_cash_keys)

                if 'total_cash_and_st_investments' in record and record['total_cash_and_st_investments'] is not None:
                    record['_total_cash_check'] = {
                        'auto_summed_cash': auto_total_cash,
                        'yfinance_total': record['total_cash_and_st_investments'],
                    }
                    if auto_total_cash > 0:
                        diff_pct = abs(auto_total_cash - record['total_cash_and_st_investments']) / auto_total_cash * 100
                        if diff_pct > 1:
                            print(f"[fetch] ⚠️  现金合计不匹配: 自动汇总={auto_total_cash:,} vs yfinance合计={record['total_cash_and_st_investments']:,} 差异{diff_pct:.1f}%", file=sys.stderr)
                else:
                    record['_auto_total_cash'] = auto_total_cash
                    print(f"[fetch] ℹ️  现金自动汇总: {auto_total_cash:,}", file=sys.stderr)

                # 派生指标
                equity = record.get("shareholders_equity")
                shares = info.get("shares_outstanding")
                if equity and shares and shares > 0:
                    record["book_value_per_share"] = round(equity / shares, 2)
                balance_sheet.append(record)
    except Exception as e:
        print(f"[fetch] ⚠️  资产负债表读取失败: {e}", file=sys.stderr)

    # ── 现金流量表 ──
    cash_flow = []
    try:
        raw_cf = ticker.cashflow
        if raw_cf is not None and not raw_cf.empty:
            years = sorted(raw_cf.columns, reverse=True)[:5]
            for year in years:
                record = {"fiscal_year": str(year)[:4]}
                for yf_name, out_name in CASHFLOW_MAP.items():
                    if yf_name in raw_cf.index:
                        record[out_name] = _safe_val(raw_cf.loc[yf_name, year])

                # 派生：真实 FCF（经营现金流 - 资本开支 - SBC）
                ocf = record.get("operating_cash_flow")
                capex = record.get("capital_expenditures")
                sbc = record.get("stock_based_compensation")
                if ocf is not None and capex is not None:
                    raw_fcf = ocf + capex  # capex 是负值
                    record["free_cash_flow"] = _safe_val(raw_fcf)
                    if sbc is not None:
                        record["true_owner_earnings"] = _safe_val(raw_fcf - sbc)
                    else:
                        record["true_owner_earnings"] = None

                # 真实股东回报 = 回购 + 分红
                buybacks = record.get("share_repurchases")
                divs = record.get("dividends_paid") or record.get("common_dividends")
                total_return = 0
                if buybacks is not None:
                    total_return += abs(buybacks) if buybacks < 0 else buybacks
                if divs is not None:
                    total_return += abs(divs) if divs < 0 else divs
                record["total_shareholder_return"] = _safe_val(total_return)

                cash_flow.append(record)
    except Exception as e:
        print(f"[fetch] ⚠️  现金流量表读取失败: {e}", file=sys.stderr)

    return {
        "ticker": ticker_symbol.upper(),
        "source": "yfinance",
        "fetch_time": datetime.now().isoformat(),
        "info": info,
        "income_statement": income_stmt,
        "balance_sheet": balance_sheet,
        "cash_flow": cash_flow,
    }


# ═══════════════════════════════════════════════════════
#  派生指标计算
# ═══════════════════════════════════════════════════════
def compute_derived_metrics(data):
    """计算派生指标：FCF Yield、ROIC、股东收益率等"""
    metrics = {}
    info = data.get("info", {})
    market_cap = info.get("market_cap") or info.get("marketCap")
    currency = info.get("currency", "USD")

    cf = data.get("cash_flow", [])
    is_ = data.get("income_statement", [])
    bs = data.get("balance_sheet", [])

    if market_cap and cf:
        # 最近一年的 FCF Yield
        latest_cf = cf[0] if cf else {}
        fcf = latest_cf.get("free_cash_flow")
        true_earnings = latest_cf.get("true_owner_earnings")
        shareholder_return = latest_cf.get("total_shareholder_return")

        if fcf and market_cap > 0:
            metrics["fcf_yield_pct"] = round(abs(fcf) / market_cap * 100, 2)
        if true_earnings and market_cap > 0:
            metrics["true_owner_yield_pct"] = round(abs(true_earnings) / market_cap * 100, 2)
        if shareholder_return and market_cap > 0:
            metrics["shareholder_yield_pct"] = round(shareholder_return / market_cap * 100, 2)

    # ROIC 计算（最近一年）
    if is_ and bs:
        latest_is = is_[0] if is_ else {}
        latest_bs = bs[0] if bs else {}
        op_income = latest_is.get("operating_income") or latest_is.get("ebit")
        total_debt = latest_bs.get("total_debt", 0) or 0
        equity = latest_bs.get("shareholders_equity", 0) or 0

        # ⚠️ [2026-05-03] 修正: 优先使用 total_cash_and_st_investments (含短期投资)
        # 之前只用了 cash_and_equivalents, 导致 BZ 等中概股漏掉 ¥158亿理财产品
        total_cash = (latest_bs.get("total_cash_and_st_investments")
                      or (latest_bs.get("cash_and_equivalents", 0) or 0)
                          + (latest_bs.get("short_term_investments", 0) or 0)
                          + (latest_bs.get("other_short_term_investments", 0) or 0))

        if op_income is not None and (total_debt + equity - total_cash) != 0:
            # 简单税率假设 20%
            nopat = op_income * 0.8
            invested_capital = (total_debt or 0) + (equity or 0) - total_cash
            if invested_capital > 0:
                metrics["roic_pct"] = round(nopat / invested_capital * 100, 2)
                # ROIC > 200% 通常是净现金≈权益导致的分母过小，非真实超额回报
                if metrics["roic_pct"] > 200:
                    metrics["_warnings"] = metrics.get("_warnings", []) + [
                        f"⚠️  ROIC={metrics['roic_pct']:.0f}% > 200%, "
                        f"因投入资本(¥{invested_capital/1e6:.0f}M)过小（净现金≈权益），"
                        f"ROIC分母失真。请改用 tangible ROIC 或剔除冗余现金后重新计算"
                    ]

        # 毛利率趋势
        gross_margins = []
        for rec in is_[:3]:
            rev = rec.get("revenue")
            gp = rec.get("gross_profit")
            if rev and gp and rev > 0:
                gross_margins.append(round(gp / rev * 100, 1))
        if gross_margins:
            metrics["gross_margin_trend_pct"] = gross_margins
            metrics["gross_margin_avg_3y_pct"] = round(sum(gross_margins) / len(gross_margins), 1)

        # 净利率趋势
        net_margins = []
        for rec in is_[:3]:
            rev = rec.get("revenue")
            ni = rec.get("net_income")
            if rev and ni and rev > 0:
                net_margins.append(round(ni / rev * 100, 1))
        if net_margins:
            metrics["net_margin_trend_pct"] = net_margins

        # 营收增长率
        revenues = [r.get("revenue") for r in is_[:3] if r.get("revenue")]
        if len(revenues) >= 2:
            growth = (revenues[0] - revenues[1]) / abs(revenues[1]) * 100
            metrics["revenue_growth_yoy_pct"] = round(growth, 1)

    # 现金占市值比
    if bs and market_cap:
        latest = bs[0]
        total_cash = (latest.get("total_cash_and_st_investments")
                      or (latest.get("cash_and_equivalents") or 0)
                          + (latest.get("short_term_investments") or 0)
                          + (latest.get("other_short_term_investments") or 0))
        if total_cash and market_cap > 0:
            metrics["cash_to_market_cap_pct"] = round(total_cash / market_cap * 100, 1)

            # ⚠️ 数据合理性检查: 如果现金/市值比例异常高, 告警
            if total_cash / market_cap > 1.0:
                metrics["_warnings"] = metrics.get("_warnings", []) + [
                    f"⚠️  现金/市值={total_cash/market_cap*100:.0f}% > 100%, 请检查币种一致性: "
                    f"现金在{info.get('currency','?')}, 市值在USD"
                ]

    # SBC 占营收比
    sbc_ratios = []
    for i, cf_rec in enumerate(cf[:3]):
        sbc = cf_rec.get("stock_based_compensation")
        rev = is_[i].get("revenue") if i < len(is_) else None
        if sbc and rev and rev > 0:
            sbc_ratios.append(round(abs(sbc) / rev * 100, 2))
    if sbc_ratios:
        metrics["sbc_to_revenue_pct"] = sbc_ratios

    # ═══════════════════════════════════════════════════
    #  资产负债表完整性校验
    # ═══════════════════════════════════════════════════
    if bs:
        latest = bs[0]
        ta = latest.get("total_assets")
        if ta and ta > 0:
            # 尝试从可识别的分项推算总资产
            asset_parts = [
                latest.get(k) for k in
                ["total_current_assets", "total_non_current_assets"]
                if latest.get(k) is not None
            ]
            if len(asset_parts) == 2:
                expected = sum(asset_parts)
                diff_pct = abs(expected - ta) / ta * 100
                if diff_pct > 5:
                    metrics["_warnings"] = metrics.get("_warnings", []) + [
                        f"⚠️  资产负债表完整性: current+non-current={expected:,} vs total_assets={ta:,} 差异{diff_pct:.0f}%"
                    ]

    return metrics


# ═══════════════════════════════════════════════════════
#  Markdown 格式化输出
# ═══════════════════════════════════════════════════════
def to_markdown(data):
    """输出人类可读的 Markdown 摘要"""
    info = data.get("info", {})
    lines = []
    lines.append(f"# 财务数据摘要 — {data['ticker']}")
    lines.append(f"")
    lines.append(f"**{info.get('company_name', 'N/A')}**")
    lines.append(f"")
    lines.append(f"| 指标 | 数值 |")
    lines.append(f"|------|------|")
    lines.append(f"| 股价 | {info.get('current_price', 'N/A')} {info.get('currency', '')} |")
    lines.append(f"| 市值 | {_fmt_large(info.get('market_cap'))} |")
    lines.append(f"| 已发行股份 | {_fmt_large(info.get('shares_outstanding'))} |")
    lines.append(f"| 行业 | {info.get('sector', 'N/A')} / {info.get('industry', 'N/A')} |")
    lines.append(f"| PE(TTM) | {info.get('trailing_pe', 'N/A')} |")
    lines.append(f"| 数据源 | {data.get('source', 'yfinance')} |")
    lines.append(f"")
    lines.append(f"---")
    lines.append(f"")

    # 利润表
    is_ = data.get("income_statement", [])
    if is_:
        lines.append(f"## 利润表")
        lines.append(f"")
        headers = ["科目"] + [r["fiscal_year"] for r in is_]
        lines.append(f"| {' | '.join(headers)} |")
        lines.append(f"| {' | '.join(['---'] * len(headers))} |")

        rows = ["revenue", "gross_profit", "operating_income", "net_income",
                "basic_eps", "diluted_eps", "diluted_shares"]
        labels = ["营收", "毛利润", "营业利润", "净利润", "基本EPS", "稀释EPS", "稀释股份"]
        for row, label in zip(rows, labels):
            vals = [label]
            for r in is_:
                v = r.get(row)
                vals.append(_fmt_val(v))
            lines.append(f"| {' | '.join(vals)} |")
        lines.append(f"")

    # 现金流量表
    cf = data.get("cash_flow", [])
    if cf:
        lines.append(f"## 现金流量表")
        lines.append(f"")
        headers = ["科目"] + [r["fiscal_year"] for r in cf]
        lines.append(f"| {' | '.join(headers)} |")
        lines.append(f"| {' | '.join(['---'] * len(headers))} |")

        rows = [("operating_cash_flow", "经营现金流"),
                ("capital_expenditures", "资本开支"),
                ("free_cash_flow", "自由现金流"),
                ("stock_based_compensation", "股权激励(SBC)"),
                ("true_owner_earnings", "真实所有者盈余(扣SBC)"),
                ("share_repurchases", "股票回购"),
                ("dividends_paid", "分红（总额）"),
                ("common_dividends", "普通股分红"),
                ("total_shareholder_return", "股东总回报(含回购)"),
                ("depreciation_and_amortization", "折旧摊销")]
        for row_key, label in rows:
            vals = [label]
            for r in cf:
                v = r.get(row_key)
                vals.append(_fmt_val(v))
            lines.append(f"| {' | '.join(vals)} |")
        lines.append(f"")

    # 资产负债表
    bs = data.get("balance_sheet", [])
    if bs:
        lines.append(f"## 资产负债表")
        lines.append(f"")
        headers = ["科目"] + [r["fiscal_year"] for r in bs]
        lines.append(f"| {' | '.join(headers)} |")
        lines.append(f"| {' | '.join(['---'] * len(headers))} |")

        rows = [("cash_and_equivalents", "现金"),
                ("short_term_investments", "短期投资"),
                ("accounts_receivable", "应收账款"),
                ("inventory", "存货"),
                ("goodwill_and_intangibles", "商誉+无形资产"),
                ("total_current_assets", "流动资产合计"),
                ("pp_and_e", "固定资产(PP&E)"),
                ("total_assets", "总资产"),
                ("total_debt", "总负债"),
                ("shareholders_equity", "股东权益"),
                ("book_value_per_share", "每股账面价值")]
        for row_key, label in rows:
            vals = [label]
            for r in bs:
                v = r.get(row_key)
                vals.append(_fmt_val(v))
            lines.append(f"| {' | '.join(vals)} |")
        lines.append(f"")

    # 派生指标
    metrics = data.get("derived_metrics", {})
    if metrics:
        lines.append(f"## 派生指标")
        lines.append(f"")
        for k, v in metrics.items():
            label = k.replace("_pct", "%").replace("_", " ").title()
            if isinstance(v, list):
                lines.append(f"- **{label}**: {v}")
            else:
                lines.append(f"- **{label}**: {v}")
        lines.append(f"")

    # 标记缺失字段
    lines.append(f"## 数据完整性")
    lines.append(f"")
    missing = []
    for section_name, section in [("利润表", is_), ("资产负债表", bs), ("现金流量表", cf)]:
        if not section:
            missing.append(f"- ❌ **{section_name}**: 无数据")
    if missing:
        lines.extend(missing)
        lines.append(f"")
        lines.append(f"> ⚠️ 以上缺失数据需要通过 web 搜索补充。")
    else:
        lines.append(f"- ✅ 三张报表数据完整")
        lines.append(f"")

    return "\n".join(lines)


def _fmt_large(v):
    if v is None:
        return "N/A"
    try:
        v = float(v)
        if abs(v) >= 1e12:
            return f"${v/1e12:.2f}T"
        elif abs(v) >= 1e9:
            return f"${v/1e9:.2f}B"
        elif abs(v) >= 1e6:
            return f"${v/1e6:.2f}M"
        else:
            return f"${v:.2f}"
    except (TypeError, ValueError):
        return str(v)


def _fmt_val(v):
    if v is None:
        return "N/A"
    try:
        v = float(v)
        if abs(v) >= 1e9:
            return f"{v/1e9:.2f}B"
        elif abs(v) >= 1e6:
            return f"{v/1e6:.2f}M"
        elif v == int(v):
            return str(int(v))
        else:
            return f"{v:.2f}"
    except (TypeError, ValueError):
        return str(v)


# ═══════════════════════════════════════════════════════
#  Baostock 补充数据（A股分红 + 指数成分股 + 行业）
# ═══════════════════════════════════════════════════════
def enrich_with_baostock(data):
    """
    使用 Baostock 补充 A 股数据（针对 .SS / .SZ 后缀的代码）
    
    补充内容：
    - 分红数据（每股税前分红、除权日）
    - 行业分类
    
    返回补充后的 data 字典（新增 "baostock" key）
    """
    ticker = data.get("ticker", "")
    # 只对 A 股执行
    is_a_share = ticker.endswith(".SS") or ticker.endswith(".SZ")
    if not is_a_share:
        return data

    # 去掉后缀获取纯代码
    raw_code = ticker.replace(".SS", "").replace(".SZ", "")
    # 补上 sh/sz 前缀
    prefix = "sh" if ticker.endswith(".SS") else "sz"
    bs_code = f"{prefix}.{raw_code}"

    try:
        import baostock as bs
        lg = bs.login()
        if lg.error_code != "0":
            print(f"[baostock] 登录失败: {lg.error_msg}", file=sys.stderr)
            return data

        bs_result = {}

        # ── 1. 分红数据（近3年） ──
        dividends = []
        for year in ["2024", "2023", "2022"]:
            try:
                rs = bs.query_dividend_data(code=bs_code, year=year)
                df = rs.get_data()
                if df is not None and not df.empty:
                    for _, row in df.iterrows():
                        d = {
                            "year": year,
                            "announce_date": row.get("dividPlanAnnounceDate", ""),
                            "ex_date": row.get("dividOperateDate", ""),
                            "cash_before_tax": _safe_float_bs(row.get("dividCashPsBeforeTax")),
                            "cash_after_tax": row.get("dividCashPsAfterTax", ""),
                            "description": row.get("dividCashStock", ""),
                        }
                        if d["cash_before_tax"] is not None:
                            dividends.append(d)
            except Exception as e:
                print(f"[baostock]  {year}年分红数据获取失败: {e}", file=sys.stderr)

        if dividends:
            bs_result["dividends"] = dividends
            # 计算最近一年分红率
            latest_div = dividends[0].get("cash_before_tax")
            if latest_div:
                bs_result["latest_dividend_per_share"] = latest_div
                # 从 info 获取股价算股息率
                price = data.get("info", {}).get("current_price")
                if price and price > 0:
                    bs_result["dividend_yield_pct"] = round(latest_div / price * 100, 2)

        # ── 2. 行业分类 ──
        try:
            rs = bs.query_stock_basic(code=bs_code)
            df = rs.get_data()
            if df is not None and not df.empty:
                row = df.iloc[0]
                bs_result["ipo_date"] = str(row.get("ipoDate", ""))
                bs_result["status"] = str(row.get("status", ""))
        except Exception as e:
            print(f"[baostock] 股票基本信息获取失败: {e}", file=sys.stderr)

        # ── 3. 行业归属 ──
        try:
            rs = bs.query_stock_industry()
            df = rs.get_data()
            if df is not None and not df.empty:
                match = df[df["code"] == bs_code]
                if not match.empty:
                    bs_result["industry"] = str(match.iloc[0].get("industryName", ""))
        except Exception as e:
            print(f"[baostock] 行业信息获取失败: {e}", file=sys.stderr)

        bs.logout()

        if bs_result:
            data["baostock"] = bs_result
            print(f"[baostock] ✅ 补充数据: {list(bs_result.keys())}")

    except ImportError:
        print("[baostock] ⚠️  baostock 未安装，跳过 (pip install baostock)")
    except Exception as e:
        print(f"[baostock] ⚠️  执行失败: {e}", file=sys.stderr)

    return data


def _safe_float_bs(v):
    """Baostock 返回的数值安全转换"""
    if v is None or v == "" or v == "-":
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


# ═══════════════════════════════════════════════════════
#  Tushare 补充数据（A股分红 + 前十大股东）
# ═══════════════════════════════════════════════════════
def enrich_with_tushare(data):
    """
    使用 Tushare Pro 补充 A 股数据。

    可用接口（120积分）：
    - dividend（分红明细，含除权除息）
    - top10_holders（前十大股东，含持股变动）
    
    返回补充后的 data 字典（新增 "tushare" key）
    仅在 Tushare 可用且结果为高质量时覆盖 Baostock 的同类数据。
    """
    ticker = data.get("ticker", "")
    is_a_share = ticker.endswith(".SS") or ticker.endswith(".SZ")
    if not is_a_share:
        return data

    try:
        import tushare as ts
    except ImportError:
        print("[tushare] ⚠️  tushare 未安装，跳过 (pip install tushare)")
        return data

    try:
        token = _read_api_key("tushare_token")
        if not token:
            print("[tushare] ⚠️  未找到 tushare_token，跳过")
            return data

        ts.set_token(token)
        pro = ts.pro_api()
        result = {}

        # A 股代码格式转换：002327.SZ → 002327.SZ（Tushare也接受）
        ts_code = ticker

        # ── 1. 分红数据（优先于 Baostock） ──
        try:
            df = pro.dividend(ts_code=ts_code, start_date="20210101", end_date="20261231")
            if df is not None and not df.empty:
                div_list = []
                for _, row in df.iterrows():
                    cash = row.get("cash_div_tax")
                    if cash is not None and cash != "":
                        cash = float(cash)
                    else:
                        continue
                    div_list.append({
                        "end_date": str(row.get("end_date", "")),
                        "ann_date": str(row.get("ann_date", "")),
                        "cash_div_tax": cash,
                        "stk_div": row.get("stk_div", 0),
                        "div_proc": str(row.get("div_proc", "")),
                    })
                if div_list:
                    result["dividends"] = div_list
                    # 最新一期分红
                    latest = div_list[0]
                    latest_cash = latest["cash_div_tax"]
                    result["latest_dividend_per_share"] = latest_cash
                    price = data.get("info", {}).get("current_price")
                    if price and price > 0:
                        result["dividend_yield_pct"] = round(latest_cash / price * 100, 2)
                    print(f"[tushare] ✅ 分红: {len(div_list)} 期, 最新¥{latest_cash:.2f}/股")
        except Exception as e:
            print(f"[tushare] ⚠️  分红获取失败: {e}", file=sys.stderr)

        # ── 2. 前十大股东（新增数据源） ──
        try:
            df = pro.top10_holders(ts_code=ts_code, start_date="20240101", end_date="20261231")
            if df is not None and not df.empty:
                holders = []
                for _, row in df.iterrows():
                    hold_amt = row.get("hold_amount", 0)
                    if hold_amt is not None and hold_amt != "":
                        hold_amt = float(hold_amt)
                    holders.append({
                        "ann_date": str(row.get("ann_date", "")),
                        "end_date": str(row.get("end_date", "")),
                        "holder_name": str(row.get("holder_name", "")),
                        "hold_amount": hold_amt,
                        "hold_ratio": row.get("hold_ratio"),
                    })
                if holders:
                    result["top10_holders"] = holders
                    print(f"[tushare] ✅ 前十大股东: {len(holders)} 条记录")
        except Exception as e:
            print(f"[tushare] ⚠️  前十大股东获取失败: {e}", file=sys.stderr)

        # ── 3. 写入数据 ──
        if result:
            data["tushare"] = result
            print(f"[tushare] ✅ 补充数据: {list(result.keys())}")
        else:
            print("[tushare] ℹ️  无有效数据返回")

    except Exception as e:
        print(f"[tushare] ⚠️  执行失败: {e}", file=sys.stderr)

    return data


# ═══════════════════════════════════════════════════════
#  Baostock 成分股 + K线工具
# ═══════════════════════════════════════════════════════
def get_index_constituents_bs(index="hs300"):
    """
    使用 Baostock 获取指数成分股
    
    返回 [(code_ss, name), ...] 其中 code_ss 是 sh.601398 格式
    """
    import baostock as bs
    lg = bs.login()
    
    func_map = {
        "hs300": bs.query_hs300_stocks,
        "sz50": bs.query_sz50_stocks,
        "zz500": bs.query_zz500_stocks,
    }
    
    query_func = func_map.get(index)
    if not query_func:
        print(f"[baostock] 未知指数: {index}")
        bs.logout()
        return []
    
    try:
        rs = query_func()
        df = rs.get_data()
        bs.logout()
        
        if df is None or df.empty:
            return []
        
        results = []
        for _, row in df.iterrows():
            code = str(row.get("code", ""))
            name = str(row.get("code_name", ""))
            # 转换成 yfinance 兼容的格式
            if code.startswith("sh."):
                yahoo_code = code.replace("sh.", "") + ".SS"
            elif code.startswith("sz."):
                yahoo_code = code.replace("sz.", "") + ".SZ"
            else:
                yahoo_code = code
            results.append((yahoo_code, name, code))
        
        print(f"[baostock] {index}: {len(results)} 只成分股")
        return results

    except Exception as e:
        print(f"[baostock] 获取 {index} 失败: {e}", file=sys.stderr)
        bs.logout()
        return []


# ═══════════════════════════════════════════════════════
#  SEC EDGAR 数据补充（美股定性信息）
# ═══════════════════════════════════════════════════════
def enrich_with_sec(data):
    """
    使用 SEC EDGAR 补充美股定性信息（仅对美股生效）
    
    补充内容：
    - 最新 10-K 的 Business Description（业务描述）
    - Risk Factors（风险因素）摘要
    - MD&A（管理层讨论与分析）
    - Executive Compensation（高管薪酬，含SBC详情）
    
    数据来源：SEC EDGAR (data.sec.gov) —— 免费、无需注册
    """
    ticker = data.get("ticker", "")
    # 仅对美股执行（不包含 .SS / .SZ / .HK）
    if any(ticker.endswith(s) for s in [".SS", ".SZ", ".HK"]):
        return data

    try:
        import urllib.request
        import json as jsonlib
        import re

        sec_data = {}
        headers = {
            "User-Agent": "Hermes Financial Research (your-email@example.com)",
            "Accept": "application/json",
        }

        # ── Step 1: 查找 CIK ──
        cik = _sec_lookup_cik(ticker, headers)
        if not cik:
            print(f"[sec-edgar] ⚠️  未找到 {ticker} 的 CIK 编号", file=sys.stderr)
            return data

        sec_data["cik"] = cik
        cik_padded = str(cik).zfill(10)

        # ── Step 2: 获取最近 10-K 提交信息 ──
        filing_info = _sec_get_filing_info(cik_padded, headers)
        if not filing_info:
            print(f"[sec-edgar] ⚠️  未找到 {ticker} 的近期 10-K", file=sys.stderr)
            data["sec_edgar"] = sec_data
            return data

        sec_data["latest_10k"] = filing_info

        # ── Step 3: 下载 10-K 文本并提取关键章节 ──
        sections = _sec_extract_sections(filing_info["filing_url"], headers)
        if sections:
            sec_data["sections"] = sections
            for s_name, s_text in sections.items():
                char_count = len(s_text) if s_text else 0
                print(f"[sec-edgar]   {s_name}: {char_count:,} 字符", file=sys.stderr)

        data["sec_edgar"] = sec_data
        print(f"[sec-edgar] ✅ {ticker} (CIK={cik}): 10-K({filing_info.get('period','')})")

    except ImportError:
        print("[sec-edgar] ⚠️  需要 Python 标准库 urllib")
    except Exception as e:
        print(f"[sec-edgar] ⚠️  执行失败: {e}", file=sys.stderr)

    return data


def _sec_lookup_cik(ticker, headers):
    """通过 ticker 查找 CIK 编号"""
    import urllib.request
    import json as jsonlib

    # 使用 SEC 官方 ticker→CIK 映射文件（最可靠）
    try:
        url = "https://www.sec.gov/files/company_tickers.json"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read().decode("utf-8")
            mapping = jsonlib.loads(raw)

        ticker_upper = ticker.upper()
        for key, entry in mapping.items():
            if entry.get("ticker", "").upper() == ticker_upper:
                return str(entry["cik_str"])

        return None
    except Exception:
        pass

    # 备用：通过 SEC EDGAR 全文搜索 API
    try:
        url = f"https://efts.sec.gov/LATEST/search-index?q={ticker}+AND+ticker&dateRange=all&counts=5"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            raw = resp.read().decode("utf-8")
            data = jsonlib.loads(raw)

        if data.get("hits", {}).get("total", {}).get("value", 0) > 0:
            hits = data["hits"]["hits"]
            for hit in hits:
                source = hit.get("_source", {})
                tickers_list = source.get("tickers", [])
                if ticker.upper() in [t.upper() for t in tickers_list]:
                    ciks = source.get("ciks", [])
                    if ciks:
                        return ciks[0]
        return None
    except Exception:
        return None


def _sec_get_filing_info(cik_padded, headers):
    """
    获取最近 10-K 提交信息
    返回 {period, accession, filing_url} 或 None
    """
    import urllib.request
    import json as jsonlib

    url = f"https://data.sec.gov/submissions/CIK{cik_padded}.json"
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read().decode("utf-8")
            data = jsonlib.loads(raw)

        filings = data.get("filings", {}).get("recent", {})
        if not filings:
            return None

        forms = filings.get("form", [])
        for i, form in enumerate(forms):
            if form in ("10-K", "10-K/A"):
                accession = filings["accessionNumber"][i]
                primary_doc = filings["primaryDocument"][i]
                period = filings.get("reportDate", [""])[i]

                filing_url = f"https://www.sec.gov/Archives/edgar/data/{cik_padded.lstrip('0')}/{accession.replace('-','')}/{primary_doc}"

                return {
                    "period": period,
                    "accession": accession,
                    "primary_document": primary_doc,
                    "filing_url": filing_url,
                    "form": form,
                }

        return None

    except Exception as e:
        print(f"[sec-edgar]  获取提交信息失败: {e}", file=sys.stderr)
        return None


def _sec_extract_sections(filing_url, headers):
    """
    下载 10-K HTML 并提取关键章节
    
    返回 dict:
    {
        "business_description": "...",
        "risk_factors": "...(最多2000字摘要)...",
        "md_and_a": "...(最多3000字摘要)...",
        "executive_compensation": "...(最多2000字摘要)..."
    }
    """
    import urllib.request
    import re

    try:
        req = urllib.request.Request(filing_url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            html = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"[sec-edgar]  下载 10-K 失败: {e}", file=sys.stderr)
        return None

    # 去除 HTML 标签
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"\s+", " ", text)
    text = text.replace("&nbsp;", " ").replace("&amp;", "&")

    sections = {}

    # ── 提取 Business (Item 1) ──
    sections["business_description"] = _sec_extract_section_text(
        text,
        [r"ITEM\s+1\.\s*BUSINESS", r"ITEM\s+1[.,]\s*BUSINESS"],
        [r"ITEM\s+1A\.", r"ITEM\s+1[.,]\s*RISK\s+FACTORS", r"ITEM\s+2\."],
        max_chars=100000,
    )

    # ── 提取 Risk Factors (Item 1A) ──
    sections["risk_factors"] = _sec_extract_section_text(
        text,
        [r"ITEM\s+1A\.\s*RISK\s+FACTORS", r"ITEM\s+1A[.,]\s*RISK"],
        [r"ITEM\s+1B\.", r"ITEM\s+2\."],
        max_chars=100000,
    )

    # ── 提取 MD&A (Item 7) ──
    sections["md_and_a"] = _sec_extract_section_text(
        text,
        [r"ITEM\s+7\.\s*MANAGEMENT", r"ITEM\s+7[.,]\s*MANAGEMENT"],
        [r"ITEM\s+7A\.", r"ITEM\s+8\."],
        max_chars=100000,
    )

    # ── 提取 Executive Compensation (Item 11) ──
    sections["executive_compensation"] = _sec_extract_section_text(
        text,
        [r"ITEM\s+11\.\s*EXECUTIVE", r"ITEM\s+11[.,]\s*EXECUTIVE"],
        [r"ITEM\s+12\."],
        max_chars=100000,
    )

    # 移除空章节
    return {k: v for k, v in sections.items() if v}


def _sec_extract_section_text(text, start_patterns, end_patterns, max_chars=3000):
    """从 10-K 文本中提取特定章节"""
    import re

    start_idx = None
    for pat in start_patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            start_idx = m.start()
            break

    if start_idx is None:
        return None

    end_idx = len(text)
    for pat in end_patterns:
        m = re.search(pat, text[start_idx + 200:], re.IGNORECASE)
        if m:
            end_idx = start_idx + 200 + m.start()
            break

    # 限制长度
    raw_text = text[start_idx:end_idx].strip()
    if len(raw_text) > max_chars:
        raw_text = raw_text[:max_chars] + "..."

    return raw_text


# ═══════════════════════════════════════════════════════
#  Finnhub 补充数据（美股 Earnings Call + 新闻）
# ═══════════════════════════════════════════════════════
def enrich_with_finnhub(data):
    """
    使用 Finnhub API 补充美股数据
    
    补充内容：
    - 最新 Earnings Call Transcript（管理层在电话会上的真实发言）
    - 近期公司新闻
    - 内部交易数据（管理层买卖股票信号）
    
    需要 finnhub-python 包 + config/api_keys.json 中的 API Key
    """
    ticker = data.get("ticker", "")
    if any(ticker.endswith(s) for s in [".SS", ".SZ", ".HK"]):
        return data

    # 读取 API Key
    api_key = _read_api_key("finnhub_api_key")
    if not api_key:
        print("[finnhub] ⚠️  未配置 API Key", file=sys.stderr)
        return data

    try:
        import finnhub

        fh_data = {}
        finnhub_client = finnhub.Client(api_key=api_key)

        # ── 1. 最新 Earnings Call Transcript ──
        try:
            # 查找最近一期财报的日期
            info = data.get("info", {})
            # 先从公司财报日历获取最新财报日期
            earnings = finnhub_client.earnings_calendar(
                _from="2025-01-01", to="2026-12-31", symbol=ticker
            )
            if earnings and earnings.get("earningsCalendar"):
                for e in earnings["earningsCalendar"]:
                    eps_actual = e.get("epsActual")
                    if eps_actual is not None:
                        report_date = e.get("date", "")
                        eps_est = e.get("epsEstimate", "N/A")
                        revenue_est = e.get("revenueEstimate", "N/A")
                        revenue_actual = e.get("revenueActual", "N/A")
                        fh_data["latest_earnings"] = {
                            "date": report_date,
                            "eps_actual": eps_actual,
                            "eps_estimate": eps_est,
                            "revenue_actual": revenue_actual,
                            "revenue_estimate": revenue_est,
                        }

                        # 基于财报日期获取 Transcript
                        try:
                            if report_date:
                                trans = finnhub_client.earnings_call_transcript(
                                    ticker, report_date
                                )
                                if trans and trans.get("transcript"):
                                    fh_data["earnings_transcript"] = trans["transcript"][:5000]
                        except Exception:
                            pass
                        break
        except Exception as e:
            print(f"[finnhub]  Earnings Call 获取失败: {e}", file=sys.stderr)

        # ── 2. 近期公司新闻（近30天，取前5条） ──
        try:
            from datetime import datetime, timedelta
            end_date = datetime.now().strftime("%Y-%m-%d")
            start_date = (datetime.now() - timedelta(days=90)).strftime("%Y-%m-%d")
            news = finnhub_client.company_news(ticker, _from=start_date, to=end_date)
            if news and len(news) > 0:
                fh_data["recent_news"] = [
                    {
                        "date": n.get("datetime", ""),
                        "headline": n.get("headline", ""),
                        "summary": n.get("summary", "")[:300],
                        "url": n.get("url", ""),
                        "source": n.get("source", ""),
                    }
                    for n in news[:5]
                ]
        except Exception as e:
            print(f"[finnhub]  新闻获取失败: {e}", file=sys.stderr)

        # ── 3. 内部交易（管理层买卖信号） ──
        try:
            insider = finnhub_client.stock_insider_transactions(ticker, "US")
            if insider and insider.get("data"):
                fh_data["insider_transactions"] = [
                    {
                        "name": t.get("name", ""),
                        "share": t.get("share", 0),
                        "change": t.get("change", 0),
                        "transaction_price": t.get("transactionPrice", 0),
                        "transaction_date": t.get("transactionDate", ""),
                    }
                    for t in insider["data"][:5]
                ]
        except Exception as e:
            print(f"[finnhub]  内部交易获取失败: {e}", file=sys.stderr)

        if fh_data:
            data["finnhub"] = fh_data
            print(f"[finnhub] ✅ {list(fh_data.keys())}")

    except ImportError:
        print("[finnhub] ⚠️  finnhub-python 未安装 (pip install finnhub-python)")
    except Exception as e:
        print(f"[finnhub] ⚠️  执行失败: {e}", file=sys.stderr)

    return data


def _read_api_key(key_name):
    """从配置文件读取 API Key"""
    import json
    import os

    config_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..", "config", "api_keys.json"
    )
    try:
        with open(config_path) as f:
            config = json.load(f)
        return config.get(key_name, "")
    except Exception:
        return ""


# ═══════════════════════════════════════════════════════
#  FRED 宏观经济数据补充（无风险利率、CPI等）
# ═══════════════════════════════════════════════════════
def enrich_with_fred(data):
    """
    使用 FRED（圣路易斯联储）API 补充宏观经济数据

    补充内容：
    - DGS10: 10年期国债收益率（用于 WACC 计算）
    - CPIAUCSL: CPI 通胀率
    - GDP: GDP 增长率
    - UNRATE: 失业率
    - FEDFUNDS: 联邦基金利率

    需要 fredapi 包 + config/api_keys.json 中的 FRED API Key
    """
    api_key = _read_api_key("fred_api_key")
    if not api_key:
        print("[fred] ⚠️  未配置 API Key", file=sys.stderr)
        return data

    try:
        from fredapi import Fred
        import json

        fred_data = {}
        fred = Fred(api_key=api_key)

        # 核心宏数据系列
        series = {
            "DGS10": "10y_treasury_yield_pct",       # 10年期国债收益率
            "FEDFUNDS": "fed_funds_rate_pct",         # 联邦基金利率
            "CPIAUCSL": "cpi_yoy_change_pct",         # CPI（需要算同比）
            "UNRATE": "unemployment_rate_pct",        # 失业率
            "GDP": "gdp_billions",                    # GDP（名义）
        }

        # 获取每个系列的最近值
        for fred_code, output_key in series.items():
            try:
                series_data = fred.get_series(fred_code)
                if series_data is not None and not series_data.empty:
                    latest = series_data.iloc[-1]
                    # CPI需要算同比变化
                    if fred_code == "CPIAUCSL":
                        if len(series_data) >= 13:
                            year_ago = series_data.iloc[-13]
                            latest_val = round((latest / year_ago - 1) * 100, 2)
                        else:
                            latest_val = round(float(latest), 2)
                    elif fred_code == "GDP":
                        latest_val = round(float(latest) / 1000, 1)  # 转为万亿美元
                    else:
                        latest_val = round(float(latest), 2)

                    fred_data[output_key] = latest_val
            except Exception as e:
                print(f"[fred]  {fred_code} 获取失败: {e}", file=sys.stderr)

        if fred_data:
            data["fred"] = fred_data
            print(f"[fred] ✅ {list(fred_data.keys())}")

    except ImportError:
        print("[fred] ⚠️  fredapi 未安装 (pip install fredapi)")
    except Exception as e:
        print(f"[fred] ⚠️  执行失败: {e}", file=sys.stderr)

    return data


# ═══════════════════════════════════════════════════════
#  CLI 入口
# ═══════════════════════════════════════════════════════
def main():
    import argparse
    parser = argparse.ArgumentParser(description="Fetch 5-year financial data for a ticker")
    parser.add_argument("--ticker", type=str, required=True,
                        help="Stock ticker symbol (e.g., AAPL, GOOGL)")
    parser.add_argument("--output", type=str, default=None,
                        help="Output JSON file path")
    parser.add_argument("--format", type=str, default="json",
                        choices=["json", "markdown"],
                        help="Output format (default: json)")
    parser.add_argument("--years", type=int, default=5,
                        help="Number of years of data (default: 5)")
    args = parser.parse_args()

    print(f"[fetch] 正在获取 {args.ticker} 的财务数据...")

    # ── 采集 ──
    data = extract_financials(args.ticker)

    # ── 派生指标 ──
    metrics = compute_derived_metrics(data)
    data["derived_metrics"] = metrics

    # ── 数据预警 ──
    warnings = metrics.get("_warnings", [])
    for w in warnings:
        print(f"[fetch] {w}", file=sys.stderr)

    # ── Baostock 补充（A股分红数据） ──
    data = enrich_with_baostock(data)

    # ── Tushare 补充（A股分红 + 前十大股东，优先于 Baostock） ──
    data = enrich_with_tushare(data)

    # ── SEC EDGAR 补充（美股10-K定性信息） ──
    data = enrich_with_sec(data)

    # ── Finnhub 补充（美股Earnings Call + 新闻） ──
    data = enrich_with_finnhub(data)

    # ── FRED 补充（宏观经济数据） ──
    data = enrich_with_fred(data)

    # ── 数据完整性报告 ──
    is_count = len(data.get("income_statement", []))
    bs_count = len(data.get("balance_sheet", []))
    cf_count = len(data.get("cash_flow", []))
    print(f"[fetch]   利润表: {is_count} 年 | 资产负债表: {bs_count} 年 | 现金流量表: {cf_count} 年")
    print(f"[fetch]   派生指标: {len(metrics)} 项")

    if is_count == 0 or bs_count == 0 or cf_count == 0:
        print(f"[fetch] ⚠️  部分报表为空，需要通过 web 搜索补充")

    # ── 输出 ──
    if args.format == "markdown":
        output = to_markdown(data)
    else:
        output = json.dumps(data, indent=2, default=str)

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"[fetch] ✅ 已写入 {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
