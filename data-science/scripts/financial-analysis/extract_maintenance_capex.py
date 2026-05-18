#!/usr/bin/env python3
"""
extract_maintenance_capex.py — 维护性资本开支提取器

从 SEC 10-K 中提取/估算 Maintenance CapEx（维护性资本开支）。
这是计算真实自由现金流和格林沃尔德EPV的关键输入。

核心理念：
  Total CapEx = Maintenance CapEx（维持现有产能） + Growth CapEx（扩张新产能）
  
  在10-K中，部分公司会在MD&A中披露维护vs增长的拆分。
  如果未披露，使用 Depreciation & Amortization 作为 Maintenance CapEx 的代理变量。

用法：
  python3 scripts/extract_maintenance_capex.py --ticker AAPL
  python3 scripts/extract_maintenance_capex.py --ticker CROX --format markdown
  python3 scripts/extract_maintenance_capex.py --ticker MSFT --output /tmp/mc.json

输出：
  - maintenance_capex: 维护性资本开支（估算值）
  - growth_capex: 增长性资本开支（total - maintenance）
  - disclosure_method: 如何获取的（SEC披露 / D&A代理 / yfinance推算）
"""

import json
import os
import sys
import re
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data")
os.makedirs(DATA_DIR, exist_ok=True)


# ═══════════════════════════════════════════════════════
#  SEC EDGAR 工具函数（复用自 fetch_financials.py 的逻辑）
# ═══════════════════════════════════════════════════════

SEC_HEADERS = {
    "User-Agent": "Hermes Financial Research (research@example.com)",
    "Accept": "application/json",
}

def _lookup_cik(ticker):
    """通过 ticker→CIK 映射文件查找"""
    import urllib.request
    import json as jsonlib
    try:
        url = "https://www.sec.gov/files/company_tickers.json"
        req = urllib.request.Request(url, headers=SEC_HEADERS)
        with urllib.request.urlopen(req, timeout=15) as resp:
            mapping = jsonlib.loads(resp.read().decode("utf-8"))
        for entry in mapping.values():
            if entry.get("ticker", "").upper() == ticker.upper():
                return str(entry["cik_str"])
    except:
        pass
    return None


def _get_latest_10k(cik_padded):
    """获取最新 10-K 的归档信息"""
    import urllib.request
    import json as jsonlib
    url = f"https://data.sec.gov/submissions/CIK{cik_padded}.json"
    try:
        req = urllib.request.Request(url, headers=SEC_HEADERS)
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = jsonlib.loads(resp.read().decode("utf-8"))
        filings = data.get("filings", {}).get("recent", {})
        forms = filings.get("form", [])
        for i, form in enumerate(forms):
            if form in ("10-K", "10-K/A"):
                acc = filings["accessionNumber"][i]
                doc = filings["primaryDocument"][i]
                period = filings.get("reportDate", [""])[i]
                filing_url = (
                    f"https://www.sec.gov/Archives/edgar/data/"
                    f"{cik_padded.lstrip('0')}/{acc.replace('-','')}/{doc}"
                )
                return {"period": period, "url": filing_url, "accession": acc}
    except:
        pass
    return None


def _download_10k_text(url):
    """下载10-K并提取纯文本"""
    import urllib.request
    try:
        req = urllib.request.Request(url, headers=SEC_HEADERS)
        with urllib.request.urlopen(req, timeout=30) as resp:
            html = resp.read().decode("utf-8", errors="replace")
        # 去HTML标签
        text = re.sub(r"<[^>]+>", " ", html)
        text = re.sub(r"\s+", " ", text)
        text = text.replace("&nbsp;", " ").replace("&amp;", "&").replace("&#160;", " ")
        return text
    except Exception as e:
        print(f"[mc]  下载失败: {e}", file=sys.stderr)
        return None


# ═══════════════════════════════════════════════════════
#  维护性 CapEx 提取逻辑
# ═══════════════════════════════════════════════════════

