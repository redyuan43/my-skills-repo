#!/usr/bin/env python3
"""
upload_to_notion.py — 将投资报告上传到 Notion（子页面形式）

用法：
  python3 upload_to_notion.py --ticker DUOL
  python3 upload_to_notion.py --files "report1.md,report2.md"
"""

import json
import os
import re
import sys
import urllib.request

NOTION_API_KEY = os.environ.get("NOTION_API_KEY", "")
NOTION_VERSION = "2022-06-28"
API_BASE = "https://api.notion.com/v1"


def notion_request(method, path, data=None):
    url = f"{API_BASE}/{path}"
    headers = {
        "Authorization": f"Bearer {NOTION_API_KEY}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        err_body = e.read().decode()
        print(f"  ❌ API 错误 {e.code}: {err_body}", file=sys.stderr)
        return None


def extract_page_id(url_or_id):
    if not url_or_id:
        return None
    url_or_id = url_or_id.strip().rstrip("/")
    if re.match(r"^[a-f0-9]{32}$", url_or_id):
        return url_or_id
    if re.match(r"^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", url_or_id):
        return url_or_id.replace("-", "")
    m = re.search(r"([a-f0-9]{32})", url_or_id)
    if m:
        return m.group(1)
    m = re.search(r"([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})", url_or_id)
    if m:
        return m.group(1).replace("-", "")
    return url_or_id


def rich_text(text):
    parts = []
    segments = re.split(r"(\*\*.*?\*\*)", text)
    for seg in segments:
        if seg.startswith("**") and seg.endswith("**"):
            parts.append({"type": "text", "text": {"content": seg[2:-2]}, "annotations": {"bold": True}})
        elif seg.strip():
            parts.append({"type": "text", "text": {"content": seg}})
    if not parts:
        parts.append({"type": "text", "text": {"content": text or " "}})
    return parts


def md_to_notion_blocks(md_text):
    lines = md_text.split("\n")
    blocks = []
    i = 0
    table_buffer = []

    def flush_table():
        nonlocal table_buffer
        if not table_buffer:
            return
        max_cols = max(len(row) for row in table_buffer)
        rows = []
        for row_parts in table_buffer:
            cells = row_parts[:max_cols]
            while len(cells) < max_cols:
                cells.append("")
            cells_formatted = [[{"type": "text", "text": {"content": c.strip()}}] for c in cells]
            rows.append({"type": "table_row", "table_row": {"cells": cells_formatted}})
        if rows:
            blocks.append({
                "object": "block", "type": "table",
                "table": {"table_width": max_cols, "children": rows}
            })
        table_buffer = []

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            flush_table()
            i += 1
            continue

        if stripped.startswith("|") and stripped.endswith("|"):
            cells = [c.strip() for c in stripped.split("|")[1:-1]]
            if all(re.match(r"^[-:\s]+$", c) for c in cells):
                i += 1
                continue
            table_buffer.append(cells)
            i += 1
            continue
        else:
            flush_table()

        if stripped.startswith("```"):
            lang = stripped[3:].strip()
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i])
                i += 1
            code_text = "\n".join(code_lines)
            blocks.append({
                "object": "block", "type": "code",
                "code": {"language": lang or "plain text",
                         "rich_text": [{"type": "text", "text": {"content": code_text}}]}
            })
            i += 1
            continue

        if re.match(r"^---+\s*$", stripped):
            blocks.append({"object": "block", "type": "divider", "divider": {}})
            i += 1
            continue

        if stripped.startswith(">"):
            blocks.append({
                "object": "block", "type": "quote",
                "quote": {"rich_text": rich_text(stripped[1:].strip())}
            })
            i += 1
            continue

        if stripped.startswith("# ") and not stripped.startswith("## "):
            blocks.append({
                "object": "block", "type": "heading_1",
                "heading_1": {"rich_text": rich_text(stripped[2:])}
            })
            i += 1
            continue

        if stripped.startswith("## ") and not stripped.startswith("### "):
            blocks.append({
                "object": "block", "type": "heading_2",
                "heading_2": {"rich_text": rich_text(stripped[3:])}
            })
            i += 1
            continue

        if stripped.startswith("### "):
            blocks.append({
                "object": "block", "type": "heading_3",
                "heading_3": {"rich_text": rich_text(stripped[4:])}
            })
            i += 1
            continue

        if stripped.startswith("- "):
            blocks.append({
                "object": "block", "type": "bulleted_list_item",
                "bulleted_list_item": {"rich_text": rich_text(stripped[2:])}
            })
            i += 1
            continue

        if re.match(r"^\d+[\.\)]\s", stripped):
            text = re.sub(r"^\d+[\.\)]\s", "", stripped)
            blocks.append({
                "object": "block", "type": "numbered_list_item",
                "numbered_list_item": {"rich_text": rich_text(text)}
            })
            i += 1
            continue

        if stripped:
            blocks.append({
                "object": "block", "type": "paragraph",
                "paragraph": {"rich_text": rich_text(stripped)}
            })
        i += 1

    flush_table()
    return blocks


