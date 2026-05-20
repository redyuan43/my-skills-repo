#!/usr/bin/env python3
"""
Polygon.io 金融数据采集器
美股行情/财报/K线/股息/拆分 — 作为 yfinance 的补充

用法:
  python3 polygon_data.py --ticker AAPL --type quote
  python3 polygon_data.py --ticker AAPL --type financials --limit 5
  python3 polygon_data.py --ticker AAPL --type bars --from 2023-01-01 --to 2025-12-31
  python3 polygon_data.py --ticker AAPL --type dividends
  python3 polygon_data.py --ticker AAPL --type all
"""

import os, sys, json, argparse
from datetime import datetime, timedelta
from pathlib import Path
import urllib.request
import urllib.error

BASE_URL = "https://api.polygon.io"
CACHE_DIR = os.path.expanduser("~/.polygon_data/output")

def read_polygon_api_key():
    """按本机约定自动查找 Polygon API Key"""
    value = os.environ.get("POLYGON_API_KEY")
    if value:
        return value

    script_path = Path(__file__).resolve()
    skill_root = script_path.parents[2]
    config_paths = [
        skill_root / ".env.local",
        script_path.parent.parent / "config" / "api_keys.json",
        Path.home() / ".hermes" / "skills" / "data-science" /
        "financial-data-acquisition" / "config" / "api_keys.json",
        Path.home() / ".hermes" / ".env",
    ]

    for path in config_paths:
        if not path.exists():
            continue
        try:
            if path.suffix == ".json":
                config = json.loads(path.read_text())
                value = config.get("polygon_api_key") or config.get("POLYGON_API_KEY")
                if value:
                    return value
            else:
                for raw_line in path.read_text(errors="ignore").splitlines():
                    line = raw_line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    key, value = line.split("=", 1)
                    if key.strip() == "POLYGON_API_KEY" and value.strip():
                        return value.strip().strip('"').strip("'")
        except Exception:
            continue
    return ""

API_KEY = read_polygon_api_key()

def api_get(path, params=None):
    """调用 Polygon.io REST API"""
    if not API_KEY:
        print("❌ POLYGON_API_KEY 未设置")
        print("   请 export POLYGON_API_KEY=your_key_here，或配置 data-science/.env.local / scripts/config/api_keys.json")
        sys.exit(1)
    
    url = f"{BASE_URL}{path}"
    if params:
        params["apiKey"] = API_KEY
        qs = "&".join(f"{k}={v}" for k, v in sorted(params.items()))
        url = f"{url}?{qs}"
    else:
        url = f"{url}?apiKey={API_KEY}"
    
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Hermes-CFO/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"❌ HTTP {e.code}: {e.reason}")
        if e.code == 401:
            print("   API Key 无效或未设置")
        elif e.code == 429:
            print("   频率限制: Free tier 5 calls/min")
        return None
    except Exception as e:
        print(f"❌ 请求失败: {e}")
        return None

