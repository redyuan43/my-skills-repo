# SEC EDGAR API 使用指南

## 概述
SEC EDGAR 提供所有美股上市公司的原始申报文件（10-K、10-Q、8-K 等）。
**完全免费**，无需注册，无需 API Key。

## 集成方式
在 `fetch_financials.py` 中自动执行 `enrich_with_sec(data)`，结果写入 `data["sec_edgar"]`。

## 数据获取链路

### 1. CIK 查询
```
GET https://www.sec.gov/files/company_tickers.json
```
返回所有上市公司 ticker → CIK 的完整映射。查找方式：
```python
for entry in mapping.values():
    if entry["ticker"] == "CROX":
        cik = entry["cik_str"]  # 例: 1334036
```

### 2. 获取最近 10-K 提交信息
```
GET https://data.sec.gov/submissions/CIK{cik_padded_to_10}.json
```
解析 `filings.recent` 列表，找到 form="10-K" 的最新一条。提取：
- `accessionNumber`（档案号）
- `primaryDocument`（主文件名，通常是 HTML）
- `reportDate`（报告期）

### 3. 下载 10-K HTML
```
GET https://www.sec.gov/Archives/edgar/data/
    {cik}/{accession_without_dashes}/{primary_document}
```

### 4. 提取章节
通过正则匹配提取：
- **Item 1 — Business**：公司业务描述
- **Item 1A — Risk Factors**：风险因素
- **Item 7 — MD&A**：管理层讨论与分析
- **Item 11 — Executive Compensation**：高管薪酬（通常引用至 Proxy Statement）

## 已知限制
- Executive Compensation 通常引用至 DEF 14A（Proxy Statement），需单独获取
- 10-K HTML 格式在各公司之间不统一，章节提取可能不完美
- 需要设置 User-Agent 才能访问 SEC 服务器
- SEC 有速率限制（约 10 次/秒），大部分场景不会触发