def upload_blocks(page_id, blocks):
    batch_size = 100
    total_uploaded = 0
    total_blocks = len(blocks)

    for start in range(0, total_blocks, batch_size):
        batch = blocks[start:start + batch_size]
        result = notion_request("PATCH", f"blocks/{page_id}/children", {"children": batch})
        if result:
            total_uploaded += len(batch)
            print(f"  已上传 {total_uploaded}/{total_blocks} blocks", end="\r")
        else:
            print(f"\n  ⚠️  batch {start//batch_size + 1} 上传失败")
            return False

    print(f"\n  ✅ 全部 {total_uploaded} blocks 上传完成")
    return True


def add_separator(parent_id, ticker, date, version):
    """在父页面底部插入分隔标记：批次标题 + 分割线。"""
    label = f"▶ {ticker} — {date} V{version}"
    blocks = [
        {
            "object": "block", "type": "callout",
            "callout": {
                "rich_text": [{"type": "text", "text": {"content": label}}],
                "color": "gray_background",
                "icon": {"type": "emoji", "emoji": "📌"}
            }
        },
        {"object": "block", "type": "divider", "divider": {}}
    ]
    result = notion_request("PATCH", f"blocks/{parent_id}/children", {"children": blocks})
    if result:
        print(f"  ✅ 已插入分隔标记: {label}")
    else:
        print(f"  ⚠️ 分隔标记插入失败（非致命）")


def create_child_page(parent_id, title, report_type_emoji, md_content):
    """创建子页面（默认追加到父页面底部），上传内容。"""
    display_title = f"{report_type_emoji} {title}"
    print(f"\n  创建子页面: {display_title}")

    page_data = {
        "parent": {"page_id": parent_id},
        "properties": {
            "title": {"title": [{"type": "text", "text": {"content": display_title}}]}
        }
    }
    result = notion_request("POST", "pages", page_data)
    if not result:
        print(f"  ❌ 页面创建失败: {display_title}")
        return False

    page_id = result.get("id", "")
    if not page_id:
        print("  ❌ 未获取到 page_id")
        return False
    print(f"  ✅ 页面已创建: {page_id}")

    blocks = md_to_notion_blocks(md_content)
    print(f"  解析了 {len(blocks)} 个 block")

    if not upload_blocks(page_id, blocks):
        return False

    # 末尾分割线
    notion_request("PATCH", f"blocks/{page_id}/children", {
        "children": [{"object": "block", "type": "divider", "divider": {}}]
    })

    return True


