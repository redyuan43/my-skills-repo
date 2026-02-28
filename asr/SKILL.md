---
name: asr
description: 语音识别（Speech-to-Text）：将音频文件转录为文字。使用本地 Qwen3-ASR 模型，支持中英文。用法：/asr /path/to/audio.wav
disable-model-invocation: true
allowed-tools: Bash(curl:*)
argument-hint: [audio-file-path]
---

# 语音识别 (ASR)

将音频文件转录为文字。参数：`$ARGUMENTS`

## 步骤

1. 先检查服务健康状态：
   ```
   curl -s http://127.0.0.1:8001/api/health
   ```
   如果连接失败，提示用户先运行 `./start_all.sh` 或 `./start_http_api.sh`。

2. 调用 ASR API 转录文件：
   ```
   curl -s -X POST http://127.0.0.1:8001/api/asr/transcribe \
     -F "audio=@$ARGUMENTS"
   ```

3. 解析 JSON 响应，向用户展示：
   - 识别文字（`text`）
   - 音频时长（`duration` 秒）
   - 语言（`language`）
   - 置信度（`confidence`）

4. 如果 `success` 为 false，显示错误信息并提示可能的原因（文件格式、路径错误等）。
