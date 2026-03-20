---
name: wechat-screenshot-send
description: Capture the current desktop on Ubuntu X11 and immediately send the screenshot to a specified WeChat chat or group through the local `PyWxDump` send pipeline. Use when the user asks to “截个图发给某人/某个群”, wants the action completed in one shot without a confirmation round, or wants the screenshot saved locally and sent right away.
---

# Wechat Screenshot Send

## Overview

Use `scripts/screenshot_send_wechat.sh` for a one-shot workflow: capture the desktop, save the screenshot under `~/Pictures/Screenshots/`, and immediately send it through `PyWxDump tools/linux_wx_chat_daemon.py send-image`.

在这台机器上，执行环境必须固定使用 `~/github/PyWxDump/.venv/bin/python`。不要使用系统 `python3`，否则容易再次触发 `Cryptodome` / `Pillow` 之类的依赖缺失问题。

默认行为是**直接发送**（除非你传 `--print-only`）并默认尝试最小化发送窗口（`restore_action=minimized`）。`standalone/auto` 下支持聊天名模糊匹配，例如 `meeting` 可命中 `meeting` 对应的独立窗口；若存在多个候选则会报错避免误发。
If the goal is排障，不是普通截图转发，优先用 `scripts/diagnose_control_wechat.sh`：先把鼠标悬停到目标控件，再触发交互式截图，把截图发到群里，并把诊断 Markdown 回发到同一会话。

When `--window-mode main` is used for a target that has not been warmed before, the underlying `PyWxDump` flow may need a vision model to pick the correct search result row. In practice, `qwen3.5-plus` is the stable choice for this step. If you use 阿里云 Coding Plan, prefer the native Anthropic-compatible endpoint `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1`. Do not assume `qwen3-coder-plus` is reliable for main-window search-result selection.

## Workflow

1. Determine the target chat title.
2. 普通截图场景默认抓取当前桌面并发送图片。
3. 诊断场景下，先把鼠标移到控件，再调用交互式截图快捷键。
4. Save the screenshot to `~/Pictures/Screenshots/`.
5. 根据需要选择 `--window-mode standalone|main|auto`。
6. 通过 `PyWxDump send-image` 发送截图。
7. 诊断场景继续调用视觉模型生成 Markdown 诊断，并回发文本。
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

通过主界面搜索并显式配置 Coding Plan 视觉参数：

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "丁国华" \
  --window-mode main \
  --main-window-vision-base-url "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1" \
  --main-window-vision-model "qwen3.5-plus" \
  --main-window-vision-thinking-budget-tokens 1024
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
- This skill assumes the local `PyWxDump` clone is `~/github/PyWxDump`.
- On this machine, always run through `~/github/PyWxDump/.venv/bin/python`. Do not fall back to system `python3` when executing live sends.
- `--window-mode standalone` requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- `--chat` 在 `standalone|auto` 模式下会进行独立窗口名模糊匹配；`--mode ui-window` 下也会要求匹配到独立窗口用于截图激活。
- For `--window-mode main`, the first successful send to a target warms that target. Later sends can reuse the lighter `warm_search_enter_refocus` path.
- For `--window-mode main`, prefer `qwen3.5-plus` as the search-result vision model if you explicitly configure `PyWxDump` main-window vision options.
- For `--window-mode main` with Coding Plan, prefer `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1` instead of the older OpenAI-compatible `/v1` endpoint.
- The underlying CLI now supports `--main-window-vision-timeout-seconds`, `--main-window-vision-thinking-budget-tokens`, and `--main-window-vision-disable-thinking`.
- `--mode ui-window` 仍然更适合配合独立窗口使用；主界面模式下更推荐 `--mode desktop`。
- 诊断脚本依赖本地视觉模型可用；若模型失败，脚本会把失败说明回发，而不是静默退出。
- 默认发送为即时发送（非 `--print-only`），`restore_action` 通常会返回 `minimized`，表示发送后窗口已最小化到后台。

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