def main():
    import argparse
    parser = argparse.ArgumentParser(description="上传报告到 Notion（子页面形式）")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--ticker", default=None)
    mode.add_argument("--files", default=None)
    args = parser.parse_args()

    parent_url = "https://www.notion.so/Report-for-Hermes-3551dbfc72bb80a6849cdc1292697c14"
    parent_id = extract_page_id(parent_url)
    print(f"目标页面 ID: {parent_id}")

    if not NOTION_API_KEY:
        print("❌ NOTION_API_KEY 未设置")
        sys.exit(1)

    print("验证 API key...")
    result = notion_request("GET", "users/me")
    if result:
        print(f"  ✅ 已连接 Notion: {result.get('name', 'Unknown')}")
    else:
        print("  ❌ API key 无效，请检查")
        sys.exit(1)

    reports_dir = os.path.expanduser(
        "~/.hermes/skills/data-science/out/out_reports"
    )
    all_files = sorted(os.listdir(reports_dir), reverse=True)

    matched = []
    if args.files:
        file_list = [f.strip() for f in args.files.split(",")]
        for f in file_list:
            fpath = os.path.join(reports_dir, f) if not f.startswith("/") else f
            fname = os.path.basename(fpath)
            if os.path.exists(fpath):
                matched.append(fname)
            else:
                alt = os.path.expanduser(f)
                if os.path.exists(alt):
                    matched.append(os.path.basename(alt))
                else:
                    print(f"  ⚠️ 未找到: {f}")
        if not matched:
            print("❌ 所有指定的文件均未找到")
            sys.exit(1)
    elif args.ticker:
        ticker = args.ticker.upper()
        all_matched = [f for f in all_files
                       if f.startswith(("investment_memo_", "reasoning_trace_", "reasoning_review_",
                                        "critical_review_", "buffett_review_"))
                       and "_V" in f and ticker in f]
        if not all_matched:
            print(f"❌ 未找到 {ticker} 的分析报告")
            sys.exit(1)
        matched = []
        for prefix in ["investment_memo_", "reasoning_trace_", "reasoning_review_", "critical_review_", "buffett_review_"]:
            candidates = [f for f in all_matched if f.startswith(prefix)]
            if candidates:
                matched.append(sorted(candidates, reverse=True)[0])
        if not matched:
            print(f"❌ 未找到 {ticker} 的最新分析报告")
            sys.exit(1)

    if not matched:
        print("❌ 未找到匹配的报告文件")
        sys.exit(1)

    print(f"找到 {len(matched)} 份报告:", ", ".join(matched))
    print()

    type_config = {
        "investment_memo": ("📊", "投资备忘录"),
    "reasoning_trace": ("🔍", "推理轨迹"),
    "reasoning_review": ("🔍", "思考链"),
    "critical_review": ("⚠️", "批判性审视"),
    "buffett_review": ("🦅", "巴菲特视角"),
    }

    # 上传前先插入批次分隔标记（仅 --ticker 模式）
    if args.ticker and matched:
        ticker = args.ticker.upper()
        # 从第一个文件名提取日期和版本：investment_memo_DUOL_Duolingo_20260505_V2.md
        m = re.search(r"_(\d{8})_V(\d+)", matched[0])
        if m:
            add_separator(parent_id, ticker, m.group(1), m.group(2))

    success = 0
    for fname in matched:
        fpath = os.path.join(reports_dir, fname)
        if not os.path.exists(fpath):
            print(f"\n❌ 未找到: {fname}")
            continue

        with open(fpath, encoding="utf-8") as f:
            content = f.read()

        prefix = fname.split("_")[0]
        emoji, type_label = type_config.get(prefix, ("📄", "报告"))
        # 重新匹配正确的前缀（文件名如 reasoning_review_002327_...）
        for key in ["investment_memo", "reasoning_trace", "reasoning_review", "critical_review", "buffett_review"]:
            if fname.startswith(key):
                emoji, type_label = type_config[key]
                break
        title = fname.replace(".md", "")

        if create_child_page(parent_id, title, emoji, content):
            success += 1
        else:
            print(f"  ❌ {fname} 上传失败")

    print(f"\n{'='*50}")
    print(f"上传完成: {success}/{len(matched)} 份报告")
    print(f"💡 注意: Notion API 限制，子页面默认按创建顺序排列（最新的在底部）")
    print(f"查看地址: {parent_url}")


if __name__ == "__main__":
    main()
