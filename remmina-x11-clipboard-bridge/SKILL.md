---
name: remmina-x11-clipboard-bridge
description: 修复 Linux X11 下 Remmina 内复制文本后无法在本地应用直接 Ctrl+V 粘贴的问题。通过安装并配置 autocutsel，把 PRIMARY 选择区与 CLIPBOARD 自动桥接，并支持当前会话立即生效。适用于“Remmina 里能复制但外面贴不出来”“X11 下远程桌面选中文本后本地剪贴板没更新”“想把这个修复做成登录后自动生效”的场景。
---

# Remmina X11 Clipboard Bridge

## Overview

这个 skill 用于修复 Linux `X11` 会话里常见的 Remmina 剪贴板桥接问题。

典型现象：
- 在 Remmina 远程桌面里复制了文本
- 切回本地应用后 `Ctrl+V` 没有内容，或者还是旧内容
- 但如果启用 `PRIMARY -> CLIPBOARD` 桥接后，问题立刻消失

核心原因通常不是 Remmina 配置错了，而是：
- 远程桌面或 X11 应用把文本放进了 `PRIMARY`
- 本地应用 `Ctrl+V` 读取的是 `CLIPBOARD`
- 两者默认不同步

默认修复方案：
- 安装 `autocutsel`
- 登录桌面后自动启动两条桥接：
  - `autocutsel -fork`
  - `autocutsel -selection PRIMARY -buttonup -fork`
- 当前会话立即启动，无需重登即可验证

## 何时使用

- 用户说“Remmina 里复制的文本贴不到外面”
- 用户说“X11 下远程桌面里选中的文本不能同步到本地剪贴板”
- 用户说“要把 PRIMARY 和 CLIPBOARD 自动同步”
- 用户说“想装一个长期稳定的剪贴板桥接方案”

## 何时不要使用

- 当前会话不是 `X11`
- 问题发生在 Wayland，而不是 X11
- 用户的问题是“本地复制可以贴出去，但远端收不到”，那更可能是远端 RDP/VNC 剪贴板通道故障
- 用户明确不允许安装系统包或写入 `~/.config/autostart`

## 标准工作流

### 1. 先做只读确认

先确认这是 X11 + Remmina + 剪贴板不同步，不要一上来就改。

```bash
printf 'XDG_SESSION_TYPE=%s\nWAYLAND_DISPLAY=%s\nDISPLAY=%s\n' \
  "$XDG_SESSION_TYPE" "$WAYLAND_DISPLAY" "$DISPLAY"

remmina --version

rg -n 'disableclipboard=|protocol=' "$HOME/.local/share/remmina"/*.remmina 2>/dev/null
```

判断要点：
- `XDG_SESSION_TYPE=x11`
- Remmina 连接配置里 `disableclipboard=0`
- 但用户仍然描述“远端复制，本地 Ctrl+V 无效”

### 2. 安装并配置 autocutsel

直接运行安装脚本：

```bash
/home/ivan/github/my-skills-repo/remmina-x11-clipboard-bridge/scripts/install_autocutsel_bridge.sh
```

脚本会完成：
- 检查 `DISPLAY` 和 `XAUTHORITY`
- 安装 `autocutsel`
- 写入 `~/.config/autostart/autocutsel.desktop`
- 在当前图形会话里立即启动桥接
- 输出验证提示

### 3. 立即验证

修复后让用户立刻测试：

1. 在 Remmina 里复制一段文本
2. 切回本地应用
3. 按 `Ctrl+V`

如果这时能贴出来，基本就坐实是 `PRIMARY/CLIPBOARD` 不同步问题。

### 4. 登录后持久化验证

让用户在下次登录图形桌面后再次测试。

若要确认进程：

```bash
pgrep -af autocutsel
```

期望看到至少两条：
- `autocutsel -fork`
- `autocutsel -selection PRIMARY -buttonup -fork`

## 结果解释

- 当前会话立刻恢复：说明问题就是 X11 剪贴板桥接缺失
- 当前会话无变化：优先怀疑不是 `PRIMARY/CLIPBOARD` 问题，而是远端桌面通道、远端系统剪贴板服务、或用户根本没有执行真正的 Copy 动作
- 登录后又失效：优先检查 `~/.config/autostart/autocutsel.desktop` 是否存在，以及桌面环境是否禁用了 autostart

## 回滚

如果用户要撤销：

```bash
pkill -f 'autocutsel -selection PRIMARY -buttonup -fork' || true
pkill -f 'autocutsel -fork' || true
rm -f "$HOME/.config/autostart/autocutsel.desktop"
```

如需卸载系统包：

```bash
sudo apt-get remove autocutsel
```

## Files

- `scripts/install_autocutsel_bridge.sh`: 安装 `autocutsel`、写入 autostart、当前会话立即启动
