---
name: translate
description: "语义翻译（Semantic Translation）：使用本地 Ollama 模型 `huihui_ai/hy-mt1.5-abliterated:1.8b` 翻译文本，支持中英文互译。用法：/translate Hello World [to:zh|to:en]"
allowed-tools: "Bash(curl:*)"
---

# 语义翻译 (Translate)

使用本地 Ollama 模型进行语义翻译。当前默认模型为 `huihui_ai/hy-mt1.5-abliterated:1.8b`。参数：`$ARGUMENTS`

## 参数解析

从 `$ARGUMENTS` 中按顺序提取：
- **text**：要翻译的文字（必填）
- **target**：目标语言（可选，默认 `zh`）
  - `to:zh` 或不指定 → 翻译为中文
  - `to:en` → 翻译为英文

例如：
- `/translate Hello World` → 翻译为中文
- `/translate 你好世界 to:en` → 翻译为英文

仅接受文本输入，不负责音频转写；音频请先走 `/asr`。

## 步骤

1. 先检查翻译服务：
   ```
   curl -s http://127.0.0.1:8001/api/health
   ```
   如果连接失败，提示用户先运行 `./start_all.sh` 或 `./start_http_api.sh`。
   如需直接排查模型，也可以检查 Ollama 服务：
   ```
   curl -s http://127.0.0.1:11434/api/tags
   ```

2. 调用翻译 API：
   ```
   curl -s -X POST http://127.0.0.1:8001/api/text/translate \
     -H "Content-Type: application/json" \
     -d '{"text": "要翻译的文字", "target": "zh"}'
   ```

3. 解析 JSON 响应，向用户展示：
   - 原文（`source_text`）
   - 译文（`translated_text`）
   - 目标语言（`target`）

4. 如果 `fallback: true`，说明 Ollama 翻译失败（模型未加载或服务未运行），
   提示用户检查 Ollama 服务（运行 `ollama serve` 或检查配置）。
