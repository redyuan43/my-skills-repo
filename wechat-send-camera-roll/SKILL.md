---
name: wechat-send-camera-roll
description: Batch-send camera photos from a mounted DCIM folder to an already-open standalone WeChat chat window on Ubuntu X11 using pure GUI controls. Use when the user wants to send all photos under a camera card or DCIM directory, wants a stable non-vision workflow, or needs resume/limit controls for repeated WeChat photo batches.
---

# Wechat Send Camera Roll

## Overview

Use `scripts/send_wechat_camera_roll.py` to send photos from a directory such as `DCIM/100MSDCF` to a standalone WeChat chat window.

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
5. Run the script and let it send files in sorted filename order.

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

## Resources

- `scripts/send_wechat_camera_roll.py`: batch-send photos from a directory with optional resume and limit controls.