def extract_maintenance_capex_from_10k(ticker):
    """
    主函数：从10-K中提取维护性CapEx
    
    返回 dict:
    {
        "ticker": "AAPL",
        "method": "sec_disclosure" | "da_proxy" | "yfinance_estimate",
        "ten_k_period": "2024-09-28",
        "total_capex": {2024: -, 2023: -, ...},
        "depreciation": {2024: -, 2023: -, ...},
        "maintenance_capex": {2024: -, 2023: -, ...},
        "growth_capex": {2024: -, 2023: -, ...},
        "maintenance_pct": 0.85,    # 维护性占总额比例
        "disclosure_text": "...",    # 10-K 原文中提及维护性CapEx的部分
        "analysis": "...",           # 分析结论
    }
    """
    result = {
        "ticker": ticker.upper(),
        "fetch_time": datetime.now().isoformat(),
    }
    
    # ── Step 1: CIK 查找 ──
    print(f"[mc] 查找 {ticker} 的CIK...", file=sys.stderr)
    cik = _lookup_cik(ticker)
    if not cik:
        print(f"[mc] ❌ 未找到 CIK", file=sys.stderr)
        return _fallback_yfinance(ticker, result)
    result["cik"] = cik
    cik_padded = cik.zfill(10)
    
    # ── Step 2: 获取最新10-K ──
    print(f"[mc] 获取最新10-K (CIK={cik})...", file=sys.stderr)
    filing = _get_latest_10k(cik_padded)
    if not filing:
        print(f"[mc] ⚠️  未找到10-K，回退yfinance", file=sys.stderr)
        return _fallback_yfinance(ticker, result)
    
    result["ten_k_period"] = filing["period"]
    result["ten_k_url"] = filing["url"]
    
    # ── Step 3: 下载10-K文本 ──
    print(f"[mc] 下载10-K ({filing['period']})...", file=sys.stderr)
    text = _download_10k_text(filing["url"])
    if not text:
        return _fallback_yfinance(ticker, result)
    
    # ── Step 4: 搜索维护性CapEx披露 ──
    print(f"[mc] 搜索维护性CapEx披露...", file=sys.stderr)
    
    # 搜索关键词模式
    patterns = [
        r"maintenance\s+capital\s+(expenditures|expenses|spending)",
        r"capital\s+(expenditures|spending)\s+.*?maintenance",
        r"sustaining\s+capital\s+(expenditures|expenses)",
        r"maintenance\s+capex",
        r"capex\s+.*?maintenance",
        r"growth\s+capital\s+(expenditures|expenses|spending)",
        r"capital\s+(expenditures|spending)\s+.*?growth",
    ]
    
    disclosure_text = None
    for pat in patterns:
        matches = re.finditer(pat, text, re.IGNORECASE)
        for m in matches:
            start = max(0, m.start() - 200)
            end = min(len(text), m.end() + 800)
            snippet = text[start:end]
            # 尝试提取数字
            numbers = re.findall(r'[\$]?([0-9,]+(?:\.[0-9]+)?)\s*(million|billion|M|B)?', snippet)
            if numbers:
                disclosure_text = snippet.strip()
                result["disclosure_text"] = disclosure_text[:2000]
                break
        if disclosure_text:
            break
    
    if disclosure_text:
        print(f"[mc] ✅ 在10-K中发现维护性CapEx披露", file=sys.stderr)
        result["method"] = "sec_disclosure"
        # 从披露文本中提取数字（简化处理）
        result["disclosure_summary"] = _parse_disclosure_numbers(disclosure_text)
    else:
        print(f"[mc] ⚠️  10-K中未明确披露，使用D&A代理法", file=sys.stderr)
        result["method"] = "da_proxy"
    
    # ── Step 5: 从 yfinance 获取总 CapEx 和 D&A ──
    _add_yfinance_capex_data(ticker, result)
    
    # ── Step 6: 计算维护性/增长性拆分 ──
    _compute_split(result)
    
    return result


def _parse_disclosure_numbers(text):
    """尝试从披露文本中解析维护性CapEx的具体数字"""
    summary = {}
    # 寻找"maintenance capex of $X million"模式
    patterns = [
        (r"(?:maintenance|sustaining)\s+capex\s+(?:of|was|is|were|totaled|approximately)\s*\$?([0-9,]+(?:\.[0-9]+)?)\s*(million|billion|M|B)?", "maintenance_capex_text"),
        (r"(?:growth|expansion)\s+capex\s+(?:of|was|is|were|totaled|approximately)\s*\$?([0-9,]+(?:\.[0-9]+)?)\s*(million|billion|M|B)?", "growth_capex_text"),
    ]
    for pat, key in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            num = float(m.group(1).replace(",", ""))
            unit = (m.group(2) or "").lower()
            if unit in ("billion", "b"):
                num *= 1000
            summary[key] = num
    return summary


