---
name: jetson-display-stack-repair
description: 排查和修复 Jetson 上 GNOME/Weston 图形栈启动失败、黑屏或登录界面不显示。用于 `graphical.target` 不生效、`display-manager.service` 缺失或失效、`gdm3` 不启动、`nvweston` 抢占 DRM、Xorg 报 `drmSetMaster failed`、显示器有信号但桌面不起的场景。
---

# Jetson Display Stack Repair

## Overview

先判断是启动目标、显示管理器，还是 DRM/Xorg 设备冲突。优先修复 `gdm3` / `display-manager.service` / `nvweston.service` 的启动链，再处理显卡和显示器链路。

## Workflow

1. 先确认图形启动链是否完整。
- `systemctl get-default` 应为 `graphical.target`。
- `systemctl status display-manager.service gdm.service gdm3.service` 应能定位到 `gdm3`。
- `/etc/X11/default-display-manager` 应指向 `/usr/sbin/gdm3`。

2. 再找是否有 Weston 或其他图形服务抢占 DRM。
- 查 `systemctl is-enabled nvweston.service` 和 `systemctl list-dependencies graphical.target`。
- 如果日志里有 `drmSetMaster failed: Device or resource busy`，先处理服务冲突，不要先改驱动。
- Jetson 上常见根因是 `nvweston.service` 仍挂在 `multi-user.target.wants`，与 `gdm3` 同时抢卡。

3. 如果目标是 GNOME 桌面，按这个顺序修复。
- 禁用并停止 `nvweston.service`。
- 恢复 `display-manager.service` 指向 `gdm.service`。
- 重新加载 systemd，然后启动 `display-manager.service`。
- 只在 `gdm3` 已正常拉起后，再考虑重启验证。

4. 如果仍然黑屏，再看 Xorg 和硬件链路。
- 检查 `/var/log/Xorg.0.log` 中的输出设备、EDID、connected/disconnected、`(EE)`。
- 只有在图形服务已独占 DRM 后，才继续判断线材、接口、EDID 或 `xorg.conf`。

## Validation

- `gdm.service` 应为 `active (running)`。
- `ps -eo pid,cmd | rg 'gdm|Xorg|gnome-shell|Xwayland|weston'` 应能看到 GNOME 会话，而不是只有守护进程。
- 日志里不应再持续出现 `drmSetMaster failed`、`Device or resource busy`，或者 `gdm3` 启动后立即退出。

## Resources

- See [references/jetson-display-stack-repair.md](references/jetson-display-stack-repair.md) for the exact command sequence and log patterns.
