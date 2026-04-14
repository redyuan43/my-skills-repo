---
name: pywxdump-obsidian-shortcut
description: 为当前仓库生成一个“先增量导出 chat_archive，再打开 Obsidian Vault”的桌面快捷方式，适用于新机器初始化、桌面入口修复和 Vault 路径迁移。
---

# PyWxDump Obsidian Shortcut

## Overview

这个 skill 只做一件事：

- 调用仓库内正式入口 `tools/install_obsidian_vault_shortcut.py`

不要在 skill 里重复实现桌面文件和启动脚本逻辑。快捷方式生成、更新和参数处理一律复用仓库脚本。

## Workflow

1. 解析 `PYWXDUMP_REPO_ROOT`；如果没有，就优先用当前工作目录，再回退到 `~/github/PyWxDump`。
2. 优先使用 repo 内 `.venv/bin/python`；没有时再回退到 `python3`。
3. 运行 `tools/install_obsidian_vault_shortcut.py`。
4. 用户如果没有显式传参，使用默认值：
   - `~/chat_archive`
   - `~/Documents/ObsidianVaults/wechat-knowledge`
   - `~/Applications/Obsidian-1.12.7-arm64.AppImage`
   - 快捷方式名称 `微信知识库`
5. 把生成出来的脚本路径、桌面图标路径和 Vault 路径反馈给用户。

## Quick Use

```bash
skills/pywxdump-obsidian-shortcut/scripts/install_shortcut.sh
skills/pywxdump-obsidian-shortcut/scripts/install_shortcut.sh --shortcut-name "微信知识库" --vault-root "$HOME/Documents/ObsidianVaults/wechat-knowledge"
```

## Constraints

- 当前 skill 生成的是 Linux 桌面快捷方式（`.desktop`）。
- 它不会自动安装 Obsidian，只会写快捷方式和启动脚本。
- 启动脚本默认会先执行一次增量导出，再打开 Obsidian。
