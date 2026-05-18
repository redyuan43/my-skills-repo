---
name: notion-upload
description: "将投资报告上传到 Notion 父页面（Report for Hermes），以子页面形式展示，含批次分隔标记"
version: 1.0.0
author: Hermes Agent
---

# Notion Upload — 投资报告同步到 Notion

## 前置条件

- `NOTION_API_KEY` 配置在 `~/.hermes/.env` 中
- Notion 目标页面已对 Integration 开放访问
- 目标页面: `Report for Hermes` (ID: `3551dbfc72bb80a6849cdc1292697c14`)

## 触发条件

用户**明确要求**以下内容时触发此 skill（非默认行为）：
- "上传到 notion"
- "同步到 notion"
- "把报告发到 notion"

## 用法

```bash
cd ~/.hermes/skills/data-science/notion-upload/scripts

# 上传指定股票的最新4份报告
export $(grep NOTION_API_KEY ~/.hermes/.env)
python3 upload_to_notion.py --ticker XNET

# 上传指定文件
python3 upload_to_notion.py --files "report1.md,report2.md"
```

## 工作流程

1. 读取 `out/out_reports/` 目录下的 MD 报告
2. `--ticker` 模式：各类型（备忘录/思考链/批判性审视/巴菲特）取最新版本
3. 在父页面底部插入分隔标记 `📌 ▶ [代码] — [日期] V[版本]`
4. 通过 `POST /pages` 创建子页面（默认在父页面底部）
5. 将报告内容逐 block 解析上传

## 页面标题映射

| 报告类型 | emoji | 标题前缀 |
|---------|-------|---------|
| `investment_memo` | 📊 | 投资备忘录 |
| `reasoning_trace` | 🔍 | 推理轨迹 |
| `reasoning_review` | 🔍 | 思考链 |
| `critical_review` | ⚠️ | 批判性审视 |
| `buffett_review` | 🦅 | 巴菲特视角 |

## ⚠️ HOME 目录扩展陷阱（macOS cfo profile）

**关键发现：** 在 cfo profile 环境中，`os.path.expanduser("~")` 返回 `/Users/michael/.hermes/profiles/cfo/home/`，而非 `/Users/michael/`。

这意味着脚本中的 `reports_dir = os.path.expanduser("~/.hermes/skills/...")` 实际解析为 `/Users/michael/.hermes/profiles/cfo/home/.hermes/skills/...`，而报告文件通常写在 `/Users/michael/.hermes/skills/...` 下。

**快速修复：** 将报告文件复制到 HOME 下的对应路径：
```bash
# 源: 实际报告位置
# 目标: $HOME/.hermes/skills/data-science/out/out_reports/
mkdir -p ~/.hermes/skills/data-science/out/out_reports
cp /Users/michael/.hermes/skills/data-science/out/out_reports/*CP代码* \
   ~/.hermes/skills/data-science/out/out_reports/
# 然后运行 upload_to_notion.py --ticker [代码]
```

**长期修复方案：** 将脚本中的 `os.path.expanduser("~")` 替换为硬编码路径，或使用 `os.environ.get('ORIGINAL_HOME', os.path.expanduser('~'))`。

## ⚠️ 维护陷阱：前缀同步

上传脚本内有 **3 处硬编码的报告类型前缀列表**（prefix filtering、type_config、emoji matching）。如果后续重命名任何 skill（如 reasoning_review→reasoning_xxx），必须同步更新 upload_to_notion.py 中所有 3 处。漏掉任意一处会导致 --ticker 模式找不到文件或 emoji 显示为默认 📄。

同步清单：
1. `all_matched` 的 startswith 过滤条件
2. `type_config` 字典的 key
3. emoji 匹配循环的 `for key in [...]`

## ⚠️ 已知修复：reasoning_trace 前缀

当前系统生成的文件前缀为 `reasoning_trace_`，但脚本默认只匹配 `reasoning_review_`。这是一个已知的命名不一致问题，已在以下 3 处追加修复：

1. `all_matched` 的 startswith tuple: 添加 `"reasoning_trace_"`（第 319 行附近）
2. `type_config` 字典: 添加 `"reasoning_trace": ("🔍", "推理轨迹")`（第 342 行附近）
3. emoji 匹配循环: 在 key list 中添加 `"reasoning_trace"`（第 369 行附近）

如果修复失效，请重新检查以上 3 处。临时绕过方式：`--files "/path/to/reasoning_trace_xxx.md"`
4. **报告文件名前缀** — 注意 `reasoning_trace_` 与 `reasoning_review_` 的差异：
   - `reasoning_trace` 是实际生成的文件前缀（来自 SOUL.md 中的 `reasoning_trace` 命名）
   - `reasoning_review` 是 skill 名称（来自 skill 目录名）
   - 如果 --ticker 模式找不到 `reasoning_trace_*` 文件，请手动传入：`--files "/path/to/reasoning_trace_xxx.md"`

## 报告文件命名格式

```
[类型]_[股票代码]_[公司名]_[日期YYYYMMDD]_V[版本].md
```

## 路径说明

```
脚本:    ~/.hermes/skills/data-science/notion-upload/scripts/upload_to_notion.py
报告源:  ~/.hermes/skills/data-science/out/out_reports/
```

## 集成到 financial-analysis

在 `financial-analysis` 中完成报告生成后调用：

```bash
cd ~/.hermes/skills/data-science/notion-upload/scripts
export $(grep NOTION_API_KEY ~/.hermes/.env)
python3 upload_to_notion.py --ticker [代码]
```
