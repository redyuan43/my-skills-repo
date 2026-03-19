---
name: linux-wechat-send-bootstrap
description: Bootstrap PyWxDump Linux WeChat text sending for new users on the current machine. Use when `tools/linux_wx_chat_daemon.py send-text` fails because `.venv` misses `Pillow` or `Cryptodome`, `~/.wx_db_keys.json` is empty, `kernel.yama.ptrace_scope` blocks key extraction, `OPENAI_API_KEY` only exists in `~/.bashrc`, or the main-window search needs a vision-verified fallback before sending.
---

# Linux WeChat Send Bootstrap

## Overview

Use this skill to take a fresh local PyWxDump checkout from "repo present but send-text not working" to "one text message sent and confirmed by database readback".

This skill targets PyWxDump and assumes Linux WeChat is already running and logged in on the current desktop session.

## Workflow

1. Keep tracked repo files clean if the user requests a reset. Preserving `.venv/` is fine.
2. Resolve the PyWxDump repo root from one of these sources:
   - `PYWXDUMP_REPO_ROOT`
   - current working directory
   - common clone paths such as `~/github/PyWxDump`
3. Ensure the repo virtualenv exists and install missing local dependencies into `.venv`:
   - `pycryptodomex`
   - `Pillow`
4. Pick the newest `db_storage` under `~/Documents/xwechat_files/wxid_*/db_storage` unless the user provides `--db-dir`.
5. If `~/.wx_db_keys.json` is missing or empty, ask before lowering `kernel.yama.ptrace_scope`, then extract keys and restore the original value.
6. Decrypt databases into `~/wx_decrypted`.
7. Load `OPENAI_API_KEY` from an interactive Bash session because `~/.bashrc` may not expose it to non-interactive shells.
8. Use the wrapper script. It runs a safer send path than the default one-shot command:
   - initialize monitor state
   - search the target in the main window
   - verify the right-side title with vision
   - send the text
   - confirm success by local DB readback

## Quick Use

Send one text and allow temporary ptrace relaxation after explicit user confirmation:

```bash
skills/linux-wechat-send-bootstrap/scripts/send_text_with_setup.sh \
  --target "新技术讨论" \
  --text "你好" \
  --allow-ptrace-toggle
```

If the skill is installed outside the PyWxDump repo, point it to the clone explicitly:

```bash
PYWXDUMP_REPO_ROOT="$HOME/github/PyWxDump" \
linux-wechat-send-bootstrap/scripts/send_text_with_setup.sh \
  --target "新技术讨论" \
  --text "你好" \
  --allow-ptrace-toggle
```

Use an explicit database directory:

```bash
skills/linux-wechat-send-bootstrap/scripts/send_text_with_setup.sh \
  --target "新技术讨论" \
  --text "你好" \
  --db-dir "$HOME/Documents/xwechat_files/wxid_xxx/db_storage" \
  --allow-ptrace-toggle
```

## Constraints

- Linux WeChat main window must be visible and logged in.
- PyWxDump repo must exist locally. If auto-discovery fails, set `PYWXDUMP_REPO_ROOT`.
- `OPENAI_API_KEY` must be available from `bash -ic`, typically via `~/.bashrc`.
- `ffmpeg`, `xwd`, and X11 control tools must already exist on the machine.
- Only pass `--allow-ptrace-toggle` after explicit user confirmation because it temporarily lowers `kernel.yama.ptrace_scope`.
- The wrapper only changes the repo-local virtualenv and user-local artifacts such as `~/.wx_db_keys.json` and `~/wx_decrypted`.

## Resources

- `scripts/send_text_with_setup.sh`: prerequisite bootstrap, key extraction, decrypt, and interactive-shell handoff.
- `scripts/send_text_with_setup.py`: robust "search + verify + send + DB readback" runner.
