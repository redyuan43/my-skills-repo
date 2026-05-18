# Baostock 使用指南

## 安装
```bash
pip install baostock
```
无需注册，无需 API Key。登录调用 `bs.login()` 返回 "login success!" 即成功。

## 已验证可用的函数

### 分红数据（已集成到 fetch_financials.py）
```python
import baostock as bs
lg = bs.login()
rs = bs.query_dividend_data(code="sh.601398", year="2024")
df = rs.get_data()
# 关键列：
# dividCashPsBeforeTax — 税前每股现金分红
# dividOperateDate — 除权日
# dividPlanAnnounceDate — 宣告日
# dividCashStock — 描述，如 "10派3.064元"
```

### 指数成分股
```python
rs = bs.query_hs300_stocks()   # 沪深300
rs = bs.query_zz500_stocks()   # 中证500
rs = bs.query_sz50_stocks()    # 上证50
df = rs.get_data()
# 列: code (如 "sh.601398"), code_name (如 "工商银行")
# 转 yfinance 兼容:
# code.startswith("sh.") → code[3:] + ".SS"
# code.startswith("sz.") → code[3:] + ".SZ"
```

### 股票基本信息
```python
rs = bs.query_stock_basic(code="sh.601398")
df = rs.get_data()
# 列: code, code_name, ipoDate, status
```

### 行业分类
```python
rs = bs.query_stock_industry()
df = rs.get_data()
# 列: code, industryName, industryClassification
# 注意：实测 industryName 可能为空，需要排查列名映射
```

## 注意事项

- `bs.login()` 和 `bs.logout()` 必须成对调用
- q 每次 login 后获取的数据是独立的（断开重连会丢失会话）
- 所有财务指标函数（query_profit_data 等）返回的是**财务比率**，不是详细的财务报表科目
- 港股/美股不支持
