---
name: dual-mi-barge-in-replay-lab
description: 用两台 MI Speakphone 做自动化 barge-in 真实回放实验：speaker1 负责助手播报，speaker2 负责模拟外部插话，mic1 负责检测与识别。适用于定位“实时语音打断不灵敏”“AEC 把外部插话也消掉了”“流式 partial 比 batch 更差”“双设备自动化回放测试怎么搭”的场景。
---

# Dual MI Barge-in Replay Lab

当用户想用两台 `MI Speakphone` 自动模拟真人插话，而不是靠人工反复说话时，使用这个 skill。

## 何时使用

- 需要验证 `speaker2 -> mic1 -> barge-in detect -> stop speaker1 -> ASR` 整条链路。
- 需要比较 `barge_in_asr_mode=batch` 和 `stream` 的真实效果。
- 需要判断问题在：
  - `speaker2` 注入没打进去
  - `AEC` 把外部插话也杀掉了
  - 检测源选错
  - endpointing / partial 收尾不对
- 需要把双设备自动化测试做成可重复实验，而不是临场靠人耳和体感判断。

## 前置条件

1. 项目路径：
`/home/dgx/github/CapsWriter-Offline-Windows-64bit-main`
2. 两台 `MI Speakphone` 都已被系统识别。
3. 当前仓库里的以下入口存在：
   - `barge_in_replay_lab.py`
   - `run_barge_in_replay_lab.sh`
   - `echo_repeat_client.py`
   - `local_ai_chat_client.py`
4. `ASR/TTS` 服务可用。

## 当前推荐拓扑

- `speaker1`: 第 1 台 `MI` 输出，负责助手播报
- `mic1`: 第 1 台 `MI` 输入，负责 barge-in 检测与识别
- `speaker2`: 第 2 台 `MI` 输出，负责模拟外部插话
- `mic2`: 第 2 台 `MI` 输入，只作为辅助元数据或额外观测

## 当前稳定结论

1. 双 `MI` 场景下，`barge-in` 检测源默认应使用 `raw mic1`。
2. `AEC source` 不应作为双 `MI` 场景的默认检测源；它会把 `speaker2` 外部插话也一起压掉。
3. `speaker2` 注入播放优先使用 `ALSA` 直打硬件，而不是只依赖 `Pulse/PipeWire` sink。
4. 当前自动实验里，`batch` 比 `stream` 更稳，应作为默认 `barge_in_asr_mode`。

## 标准工作流

1. 列设备并确认角色映射：
`bash "/home/dgx/github/CapsWriter-Offline-Windows-64bit-main/run_barge_in_replay_lab.sh" --list-devices`

2. 跑最小 isolated 实验：
`/home/dgx/github/CapsWriter-Offline-Windows-64bit-main/venv-asr/bin/python "/home/dgx/github/CapsWriter-Offline-Windows-64bit-main/barge_in_replay_lab.py" --mode isolated --stimulus short_wait --repeat 1 --barge-in-detector-source raw --barge-in-asr-mode batch`

3. 如果要做 A/B：
先跑 `batch`，再单独跑 `stream`，不要并行跑。

4. 读取输出目录中的：
   - `summary.json`
   - `lab.log`
   - `*.trace.jsonl`
   - `*.injector_preflight_raw.wav`
   - `*.captured_input.wav`

## 关键判据

- `injector_preflight_passed`
- `detect_ms`
- `tts_stop_ms`
- `capture_ready_ms`
- `capture_duration_ms`
- `final_asr_text`
- `failure_class`

## failure_class 解释

- `injector_not_observed_on_raw`
  - `speaker2` 注入在 `raw mic1` 上都没被看到，优先查注入播放和硬件路由。
- `aec_suppressed_external_injector`
  - `raw mic1` 能看到，`AEC source` 看不到，说明 AEC 不适合作为检测源。
- `detector_source_missed_valid_injector`
  - 注入存在，但检测源没触发，优先查检测源选择和阈值。
- `endpoint_truncated_after_detect`
  - 已触发停播，但收尾过早或识别不完整，优先查 endpointing / partial 收尾。
- `ok`
  - 整条链路在当前 trial 下通过。

## 当前推荐默认参数

- `--barge-in-detector-source raw`
- `--barge-in-asr-mode batch`

如果用户要求验证新方案，再显式切到：
- `--barge-in-asr-mode stream`

## 排障顺序

1. 先看 `injector_preflight_passed`
2. 再看 `detect_ms / missed_interrupt`
3. 再看 `capture_duration_ms / capture_reason`
4. 最后看 `final_asr_text / CER / WER`

更详细的结论模板和实验经验见：
- `references/runbook.md`
