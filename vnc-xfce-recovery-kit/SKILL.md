---
name: vnc-xfce-recovery-kit
description: 在 Ubuntu/Linux 上一键恢复可用的 TigerVNC + 完整 XFCE + Chromium(Flatpak) 桌面，并保留可扩展的启动 hook 入口。适用于“VNC 能连但桌面坏了”“XFCE 体验被改坏”“Chromium 打不开”“想要一个可重复执行的恢复脚本”这类场景。
---

# VNC XFCE Recovery Kit

这个技能用于把一台已经跑过 `TigerVNC + XFCE` 的机器恢复到“完整桌面可登录、终端正常、浏览器能开”的状态。

它不是只讲步骤的文档，而是一个可重复执行的恢复脚本：

- 重装 `XFCE`、`dbus`、`selinux-policy-default`
- 补齐 `dbus` 所需的 `SELinux` policy 目录
- 备份并重置坏掉的 `XFCE` 用户配置
- 恢复标准 `~/.vnc/xstartup`
- 刷新 `/etc/systemd/system/vncserver-headless.service`
- 固定默认终端和默认浏览器入口
- 生成启动 hook 目录，方便后续追加自动启动功能

## 适用场景

- `VNC` 端口通，但桌面体验已经被改坏
- `startxfce4` 起不来，日志里出现 `dbus_contexts` 或 `SELinux` 相关错误
- `Chromium` 仍然走坏掉的 `snap` 包装器
- 希望把修复流程收敛成一条以后还能重复跑的脚本

## 一键恢复

脚本需要 `root` 或 `sudo` 权限：

```bash
cd ~/.codex/skills/vnc-xfce-recovery-kit
sudo bash scripts/recover_vnc_xfce.sh
```

默认会：

- 恢复当前 `sudo` 用户的桌面
- 使用 display `:1`
- 使用 `1920x1080`
- 使用 `24-bit`
- 默认终端设为 `gnome-terminal`
- 默认浏览器设为 `chromium`，并把该命令指向 `Flatpak Chromium`

## 常用参数

```bash
sudo bash scripts/recover_vnc_xfce.sh \
  --user nano \
  --display :1 \
  --geometry 1920x1080 \
  --depth 24
```

如果你希望顺带把系统默认目标切到纯命令行并禁用 `gdm3`：

```bash
sudo bash scripts/recover_vnc_xfce.sh \
  --set-multi-user-target \
  --disable-gdm
```

## 启动 hook 扩展点

脚本会创建：

```bash
~/.config/vnc-startup-hooks.d/
```

`xstartup` 会在桌面启动后异步执行这个目录下的所有可执行脚本。

后续如果你想在每次 `VNC` 桌面启动时自动做一些事，例如：

- 启动音频路由
- 自动打开某个应用
- 设置特定分辨率或输入法
- 拉起微信、浏览器或自定义工具

只需要把脚本丢进这个目录并加执行权限：

```bash
chmod +x ~/.config/vnc-startup-hooks.d/my-startup-hook.sh
```

## 已包含的恢复策略

### 1. 标准 XFCE 会话

脚本会把 `~/.vnc/xstartup` 恢复成标准 `startxfce4`，不再使用手搓的最小会话。

### 2. TigerVNC SELinux 绕过

脚本会写入 `~/.vnc/config`：

```text
extension = SELinux
```

这是为了绕开某些机器上 `Xtigervnc` 的 `SELinux` 扩展初始化崩溃。

### 3. Chromium 固定到 Flatpak

脚本会生成 `~/.local/bin/chromium` 包装器，让 `XFCE` 默认浏览器入口走：

```bash
flatpak run org.chromium.Chromium
```

这样可以避开 Ubuntu 上经常不稳定的 `snap chromium` 路径。

## 产物与备份

脚本运行时会把旧配置备份到：

```bash
~/.config/vnc-xfce-recovery-backups/<timestamp>/
```

便于后续回看或手工取回某些配置。

## 参考

- `references/runbook.md`：这次恢复流程的结构化说明和验证点
- `scripts/recover_vnc_xfce.sh`：实际执行恢复的脚本
