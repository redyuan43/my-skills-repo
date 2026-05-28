---
name: asr
description: 语音识别（Speech-to-Text）：输入音频文件，直接输出转写文本。当前默认后端使用本地 SenseVoiceSmall 模型，支持中英文。用法：/asr /path/to/audio.wav
allowed-tools: Bash(curl:*)
---

# 语音识别 (ASR)

将音频文件转录为文字。默认目标是直接返回转写文本，不做翻译。参数：`$ARGUMENTS`

适用场景：
- 用户给了一段本地音频，希望直接识别成文本
- 用户只需要语音转文字，不需要翻译
- 输入通常为 `.wav`，也可尝试常见音频格式如 `.mp3`、`.m4a`、`.flac`

示例：
- `/asr /home/user/voice.wav`
- `/asr /home/user/meeting.m4a`

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

3. 解析 JSON 响应。
   - 如果 `success` 为 true，默认直接向用户返回识别文字（`text`），不要额外做翻译、总结或改写。
   只有在用户明确需要更多信息时，再附带展示：
   - 音频时长（`duration` 秒）
   - 语言（`language`）
   - 置信度（`confidence`）

4. 如果 `success` 为 false，显示错误信息，并优先按以下方向提示：
   - 文件路径不存在或不可读
   - 音频格式不受支持或文件损坏
   - ASR 服务未启动，应先运行 `./start_all.sh` 或 `./start_http_api.sh`
   - 请求成功到达服务，但模型或后端处理失败