def _add_yfinance_capex_data(ticker, result):
    """从 yfinance 获取 CapEx 和 D&A 数据"""
    import yfinance as yf
    try:
        t = yf.Ticker(ticker)
        cf = t.cashflow
        if cf is None or cf.empty:
            return
        
        years = sorted(cf.columns, reverse=True)[:5]
        capex_data = {}
        da_data = {}
        
        for y in years:
            year_str = str(y)[:10] if hasattr(y, 'strftime') else str(y)[:4]
            
            if "Capital Expenditure" in cf.index:
                val = cf.loc["Capital Expenditure", y]
                if val is not None and val == val:
                    capex_data[year_str] = abs(float(val))
            
            if "Depreciation And Amortization" in cf.index:
                val = cf.loc["Depreciation And Amortization", y]
                if val is not None and val == val:
                    da_data[year_str] = float(val)
        
        result["total_capex"] = capex_data
        result["depreciation"] = da_data
        
    except Exception as e:
        print(f"[mc]  yfinance数据获取失败: {e}", file=sys.stderr)


def _compute_split(result):
    """计算维护性/增长性CapEx拆分"""
    total = result.get("total_capex", {})
    da = result.get("depreciation", {})
    
    mc = {}
    gc = {}
    
    for year in total:
        t = total[year]
        d = da.get(year)
        
        if result.get("method") == "sec_disclosure":
            # 如果有SEC披露的数字，优先使用
            disclosed = result.get("disclosure_summary", {})
            if "maintenance_capex_text" in disclosed:
                mc[year] = disclosed["maintenance_capex_text"]
                gc[year] = t - mc[year]
                continue

        # D&A 代理法（标准做法）
        if d and d > 0:
            mc[year] = min(d, t)  # 维护性不能超过总CapEx
            gc[year] = t - mc[year]
        else:
            mc[year] = t * 0.7  # 完全无数据时，假设70%为维护性
            gc[year] = t * 0.3
    
    result["maintenance_capex"] = {k: round(v, 2) for k, v in mc.items()}
    result["growth_capex"] = {k: round(v, 2) for k, v in gc.items()}
    
    # 计算维护性占比
    latest_total = list(total.values())[0] if total else 0
    latest_mc = list(mc.values())[0] if mc else 0
    result["maintenance_pct"] = round(latest_mc / latest_total, 4) if latest_total else 0.7
    
    # 分析结论
    _generate_analysis(result)


def _generate_analysis(result):
    """生成分析结论"""
    method = result.get("method", "da_proxy")
    pct = result.get("maintenance_pct", 0.7)
    
    analyses = {
        "sec_disclosure": f"公司在10-K中直接披露了维护性/增长性CapEx的拆分。维护性CapEx占总CapEx的{pct*100:.0f}%。",
        "da_proxy": f"公司未在10-K中直接披露维护性/增长性拆分。使用D&A作为维护性CapEx的代理变量：维护性CapEx = D&A = 总CapEx的{pct*100:.0f}%。这种方法假设D&A近似反映了维持当前产能所需的资本支出。",
        "yfinance_estimate": f"仅使用yfinance数据。由于无10-K和详细D&A数据，假设总CapEx的70%为维护性支出。",
    }
    
    result["analysis"] = analyses.get(method, analyses["yfinance_estimate"])
    
    # 维护性 vs 增长性趋势
    mc = result.get("maintenance_capex", {})
    gc = result.get("growth_capex", {})
    total = result.get("total_capex", {})
    
    trends = []
    for year in sorted(mc.keys(), reverse=True)[:3]:
        t = total.get(year, 0)
        m = mc.get(year, 0)
        g = gc.get(year, 0)
        m_pct = round(m/t*100, 1) if t else 0
        g_pct = round(g/t*100, 1) if t else 0
        trends.append(f"{year}: 总CapEx={_fmt_num(t)}, 维护性={_fmt_num(m)}({m_pct}%), 增长性={_fmt_num(g)}({g_pct}%)")
    
    result["trend_summary"] = trends


