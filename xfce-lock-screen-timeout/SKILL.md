---
name: xfce-lock-screen-timeout
description: 在 XFCE 桌面中检查并设置空闲锁屏时间，优先识别 `xfce4-screensaver` 和当前 X11 会话 `xset` 的实际生效层；适用于用户要求“把 XFCE 锁屏时间改成一小时/30 分钟”、需要查看当前锁屏超时，或发现图形界面设置了但实际不生效的场景。
---

# XFCE Lock Screen Timeout

当用户要求修改 `XFCE` 的锁屏时间时，先确认当前会话的实际锁屏组件，再同时更新持久化配置和当前会话超时。

## 适用边界

- 这个 skill 面向 `xfce4-screensaver` 管理锁屏的 `XFCE` 桌面。
- 如果实际运行的是 `light-locker`、`xscreensaver` 或其他锁屏器，不要直接套这个 skill，先汇报当前锁屏组件。
- 需要在图形会话内执行；至少应有 `DISPLAY`，通常也应保留 `DBUS_SESSION_BUS_ADDRESS`。

## 标准工作流

1. 先确认桌面和锁屏组件：

```bash
printenv XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION DISPLAY DBUS_SESSION_BUS_ADDRESS
pgrep -af "xfce4-screensaver|light-locker|xfce4-power-manager"
```

2. 先看当前状态：

```bash
bash xfce-lock-screen-timeout/scripts/set_xfce_lock_screen_timeout.sh --status
```

3. 设置为 60 分钟空闲后立刻锁屏：

```bash
bash xfce-lock-screen-timeout/scripts/set_xfce_lock_screen_timeout.sh --minutes 60
```

4. 如果需要其他时间，改成对应分钟数：

```bash
bash xfce-lock-screen-timeout/scripts/set_xfce_lock_screen_timeout.sh --minutes 30
bash xfce-lock-screen-timeout/scripts/set_xfce_lock_screen_timeout.sh --minutes 120
```

5. 验证结果：

```bash
xfconf-query -c xfce4-screensaver -lv
xset q | sed -n '/Screen Saver:/,/Colors:/p'
```

## 关键判断

- `xfce4-power-manager` 不是这类“空闲多久后锁屏”的主配置入口，不要只改它。
- 实际需要同时处理两层：
  - `xfce4-screensaver` 的持久化配置，保证重登后仍然保持。
  - 当前 X11 会话的 `xset` 超时，保证现在立刻生效。
- 这次经验里，真正起作用的是：
  - `/saver/idle-activation/delay`
  - `/lock/enabled`
  - `/lock/saver-activation/enabled`
  - `/lock/saver-activation/delay`
  - `xset s <seconds> <cycle>`

## 手工兜底命令

如果只需要临时手工改成“1 小时后立刻锁屏”，可以直接执行：

```bash
xfconf-query -c xfce4-screensaver -n -t bool -p /saver/enabled -s true
xfconf-query -c xfce4-screensaver -n -t bool -p /saver/idle-activation/enabled -s true
xfconf-query -c xfce4-screensaver -n -t int -p /saver/idle-activation/delay -s 3600
xfconf-query -c xfce4-screensaver -n -t bool -p /lock/enabled -s true
xfconf-query -c xfce4-screensaver -n -t bool -p /lock/saver-activation/enabled -s true
xfconf-query -c xfce4-screensaver -n -t int -p /lock/saver-activation/delay -s 0
xset s 3600 300
```

## 文件

- `scripts/set_xfce_lock_screen_timeout.sh`：查看当前状态，或把空闲锁屏时间改成指定分钟数。
