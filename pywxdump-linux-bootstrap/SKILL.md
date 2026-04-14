---
name: pywxdump-linux-bootstrap
description: 为当前仓库的 Linux 微信工具链执行依赖检查、安装、修复和配置写入。适用于新机器初始化、链路排障、环境迁移和 watcher/link-doc/ASR 运行前的自检。
---

# PyWxDump Linux Bootstrap

## Overview

这个 skill 只做一件事：

- 调用仓库内正式入口 `tools/bootstrap_linux_wechat_stack.py`

不要在 skill 里重复实现安装逻辑。安装、检测和配置写入一律复用仓库脚本。

## Workflow

1. 解析 `PYWXDUMP_REPO_ROOT`；如果没有，就优先用当前工作目录，再回退到 `~/github/PyWxDump`。
2. 优先使用 repo 内 `.venv/bin/python`；没有时再回退到 `python3`。
3. 根据用户意图执行：
   - `check --profile full`
   - `install --profile <profile>`
   - `repair --profile <profile>`
   - `write-config --profile <profile>`
4. 如果用户没有明确 profile，默认用 `full`。
5. 把脚本输出原样转述给用户，并额外说明哪些依赖已就绪、哪些仍缺失。

## Quick Use

```bash
skills/pywxdump-linux-bootstrap/scripts/bootstrap_with_profiles.sh check --profile full
skills/pywxdump-linux-bootstrap/scripts/bootstrap_with_profiles.sh install --profile link-doc
skills/pywxdump-linux-bootstrap/scripts/bootstrap_with_profiles.sh repair --profile asr
```

## Constraints

- 当前正式支持平台是 Ubuntu 22.04 + aarch64 + apt-get。
- `install` 和 `repair` 可能调用 `sudo apt-get`。
- `ai` profile 当前只认领已有环境，不会自动安装 `opencode`、`uvx` 和 `baoyu-skills`。
