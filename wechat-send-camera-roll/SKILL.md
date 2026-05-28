---
name: wechat-send-camera-roll
description: Batch-send camera photos from a mounted DCIM folder to an already-open standalone WeChat chat window on Ubuntu X11 using pure GUI controls. Use when the user wants to send all photos under a camera card or DCIM directory, wants a stable non-vision workflow, or needs resume/limit controls for repeated WeChat photo batches.
---

# Wechat Send Camera Roll

## Overview

Use `scripts/send_wechat_camera_roll.py` to send photos from a directory such as `DCIM/100MSDCF` to a standalone WeChat chat window.

## Send Safety Gate

只有同时满足三要素时才允许批量发送：

- 目标明确：用户明确给出微信联系人或群名，且目标窗口已作为独立聊天窗口打开。
- 文件明确：用户明确给出相机目录，或明确给出起点/数量限制用于验证。
- 意图明确：用户明确要求“发送这些照片/批量发给/从相机卡发出”等真实出站动作。

任一要素不清楚时，先停下确认。新机器或新相机目录先建议 `--limit 1` 或 `--print-only`，不要自动把整个 DCIM 发出。

This skill uses pure X11 GUI controls:

- activate the target chat by title
- click the toolbar folder button
- operate the `Open` chooser with `Alt+N`
- fill the filename
- confirm with `Alt+O`
- press `Return` in the chat window to actually send

Do not use vision or OCR for this workflow.

## Workflow

1. Make sure the target WeChat conversation is already opened as a standalone chat window.
2. Point the script at the mounted photo directory.
3. Use `--limit 1` or `--limit 3` when validating on a new machine.
4. Use `--start-after FILE.JPG` to resume after an interruption.
5. Confirm the user intends to send now; otherwise stop with a concise confirmation question.
6. Run the script and let it send files in sorted filename order.

## Quick Use

Send all photos in a camera folder:

```bash
python3 skills/wechat-send-camera-roll/scripts/send_wechat_camera_roll.py \
  --chat "可可" \
  --dir "/media/ivan/5E48-2118/DCIM/100MSDCF"
```

Only send one photo for validation:

```bash
python3 skills/wechat-send-camera-roll/scripts/send_wechat_camera_roll.py \
  --chat "可可" \
  --dir "/media/ivan/5E48-2118/DCIM/100MSDCF" \
  --limit 1
```

Resume after a known filename:

```bash
python3 skills/wechat-send-camera-roll/scripts/send_wechat_camera_roll.py \
  --chat "可可" \
  --dir "/media/ivan/5E48-2118/DCIM/100MSDCF" \
  --start-after "DSC00579.JPG"
```

## Constraints

- The target chat window must already exist as a standalone WeChat window.
- This workflow assumes Ubuntu X11.
- The chooser title is currently expected to be `Open`.
- The script depends on the local `wechat-auto-reply` project and its current pure-control `send_file` flow.

## Selftest

真实验收默认会生成两张临时测试图片，并把其中一张真实发送到 `新技术讨论`。

```bash
skills/wechat-send-camera-roll/scripts/selftest.sh
```

只做无副作用检查：

```bash
skills/wechat-send-camera-roll/scripts/selftest.sh --safe
```

## Resources

- `scripts/send_wechat_camera_roll.py`: batch-send photos from a directory with optional resume and limit controls.
- `scripts/selftest.sh`: real selftest for local image generation, batch-send flow, and print-only validation
