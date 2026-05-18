#!/usr/bin/env python3
"""
analyze_roic_wacc_spread.py — ROIC vs WACC Spread 分析器

格林沃尔德框架核心指标：ROIC - WACC 的差值决定了企业是否拥有护城河。

当 ROIC - WACC > 0 且持续 → 有护城河，增长创造价值
当 ROIC - WACC ≈ 0        → 无护城河，增长价值中性
当 ROIC - WACC < 0        → 在毁灭价值，增长越快越糟

用法：
  python3 scripts/analyze_roic_wacc_spread.py --ticker AAPL
  python3 scripts/analyze_roic_wacc_spread.py --ticker 605499.SS --peers "600519.SS,000858.SZ"
  python3 scripts/analyze_roic_wacc_spread.py --ticker CROX --peers "DECK,NKE" --format markdown
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

# FRED API Key 路径
API_KEYS_PATH = os.path.join(BASE_DIR, "..", "config", "api_keys.json")


def _read_api_key(key_name):
    """从配置文件读取 API Key"""
    try:
        with open(API_KEYS_PATH) as f:
            config = json.load(f)
        return config.get(key_name, "")
    except:
        return ""


# ═══════════════════════════════════════════════════════
#  1. WACC 计算
# ═══════════════════════════════════════════════════════

def calc_wacc(ticker, sector="", country="US"):
    """
    计算加权平均资本成本 WACC
    
    WACC = E/(D+E) × Re + D/(D+E) × Rd × (1-T)
    
    Re = Rf + Beta × ERP   (CAPM)
    Rd = Rf + 信用利差
    """
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info or {}
    bs = t.balance_sheet

    # ── 无风险利率 Rf ──
    rf = _get_risk_free_rate(country)
    
    # ── Beta ──
    beta = info.get("beta")
    if beta is None or beta == 0:
        # 行业默认Beta
        sector_betas = {
            "Technology": 1.20, "Financial Services": 1.05,
            "Consumer Defensive": 0.65, "Consumer Cyclical": 1.10,
            "Healthcare": 0.85, "Energy": 1.25,
            "Communication Services": 1.10, "Utilities": 0.55,
            "Basic Materials": 1.00, "Real Estate": 0.80,
            "Industrials": 1.05,
        }
        beta = sector_betas.get(sector, 1.0)
        beta_source = "行业默认值"
    else:
        beta_source = "yfinance"

    # ── 股权风险溢价 ERP ──
    erp = _get_erp(country)

    # ── 股权成本 Re ──
    re = rf + beta * erp / 100  # ERP以百分比计，需转换

    # ── 债务成本 Rd ──
    # 从利润表中获取利息支出和负债
    inc = t.income_stmt
    total_debt = 0
    interest_expense = 0

    if bs is not None and not bs.empty:
        years = sorted(bs.columns, reverse=True)
        total_debt = abs(float(bs.loc["Total Debt"].iloc[0])) if "Total Debt" in bs.index else 0

    if inc is not None and not inc.empty:
        years = sorted(inc.columns, reverse=True)
        if "Interest Expense" in inc.index:
            interest_expense = abs(float(inc.loc["Interest Expense"].iloc[0]))
    
    if total_debt > 0 and interest_expense > 0:
        rd = interest_expense / total_debt
        rd_source = "实际利率（利息支出/总负债）"
    else:
        rd = rf + 0.02  # 无负债或数据缺失：Rf + 2% 信用利差
        rd_source = "估算（Rf + 2% 信用利差）"

    # ── 税率 T ──
    if inc is not None and not inc.empty and "Tax Provision" in inc.index and "Income Before Tax" in inc.index:
        years = sorted(inc.columns, reverse=True)
        tax_prov = abs(float(inc.loc["Tax Provision"].iloc[0]))
        pretax = abs(float(inc.loc["Income Before Tax"].iloc[0]))
        tax_rate = tax_prov / pretax if pretax > 0 else 0.20
    else:
        tax_rate = 0.20
    tax_rate = min(tax_rate, 0.35)  # 封顶35%

    # ── 资本结构 ──
    equity_val = info.get("marketCap", 0)
    if equity_val is None:
        equity_val = 0

    debt_val = total_debt
    total_capital = equity_val + debt_val

    if total_capital > 0:
        w_e = equity_val / total_capital
        w_d = debt_val / total_capital
    else:
        w_e, w_d = 0.9, 0.1  # 默认90%股权

    # ── WACC ──
    wacc = w_e * re + w_d * rd * (1 - tax_rate)

    return {
        "rf_pct": round(rf * 100, 2),
        "rf_source": "FRED(DGS10)" if country == "US" else "FRED(CH_10Y)",
        "beta": round(beta, 3),
        "beta_source": beta_source,
        "erp_pct": erp,
        "erp_source": "Damodaran 2025" if country == "US" else "修正ERP",
        "re_pct": round(re * 100, 2),
        "rd_pct": round(rd * 100, 2),
        "rd_source": rd_source,
        "tax_rate_pct": round(tax_rate * 100, 1),
        "equity_weight_pct": round(w_e * 100, 1),
        "debt_weight_pct": round(w_d * 100, 1),
        "wacc_pct": round(wacc * 100, 2),
    }


def _get_risk_free_rate(country="US"):
    """通过FRED获取无风险利率"""
    api_key = _read_api_key("fred_api_key")
    if api_key:
        try:
            from fredapi import Fred
            fred = Fred(api_key=api_key)
            series = "DGS10" if country == "US" else "CH_10Y"
            data = fred.get_series(series)
            if data is not None and not data.empty:
                return float(data.iloc[-1]) / 100
        except:
            pass
    # 回退
    return 0.0436 if country == "US" else 0.020


def _get_erp(country="US"):
    """获取股权风险溢价"""
    # 基于 Damodaran 2025 数据
    if country == "US":
        return 4.5  # 成熟市场
    elif country == "China":
        return 6.5  # 新兴市场溢价
    else:
        return 5.5


# ═══════════════════════════════════════════════════════
#  2. ROIC 计算
# ═══════════════════════════════════════════════════════

def calc_roic(ticker):
    """
    计算 ROIC（投入资本回报率）
    
    ROIC = NOPAT / Invested Capital
    NOPAT = EBIT × (1 - Tax Rate)
    Invested Capital = Total Debt + Total Equity - Cash
    """
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info or {}
    inc = t.income_stmt
    bs = t.balance_sheet
    cf = t.cashflow

    results = {}

    # ── 获取多年的数据 ──
    if inc is not None and not inc.empty:
        years = sorted(inc.columns, reverse=True)[:5]
    else:
        return {"error": "无法获取利润表数据"}

    yearly_data = []
    for year in years:
        year_str = str(year)[:10] if hasattr(year, 'strftime') else str(year)[:4]
        
        try:
            # EBIT
            ebit = float(inc.loc["EBIT", year]) if "EBIT" in inc.index else 0
            
            # 税率
            tax_prov = float(inc.loc["Tax Provision", year]) if "Tax Provision" in inc.index else 0
            pretax = float(inc.loc["Income Before Tax", year]) if "Income Before Tax" in inc.index else 0
            tax_rate = tax_prov / pretax if pretax > 0 else 0.20
            tax_rate = min(max(tax_rate, 0), 0.35)

            # NOPAT
            nopat = ebit * (1 - tax_rate)
            
            # 投入资本（需要资产负债表）
            if bs is not None and not bs.empty and year in bs.columns:
                debt = float(bs.loc["Total Debt", year]) if "Total Debt" in bs.index else 0
                equity = float(bs.loc["Stockholders Equity", year]) if "Stockholders Equity" in bs.index else 0
                cash = float(bs.loc["Cash And Cash Equivalents", year]) if "Cash And Cash Equivalents" in bs.index else 0
            else:
                debt, equity, cash = 0, 0, 0

            invested_capital = debt + equity - cash
            roic = nopat / invested_capital if invested_capital > 0 else 0

            # 营收
            revenue = float(inc.loc["Total Revenue", year]) if "Total Revenue" in inc.index else 0
            
            # 毛利率
            gross = float(inc.loc["Gross Profit", year]) if "Gross Profit" in inc.index else 0
            gross_margin = round(gross / revenue * 100, 1) if revenue else 0

            yearly_data.append({
                "year": year_str,
                "revenue": revenue,
                "ebit": ebit,
                "nopat": round(nopat, 2),
                "invested_capital": round(invested_capital, 2),
                "roic_pct": round(roic * 100, 2),
                "gross_margin_pct": gross_margin,
            })
        except Exception as e:
            continue

    if not yearly_data:
        return {"error": "数据解析失败"}

    # ── 加入维护性CapEx调整 ──
    # 从现金流量表获取 CapEx 和 D&A
    if cf is not None and not cf.empty:
        cf_years = sorted(cf.columns, reverse=True)[:5]
        for yd in yearly_data:
            for cy in cf_years:
                cy_str = str(cy)[:10] if hasattr(cy, 'strftime') else str(cy)[:4]
                if cy_str == yd["year"]:
                    capex = abs(float(cf.loc["Capital Expenditure", cy])) if "Capital Expenditure" in cf.index else 0
                    da = float(cf.loc["Depreciation And Amortization", cy]) if "Depreciation And Amortization" in cf.index else 0
                    yd["total_capex"] = round(capex, 2)
                    yd["depreciation"] = round(da, 2)
                    yd["maintenance_capex"] = round(min(da, capex), 2)  # 不超总CapEx
                    yd["growth_capex"] = round(capex - yd["maintenance_capex"], 2)
                    break

    results["yearly"] = yearly_data
    results["latest"] = yearly_data[0] if yearly_data else {}
    results["avg_roic_3y_pct"] = round(
        sum(y["roic_pct"] for y in yearly_data[:3]) / len(yearly_data[:3]), 2
    ) if len(yearly_data) >= 3 else results["latest"].get("roic_pct", 0)

    # ── ROIC 质量判断 ──
    latest_roic = results["latest"].get("roic_pct", 0)
    avg_3y = results["avg_roic_3y_pct"]
    trend = [y["roic_pct"] for y in yearly_data[:3]]
    
    if latest_roic > 20:
        results["quality"] = "优秀"
        results["quality_detail"] = f"ROIC={latest_roic}%，远高于资本成本。企业拥有强大的护城河，增长将显著创造价值。"
    elif latest_roic > 10:
        results["quality"] = "良好"
        results["quality_detail"] = f"ROIC={latest_roic}%，适度高于资本成本。有一定的竞争优势，但护城河不深。"
    elif latest_roic > 5:
        results["quality"] = "平庸"
        results["quality_detail"] = f"ROIC={latest_roic}%，接近资本成本。没有明显护城河，增长不创造价值。"
    else:
        results["quality"] = "危险"
        results["quality_detail"] = f"ROIC={latest_roic}%，低于资本成本。企业在毁灭价值，增长越快越糟。"
    
    # 趋势判断
    if len(trend) >= 3:
        if trend[0] > trend[-1]:
            results["trend"] = "改善中"
        elif trend[0] < trend[-1]:
            results["trend"] = "恶化中"
        else:
            results["trend"] = "稳定"

    return results


# ═══════════════════════════════════════════════════════
#  3. Spread 分析与同业对比
# ═══════════════════════════════════════════════════════

def calc_spread(ticker, peer_list=None):
    """
    计算 ROIC - WACC Spread
    
    返回完整分析结果，含同业对比
    """
    import yfinance as yf
    
    t = yf.Ticker(ticker)
    info = t.info or {}
    sector = info.get("sector", "")
    country = "US" if info.get("country", "") == "United States" else "China" if info.get("country", "") == "China" else "US"
    
    result = {
        "ticker": ticker.upper(),
        "company_name": info.get("longName") or info.get("shortName", ""),
        "sector": sector,
        "industry": info.get("industry", ""),
        "country": info.get("country", ""),
        "current_price": info.get("currentPrice"),
        "market_cap": info.get("marketCap"),
    }

    # ── WACC ──
    print(f"[spread] 计算 WACC...", file=sys.stderr)
    wacc_data = calc_wacc(ticker, sector, country)
    result["wacc"] = wacc_data
    
    # ── ROIC ──
    print(f"[spread] 计算 ROIC...", file=sys.stderr)
    roic_data = calc_roic(ticker)
    result["roic"] = roic_data
    
    if "error" in roic_data:
        result["error"] = roic_data["error"]
        return result

    # ── Spread ──
    latest_roic = roic_data["latest"].get("roic_pct", 0)
    wacc = wacc_data["wacc_pct"]
    result["spread"] = {
        "roic_pct": latest_roic,
        "wacc_pct": wacc,
        "spread_pct": round(latest_roic - wacc, 2),
        "spread_assessment": _assess_spread(latest_roic - wacc),
    }

    # ── 同业对比 ──
    if peer_list:
        print(f"[spread] 同业对比: {peer_list}", file=sys.stderr)
        peers = []
        for p in peer_list:
            p = p.strip()
            if not p:
                continue
            try:
                peer_roic = calc_roic(p)
                peer_wacc = calc_wacc(p, sector, country)
                peer_info = yf.Ticker(p).info or {}
                peers.append({
                    "ticker": p.upper(),
                    "name": peer_info.get("shortName", p),
                    "roic_pct": peer_roic.get("latest", {}).get("roic_pct"),
                    "wacc_pct": peer_wacc.get("wacc_pct"),
                    "spread_pct": round(
                        (peer_roic.get("latest", {}).get("roic_pct", 0) or 0)
                        - peer_wacc.get("wacc_pct", 0), 2
                    ) if peer_roic.get("latest", {}).get("roic_pct") else None,
                    "mkt_cap": peer_info.get("marketCap"),
                })
            except Exception as e:
                print(f"[spread]  ⚠️ {p} 获取失败: {e}", file=sys.stderr)
        result["peers"] = peers
        
        # 排名
        all_spreads = [result["spread"]] + [{"ticker": p["ticker"], "spread_pct": p["spread_pct"]} for p in peers if p["spread_pct"] is not None]
        all_spreads_sorted = sorted(all_spreads, key=lambda x: x.get("spread_pct", -999), reverse=True)
        result["spread_ranking"] = [
            {"rank": i+1, "ticker": s.get("ticker", ticker.upper()), "spread_pct": s.get("spread_pct")}
            for i, s in enumerate(all_spreads_sorted)
        ]

    # ── 综合判断 ──
    result["verdict"] = _generate_verdict(result)

    return result


def _assess_spread(spread):
    """评估 spread 大小"""
    if spread > 20:
        return "极宽护城河 ✅✅ — ROIC远超资金成本"
    elif spread > 10:
        return "宽护城河 ✅ — 明确的竞争优势"
    elif spread > 5:
        return "中等护城河 ⚡ — 有优势但非不可逾越"
    elif spread > 0:
        return "弱护城河 ⚠️ — 勉强覆盖成本"
    elif spread > -5:
        return "无护城河 ❌ — 低于资本成本"
    else:
        return "毁灭价值 🔴 — 增长越快越糟"


def _generate_verdict(result):
    """生成综合判断"""
    spread = result.get("spread", {})
    roic_data = result.get("roic", {})
    wacc = result.get("wacc", {})
    
    roic = spread.get("roic_pct", 0)
    wacc_val = spread.get("wacc_pct", 0)
    sp = spread.get("spread_pct", 0)
    trend = roic_data.get("trend", "N/A")
    quality = roic_data.get("quality", "N/A")
    
    # 核心判断
    if sp > 10:
        action = "增长创造价值。企业有明确的护城河，应以 EPV + FV 为主进行估值。"
    elif sp > 0:
        action = "增长价值中性。企业有微弱优势，应以 EPV 为主估值，慎用 FV。"
    else:
        action = "增长毁灭价值。企业无护城河，应以 ARV 为主估值，仅考虑清算价值。"
    
    beta_info = f"Beta={wacc.get('beta', 'N/A')} | Rf={wacc.get('rf_pct', 'N/A')}%"
    
    return {
        "roic_wacc_spread_pct": sp,
        "trend": trend,
        "quality": quality,
        "action": action,
        "summary": f"ROIC={roic}% - WACC={wacc_val}% = {sp:+}% | {_assess_spread(sp)} | {trend}趋势 | {beta_info}",
    }


# ═══════════════════════════════════════════════════════
#  输出
# ═══════════════════════════════════════════════════════

def to_markdown(result):
    lines = []
    
    if "error" in result:
        return f"# ❌ ROIC/WACC Spread 分析失败\n\n{result['error']}"
    
    r = result
    sp = r.get("spread", {})
    ver = r.get("verdict", {})
    wacc = r.get("wacc", {})
    roic = r.get("roic", {})
    
    lines.append(f"# ROIC vs WACC Spread 分析 — {r['ticker']}")
    lines.append(f"")
    lines.append(f"**{r.get('company_name','')}** | {r.get('sector','')} | {r.get('industry','')}")
    lines.append(f"**当前股价：** {r.get('current_price','N/A')} | **市值：** {r.get('market_cap','N/A')}")
    lines.append(f"")
    lines.append(f"## 核心结论")
    lines.append(f"")
    lines.append(f"**{ver.get('summary','')}**")
    lines.append(f"")
    lines.append(f"> {ver.get('action','')}")
    lines.append(f"")
    
    # ── ROIC 趋势 ──
    lines.append(f"## ROIC 趋势（近5年）")
    lines.append(f"")
    lines.append(f"| 年份 | 营收 | EBIT | NOPAT | 投入资本 | ROIC | 毛利率 |")
    lines.append(f"|------|------|------|-------|---------|------|-------|")
    
    def _fmt_currency(v):
        if v is None or v == 0:
            return "-"
        if abs(v) >= 1e9:
            return f"${v/1e9:.1f}B"
        elif abs(v) >= 1e6:
            return f"${v/1e6:.1f}M"
        else:
            return f"${v:,.0f}"
    
    yd = r.get("roic", {}).get("yearly", [])
    for y in yd:
        lines.append(
            f"| {y.get('year','')} | {_fmt_currency(y.get('revenue'))} "
            f"| {_fmt_currency(y.get('ebit'))} | {_fmt_currency(y.get('nopat'))} "
            f"| {_fmt_currency(y.get('invested_capital'))} "
            f"| {y.get('roic_pct','')}% | {y.get('gross_margin_pct','')}% |"
        )
    
    avg_roic = roic.get("avg_roic_3y_pct", "")
    lines.append(f"| **3年平均** | | | | | **{avg_roic}%** | |")
    lines.append(f"")
    lines.append(f"**趋势：** {roic.get('trend','N/A')} | **质量：** {roic.get('quality','N/A')}")
    if yd:
        latest = yd[0]
        mc = latest.get("maintenance_capex")
        gc = latest.get("growth_capex")
        if mc is not None:
            lines.append(f"**最新年资本开支拆分：** 总CapEx={_fmt_currency(latest.get('total_capex'))} | 维护性={_fmt_currency(mc)} | 增长性={_fmt_currency(gc) if gc else '$0'}")
    lines.append(f"")
    
    # ── WACC 明细 ──
    lines.append(f"## WACC 计算明细")
    lines.append(f"")
    lines.append(f"| 参数 | 数值 | 来源 |")
    lines.append(f"|------|------|------|")
    lines.append(f"| 无风险利率 Rf | {wacc.get('rf_pct','')}% | {wacc.get('rf_source','')} |")
    lines.append(f"| Beta | {wacc.get('beta','')} | {wacc.get('beta_source','')} |")
    lines.append(f"| 股权风险溢价 ERP | {wacc.get('erp_pct','')}% | {wacc.get('erp_source','')} |")
    lines.append(f"| **股权成本 Re** | **{wacc.get('re_pct','')}%** | CAPM |")
    lines.append(f"| 债务成本 Rd | {wacc.get('rd_pct','')}% | {wacc.get('rd_source','')} |")
    lines.append(f"| 税率 | {wacc.get('tax_rate_pct','')}% | 利润表 |")
    lines.append(f"| 股权权重 | {wacc.get('equity_weight_pct','')}% | |")
    lines.append(f"| 债务权重 | {wacc.get('debt_weight_pct','')}% | |")
    lines.append(f"| **WACC** | **{wacc.get('wacc_pct','')}%** | |")
    lines.append(f"")

    # ── Spread 对决 ──
    lines.append(f"## ROIC vs WACC 对决")
    lines.append(f"")
    sp_val = sp.get("spread_pct", 0)
    bar_len = 40
    roic_bar = int((sp.get("roic_pct", 0) / 50) * bar_len) if sp.get("roic_pct", 0) < 50 else bar_len
    wacc_bar = int((sp.get("wacc_pct", 0) / 50) * bar_len) if sp.get("wacc_pct", 0) < 50 else bar_len
    
    lines.append(f"```")
    lines.append(f"ROIC [{'█' * roic_bar}{'░' * (bar_len - roic_bar)}] {sp.get('roic_pct', 0)}%")
    lines.append(f"WACC [{'█' * wacc_bar}{'░' * (bar_len - wacc_bar)}] {sp.get('wacc_pct', 0)}%")
    lines.append(f"     {'─' * bar_len}")
    gap = "+" if sp_val > 0 else ""
    lines.append(f"Spread {gap}{sp_val}%")
    lines.append(f"```")
    lines.append(f"")
    lines.append(f"**{_assess_spread(sp_val)}**")
    lines.append(f"")

    # ── 同业对比 ──
    peers = r.get("peers", [])
    if peers:
        lines.append(f"## 同业对比")
        lines.append(f"")
        lines.append(f"| 公司 | ROIC | WACC | Spread | 市值 |")
        lines.append(f"|------|------|------|-------|------|")
        
        # 目标公司的行
        lines.append(f"| **{r['ticker']} (目标)** | **{sp.get('roic_pct','N/A')}%** | **{sp.get('wacc_pct','N/A')}%** | **{sp.get('spread_pct','N/A')}%** | {_fmt_currency(r.get('market_cap'))} |")
        
        for p in peers:
            lines.append(f"| {p.get('ticker','')} | {p.get('roic_pct','N/A')}% | {p.get('wacc_pct','N/A')}% | {p.get('spread_pct','N/A')}% | {_fmt_currency(p.get('mkt_cap'))} |")
        lines.append(f"")
        
        # 排名
        ranking = r.get("spread_ranking", [])
        if ranking:
            lines.append(f"### Spread 排名")
            lines.append(f"")
            for rank in ranking:
                marker = " ← 目标" if rank.get("ticker") == r['ticker'] else ""
                sp_r = rank.get("spread_pct", 0)
                sp_s = f"+{sp_r}" if sp_r and sp_r > 0 else str(sp_r) if sp_r else "N/A"
                lines.append(f"{rank['rank']}. **{rank['ticker']}**: {sp_s}%{marker}")
            lines.append(f"")

    # ── 在格林沃尔德框架中的含义 ──
    lines.append(f"## 在格林沃尔德框架中的含义")
    lines.append(f"")
    lines.append(f"| Spread 范围 | 护城河 | 适用的估值方法 |")
    lines.append(f"|-----------|--------|--------------|")
    lines.append(f"| > 10% | ✅ 明确护城河 | EPV + FV（增长创造价值） |")
    lines.append(f"| 0% ~ 10% | ⚠️ 弱护城河 | EPV 为主（增长中性） |")
    lines.append(f"| < 0% | ❌ 无护城河 | ARV 为主（增长毁灭价值） |")
    lines.append(f"")
    
    # 建议
    sp_note = ""
    if sp_val > 10:
        sp_note = "明确护城河企业。在估值中应计入 FV（增长溢价）。EPV中的再投资率(b)应使用增长性CapEx而非总CapEx。"
    elif sp_val > 0:
        sp_note = "弱护城河企业。估值应以 EPV 为主，FV 应取保守值。"
    else:
        sp_note = "无护城河企业。估值应以 ARV 为主，不应计入任何增长溢价。"
    lines.append(f"**当前 {r['ticker']} Spread = {sp_val:+}%** → {sp_note}")
    
    return "\n".join(lines)


# ═══════════════════════════════════════════════════════
#  CLI
# ═══════════════════════════════════════════════════════

def main():
    import argparse
    parser = argparse.ArgumentParser(description="ROIC vs WACC Spread 分析器")
    parser.add_argument("--ticker", type=str, required=True, help="目标股票代码")
    parser.add_argument("--peers", type=str, default="", help="同业对比，逗号分隔")
    parser.add_argument("--output", type=str, default=None, help="输出路径")
    parser.add_argument("--format", type=str, default="json", choices=["json", "markdown"])
    args = parser.parse_args()

    peer_list = [p.strip() for p in args.peers.split(",") if p.strip()] if args.peers else None
    
    result = calc_spread(args.ticker, peer_list)
    
    if args.format == "markdown":
        output = to_markdown(result)
    else:
        output = json.dumps(result, indent=2, default=str)
    
    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"[spread] ✅ 已写入 {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
