---
name: emeet-record-av-toggle
description: EMEET PIXY 开始/停止录制：输入“开始”时后台启动人脸跟踪 + 视频 + 麦克风录音；输入“停止”时优雅停止并封装 MP4；也可查询状态。适用于“开始录制”“停止录制”“持续录到我叫停”为止这类请求。用法：/emeet-record-av-toggle [开始|停止|状态] [output.mp4]
disable-model-invocation: true
allowed-tools: "Bash(bash:*,ls:*,cat:*,kill:*)"
argument-hint: "[开始|停止|状态] [output.mp4]"
---

# EMEET PIXY 开始/停止录制

用这个 skill 做“说开始就录，说停止就停”的后台录制。参数：`$ARGUMENTS`

## 项目路径

`/home/dgx/github/emeet-pixy-face-tracker`

## 步骤

1. 确认脚本和虚拟环境存在：
   ```bash
   cd /home/dgx/github/emeet-pixy-face-tracker
   ls .venv/bin/python skills/emeet-record-av-toggle/scripts/toggle_record.sh
   ```

2. 执行控制脚本：
   ```bash
   cd /home/dgx/github/emeet-pixy-face-tracker && bash skills/emeet-record-av-toggle/scripts/toggle_record.sh $ARGUMENTS
   ```

## 行为

- `开始`
  - 后台启动 `emeet_pixy.apps.face_tracker` 录制视频
  - 同时后台启动 `ffmpeg` 从 `hw:1,0` 录制 EMEET PIXY 麦克风音频
  - 默认输出到 `var/recordings/face_track_talking_av_<timestamp>.mp4`
- `停止`
  - 向视频和音频后台进程发送 `SIGTERM`
  - 等待二者收尾，再自动 mux 成最终 MP4
- `状态`
  - 输出是否仍在录制、视频/音频 PID、输出文件、日志文件

## 可选参数

- 第二个参数可指定输出文件名，例如：
  ```bash
  bash skills/emeet-record-av-toggle/scripts/toggle_record.sh 开始 my_demo.mp4
  ```
  若给的是相对路径，会写到 `var/recordings/` 下。

## 实现入口

- 控制脚本：`skills/emeet-record-av-toggle/scripts/toggle_record.sh`
- 录制主程序：`emeet_pixy.apps.face_tracker`
- 音频录制：`ffmpeg -f alsa -channels 1 -sample_rate 48000 -i hw:1,0`

## 注意事项

- 默认设备固定为当前已验证可用的 `--camera 0 --device /dev/video0` 和 `hw:1,0`
- 同一时刻只允许一个后台录制任务
- 如遇异常退出，先执行一次 `状态`，再按提示决定是否重新 `开始`