def save_output(data, name):
    """保存结果到文件"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    fpath = os.path.join(CACHE_DIR, f"polygon_{name}_{ts}.json")
    with open(fpath, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"  ✅ 已保存: {fpath}")
    return fpath

def query_quote(ticker):
    """当日/上日行情"""
    print(f"\n📊 行情: {ticker}")
    data = api_get(f"/v2/aggs/ticker/{ticker}/prev")
    if not data or "results" not in data:
        print("   无数据")
        return
    r = data["results"][0]
    print(f"   昨收: ${r.get('c', 'N/A')}")
    print(f"   最高: ${r.get('h', 'N/A')}")
    print(f"   最低: ${r.get('l', 'N/A')}")
    print(f"   开盘: ${r.get('o', 'N/A')}")
    print(f"   成交量: {r.get('v', 'N/A')}")
    print(f"   日期: {r.get('t', 'N/A')}")
    save_output(data, f"{ticker}_quote")

def query_financials(ticker, limit=4):
    """财报数据（10-K/10-Q）"""
    print(f"\n📋 财报: {ticker} (最近{limit}期)")
    data = api_get(f"/v2/reference/financials/{ticker}", {
        "limit": limit,
    })
    if not data or "results" not in data:
        print("   无数据")
        return
    
    results = data.get("results", [])
    print(f"   共 {len(results)} 期财报")
    
    for i, rpt in enumerate(results[:limit]):
        period = rpt.get("period", "?")
        dt = rpt.get("calendarDate", "?")
        print(f"\n   [{i+1}] {period} ({dt})")
        print(f"       营收: {rpt.get('revenues', 'N/A')}")
        print(f"       毛利: {rpt.get('grossProfit', 'N/A')}")
        print(f"       净利润: {rpt.get('netIncome', 'N/A')}")
        print(f"       经营现金流: {rpt.get('netCashFlowFromOperations', 'N/A')}")
        print(f"       资本支出: {rpt.get('capitalExpenditure', 'N/A')}")
        print(f"       SBC(股权激励): {rpt.get('shareBasedCompensation', 'N/A')}")
        print(f"       自由现金流: {rpt.get('freeCashFlow', 'N/A')}")
        print(f"       总资产: {rpt.get('assets', 'N/A')}")
        print(f"       总负债: {rpt.get('totalLiabilities', 'N/A')}")
        print(f"       股东权益: {rpt.get('shareholdersEquity', 'N/A')}")
    
    save_output(data, f"{ticker}_financials")

def query_bars(ticker, from_date=None, to_date=None):
    """历史日K线"""
    if not to_date:
        to_date = datetime.now().strftime("%Y-%m-%d")
    if not from_date:
        from_date = (datetime.now() - timedelta(days=365)).strftime("%Y-%m-%d")
    
    print(f"\n📈 K线: {ticker} ({from_date} → {to_date})")
    data = api_get(f"/v2/aggs/ticker/{ticker}/range/1/day/{from_date}/{to_date}")
    if not data or "results" not in data:
        print("   无数据")
        return
    
    results = data.get("results", [])
    print(f"   共 {len(results)} 个交易日")
    for r in results[-5:]:
        dt = datetime.fromtimestamp(r["t"]/1000).strftime("%Y-%m-%d")
        print(f"   {dt} O:{r['o']} H:{r['h']} L:{r['l']} C:{r['c']} V:{r['v']}")
    
    save_output(data, f"{ticker}_bars")

def query_dividends(ticker):
    """分红历史"""
    print(f"\n💰 分红: {ticker}")
    data = api_get(f"/v2/reference/dividends/{ticker}")
    if not data or "results" not in data:
        print("   无数据")
        return
    
    results = data.get("results", [])
    print(f"   共 {len(results)} 条记录")
    for r in results[:5]:
        print(f"   {r.get('exDate', '?')}: ${r.get('amount', '?')} (付款日: {r.get('paymentDate', '?')})")
    
    save_output(data, f"{ticker}_dividends")

def query_all(ticker):
    """全量查询"""
    print(f"\n{'='*60}")
    print(f"全量采集: {ticker}")
    print(f"{'='*60}")
    query_quote(ticker)
    query_financials(ticker, 4)
    query_bars(ticker)
    query_dividends(ticker)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Polygon.io 金融数据采集器")
    parser.add_argument("--ticker", required=True, help="股票代码 (如 AAPL)")
    parser.add_argument("--type", default="quote",
                        choices=["quote", "financials", "bars", "dividends", "all"],
                        help="查询类型")
    parser.add_argument("--limit", type=int, default=4, help="财报期数限制")
    parser.add_argument("--from", dest="from_date", help="K线开始日期 (YYYY-MM-DD)")
    parser.add_argument("--to", dest="to_date", help="K线结束日期 (YYYY-MM-DD)")
    
    args = parser.parse_args()
    ticker = args.ticker.upper()
    
    handlers = {
        "quote": query_quote,
        "financials": lambda t: query_financials(t, args.limit),
        "bars": lambda t: query_bars(t, args.from_date, args.to_date),
        "dividends": query_dividends,
        "all": query_all,
    }
    handlers[args.type](ticker)
