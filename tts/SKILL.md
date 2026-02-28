---
name: tts
description: "文字转语音（Text-to-Speech）：将文字合成为语音并播放。使用本地 Qwen3-TTS 模型，默认音色 Vivian。用法：/tts 你好世界"
disable-model-invocation: true
allowed-tools: "Bash(curl:*), Bash(aplay:*), Bash(paplay:*), Bash(ffplay:*)"
argument-hint: "[text] [speaker:Name] [speed:1.0]"
---

# 文字转语音 (TTS)

合成语音并播放。参数：`$ARGUMENTS`

## 参数解析

从 `$ARGUMENTS` 中提取：
- **text**：要合成的文字（必填）
- **speaker**：音色（可选，默认 Vivian，格式 `speaker:Name`）
- **speed**：语速 0.5~2.0（可选，默认 1.0，格式 `speed:1.5`）

例如：`/tts 你好世界 speaker:Vivian speed:0.9`

## 步骤

1. 先检查 TTS 服务：
   ```
   curl -s http://127.0.0.1:8002/api/health
   ```
   如果连接失败，提示用户先运行 `./start_all.sh` 或 `./tts_http_server.py`。
   将健康检查响应保存为 `$HEALTH`。

1.5. 检查模型是否已加载（从步骤 1 的 `$HEALTH` 中读取 `tts_model_loaded`）：
   - 若 `tts_model_loaded` 为 false，调用加载接口：
     ```
     curl -s -X POST http://127.0.0.1:8002/api/tts/load
     ```
   - 然后轮询等待加载完成（最多 90 秒，每 3 秒一次）：
     ```
     for i in $(seq 1 30); do
       sleep 3
       STATUS=$(curl -s http://127.0.0.1:8002/api/health)
       LOADED=$(echo "$STATUS" | grep -o '"tts_model_loaded":[^,}]*' | grep -o 'true\|false')
       WORKERS=$(echo "$STATUS" | grep -o '"tts_parallel_workers_ready":[0-9]*' | grep -o '[0-9]*$')
       [ "$LOADED" = "true" ] && [ "${WORKERS:-0}" -gt 0 ] && break
     done
     ```
   - 若超时仍未加载（`tts_model_loaded` 仍为 false），报错提示用户并停止。
   - 若 `tts_model_loaded` 已为 true，直接进入下一步。

2. 调用 TTS API（将解析出的参数填入 JSON）：
   ```
   curl -s -X POST http://127.0.0.1:8002/api/tts/speak \
     -H "Content-Type: application/json" \
     -d '{"text": "文字内容", "speaker": "Vivian", "speed": 1.0}' \
     -o /tmp/capswriter_tts.wav
   ```

3. 播放音频（按顺序尝试）：
   ```
   aplay /tmp/capswriter_tts.wav 2>/dev/null || \
   paplay /tmp/capswriter_tts.wav 2>/dev/null || \
   ffplay -nodisp -autoexit /tmp/capswriter_tts.wav 2>/dev/null
   ```

4. 告知用户合成完成，文件已保存到 `/tmp/capswriter_tts.wav`。
   如果 API 返回 JSON 错误（非 WAV），先尝试重新调用加载接口（`curl -s -X POST http://127.0.0.1:8002/api/tts/load`），等待加载完成后重试合成一次；若仍失败则解析并显示错误信息。

## 注意

- 文字不超过 300 字（TTS 服务单次限制）
- 如需合成长文本，告知用户可以分段调用
