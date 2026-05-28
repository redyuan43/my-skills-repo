---
name: diarization
description: 说话人分离（Speaker Diarization）：对本地音频或视频文件生成 speaker turns、RTTM 和 speaker transcript。用法：/diarization /path/to/audio-or-video
allowed-tools: Bash(ffmpeg:*), Bash(bash:*), Bash(curl:*)
---

# Speaker Diarization

将本地音频或视频文件送入 `diarization` 项目，输出：
- `diarization.json`
- `diarization.rttm`
- `speaker_transcript.md`
- `run_manifest.json`

参数：`$ARGUMENTS`

## 步骤

1. 校验输入路径存在。

2. 如果输入是视频文件（如 `mp4/mkv/mov/m4a`），先转成 `16k/单声道 wav`：
   ```bash
   mkdir -p /tmp/diarization-skill
   ffmpeg -y -i "$ARGUMENTS" -vn -ac 1 -ar 16000 -c:a pcm_s16le /tmp/diarization-skill/input.wav
   ```
   如果输入已经是音频或 meeting 目录，直接使用原路径。

3. 检查 ASR 服务健康状态：
   ```bash
   curl -s http://127.0.0.1:8001/api/health
   ```
   如果不可用，提示用户先启动本地 ASR 服务；但仍可继续跑 diarization，只是 transcript 可能部分缺失。

4. 执行 diarization：
   ```bash
   cd /home/ivan/github/diarization
   source .venv/bin/activate
   PYTHONPATH=src python -m diarization.cli run \
     --input "<resolved-input>" \
     --out-dir /tmp/diarization-skill/out \
     --accel gpu
   ```

5. 向用户回报：
   - `turn_count`
   - 是否走了 GPU（看 `run_manifest.json` 里的 `resolved_device`）
   - 输出目录
   - `speaker_transcript.md` 路径
   - 任何 warning
