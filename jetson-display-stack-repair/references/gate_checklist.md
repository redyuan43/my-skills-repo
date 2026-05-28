# Gate Checklist

## 状态 Gate

- 先采集 `systemctl get-default`、display-manager 状态、`nvweston.service` 状态和图形日志。
- 先判断是启动目标、显示管理器还是 DRM/Xorg 冲突，不凭黑屏现象直接改服务。
- 日志中出现 `drmSetMaster failed` 时，优先核对是否有 Weston 抢占 DRM。

## 修改 Gate

- 禁用、停止、重启任何 systemd 服务前必须获得用户明确确认。
- 修改 `/etc/X11/default-display-manager` 或 display-manager symlink 前必须备份并说明影响。
- 不在未确认目标桌面是 GNOME/GDM 的机器上套用修复。

## 回滚 Gate

- 保留 display-manager 和 `nvweston.service` 的原启用状态。
- 如果 GDM 修复失败，恢复原 display-manager 指向和服务启用状态。
- 回滚后再次读取日志，确认没有引入新的启动循环。
