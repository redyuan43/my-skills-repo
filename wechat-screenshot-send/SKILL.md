---
name: wechat-screenshot-send
description: Capture the current desktop on Ubuntu X11 and immediately send the screenshot to a specified WeChat chat or group through the local `PyWxDump` send pipeline. Use when the user asks to “截个图发给某人/某个群”, wants the action completed in one shot without a confirmation round, or wants the screenshot saved locally and sent right away.
---

# Wechat Screenshot Send

## Overview

Use `scripts/screenshot_send_wechat.sh` for a one-shot workflow: capture the desktop, save the screenshot under `~/Pictures/Screenshots/`, and immediately send it through `PyWxDump tools/linux_wx_chat_daemon.py send-image`.
If the goal is排障，不是普通截图转发，优先用 `scripts/diagnose_control_wechat.sh`：先把鼠标悬停到目标控件，再触发交互式截图，把截图发到群里，并把诊断 Markdown 回发到同一会话。

## Workflow

1. Determine the target chat title.
2. 普通截图场景默认抓取当前桌面并发送图片。
3. 诊断场景下，先把鼠标移到控件，再调用交互式截图快捷键。
4. Save the screenshot to `~/Pictures/Screenshots/`.
5. 根据需要选择 `--window-mode standalone|main|auto`。
6. 通过 `PyWxDump send-image` 发送截图。
6. 诊断场景继续调用视觉模型生成 Markdown 诊断，并回发文本。
7. Do not ask for an extra confirmation step. If the window is missing or send fails, return the error directly.

## Quick Use

Capture and send to a group or contact immediately:

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "新技术讨论"
```

Delay a few seconds before capture:

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "Ivan" \
  --delay 3
```

通过主界面搜索并发送截图：

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "新技术讨论" \
  --window-mode main
```

Resolve the final command without capturing or sending:

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "新技术讨论" \
  --print-only
```

控件级诊断截图并回发分析：

```bash
skills/wechat-screenshot-send/scripts/diagnose_control_wechat.sh \
  --chat "新技术讨论" \
  --hover-x 2921 \
  --hover-y 593 \
  --note "排查底部工具栏文件发送是否被弹窗阻塞"
```

## Constraints

- This skill assumes Ubuntu X11 and `gnome-screenshot` is available.
- `--window-mode standalone` requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- `--mode ui-window` 仍然更适合配合独立窗口使用；主界面模式下更推荐 `--mode desktop`。
- 诊断脚本依赖本地视觉模型可用；若模型失败，脚本会把失败说明回发，而不是静默退出。

## Selftest

真实验收默认会截取当前桌面，并把截图发送到 `新技术讨论`。

```bash
skills/wechat-screenshot-send/scripts/selftest.sh
```

只做无副作用检查：

```bash
skills/wechat-screenshot-send/scripts/selftest.sh --safe
```

## Resources

- `scripts/screenshot_send_wechat.sh`: capture a desktop screenshot, expose `window_mode` / GUI timing parameters, and send it in one shot.
- `scripts/diagnose_control_wechat.sh`: hover a target control, capture an interactive screenshot, send it, and post a Markdown diagnosis.
- `scripts/selftest.sh`: real selftest for screenshot capture, downstream send, and print-only validation