def _fallback_yfinance(ticker, result):
    """完全回退到yfinance"""
    print(f"[mc] 回退：仅使用 yfinance 数据", file=sys.stderr)
    result["method"] = "yfinance_estimate"
    _add_yfinance_capex_data(ticker, result)
    _compute_split(result)
    return result


def _fmt_num(v):
    if v is None:
        return "N/A"
    if abs(v) >= 1e9:
        return f"${v/1e9:.1f}B"
    elif abs(v) >= 1e6:
        return f"${v/1e6:.1f}M"
    else:
        return f"${v:.0f}"


# ═══════════════════════════════════════════════════════
#  输出
# ═══════════════════════════════════════════════════════

def to_markdown(result):
    """Markdown 输出"""
    lines = []
    lines.append(f"# 维护性CapEx分析 — {result['ticker']}")
    lines.append(f"")
    lines.append(f"**获取方法：** {_method_desc(result.get('method',''))}")
    lines.append(f"**10-K期间：** {result.get('ten_k_period','N/A')}")
    lines.append(f"")
    
    total = result.get("total_capex", {})
    mc = result.get("maintenance_capex", {})
    gc = result.get("growth_capex", {})
    
    if total:
        lines.append(f"## CapEx拆分（最近3年）")
        lines.append(f"")
        lines.append(f"| 年份 | 总CapEx | 维护性 | 增长性 | 维护占比 |")
        lines.append(f"|------|--------|-------|-------|---------|")
        for year in sorted(mc.keys(), reverse=True)[:3]:
            t = total.get(year, 0)
            m = mc.get(year, 0)
            g = gc.get(year, 0)
            pct = round(m/t*100, 1) if t else 0
            lines.append(f"| {year} | {_fmt_num(t)} | {_fmt_num(m)} | {_fmt_num(g)} | {pct}% |")
        lines.append(f"")
    
    if result.get("disclosure_text"):
        lines.append(f"## 10-K原文摘录")
        lines.append(f"")
        lines.append(f"```")
        lines.append(result["disclosure_text"][:1500])
        lines.append(f"```")
        lines.append(f"")
    
    lines.append(f"## 分析结论")
    lines.append(f"")
    lines.append(f"{result.get('analysis','')}")
    lines.append(f"")
    
    if result.get("trend_summary"):
        lines.append(f"### 趋势")
        lines.append(f"")
        for t in result["trend_summary"]:
            lines.append(f"- {t}")
    
    # EPV中的应用说明
    lines.append(f"")
    lines.append(f"## 在EPV计算中的应用")
    method = result.get("method", "da_proxy")
    pct = result.get("maintenance_pct", 0.7)
    if method == "sec_disclosure":
        lines.append(f"使用10-K中披露的维护性CapEx（${pct*100:.0f}% 占总CapEx）作为EPV中的维护性支出。")
    elif method == "da_proxy":
        lines.append(f"使用D&A（${pct*100:.0f}% 占总CapEx）作为维护性CapEx的代理。注意：在增长型公司中，D&A通常低估实际维护性支出。")
    else:
        lines.append(f"按总CapEx的{pct*100:.0f}%估算维护性支出。建议在10-K可用时更新此数字。")
    
    return "\n".join(lines)


def _method_desc(method):
    descs = {
        "sec_disclosure": "✅ 10-K直接披露维护性/增长性拆分（最可靠）",
        "da_proxy": "⚠️ D&A代理法（维护性CapEx ≈ 折旧摊销，次优方案）",
        "yfinance_estimate": "❌ 仅yfinance估算（最不可靠，建议补充10-K）",
    }
    return descs.get(method, "未知方法")


# ═══════════════════════════════════════════════════════
#  CLI
# ═══════════════════════════════════════════════════════

def main():
    import argparse
    parser = argparse.ArgumentParser(description="维护性资本开支提取器")
    parser.add_argument("--ticker", type=str, required=True, help="股票代码")
    parser.add_argument("--output", type=str, default=None, help="输出路径")
    parser.add_argument("--format", type=str, default="json", choices=["json", "markdown"])
    args = parser.parse_args()

    result = extract_maintenance_capex_from_10k(args.ticker)
    
    if args.format == "markdown":
        output = to_markdown(result)
    else:
        output = json.dumps(result, indent=2, default=str)
    
    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"[mc] ✅ 已写入 {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
