---
name: linux-auto-shutdown-triage
description: 排查 Linux 机器“过一会儿自动关机、自动重启、像关机一样消失”的问题。用于区分计划任务、手动 `shutdown/reboot`、GNOME/XFCE 电源策略、电源键/合盖动作、挂起与真正关机，并在需要时执行止血：关闭自动挂起、关闭电源键动作、开启持久化 journald 日志。
---

# Linux Auto Shutdown Triage

## Overview

先判断问题是“真正关机/重启”，还是“挂起/黑屏被误认为关机”。优先收集证据，再决定是否执行止血配置。

## Workflow

1. 先做事实基线。
- 记录当前时间、时区、最近一次开机时间。
- 查 `last -x`、`uptime -s`、`who -b`，先锁定异常发生的大致时间。

2. 先排除“定时自动关机”。
- 查 `systemctl list-timers --all`、`crontab -l`、`/etc/crontab`、`/etc/cron.*`、`atq`。
- 搜索 `shutdown`、`poweroff`、`reboot`、`systemctl poweroff`、`systemctl reboot`，不要凭感觉判断。

3. 再排除“手动触发”。
- 查 `/var/log/auth.log` 中是否有 `sudo` 执行 `/usr/sbin/shutdown`、`/usr/sbin/reboot`。
- 对照 shell 历史，但历史只能证明“执行过”，不能单独证明“这一次就是它导致的”。

4. 区分挂起路径和关机路径。
- `GNOME` 重点看 `org.gnome.settings-daemon.plugins.power` 的 `sleep-inactive-*`、`lid-close-*`、`power-button-action`。
- `XFCE` 重点看 `xfce4-power-manager` 的 `power-button-action` 和用户配置是否回退到系统默认值。
- `logind` 重点看 `/etc/systemd/logind.conf` 和 drop-in，尤其是 `IdleAction`。

5. 看最近一次异常附近的日志。
- 若无持久化 journal，先结合 `/var/log/syslog`、`/var/log/kern.log`、`/var/log/auth.log` 和 `last -x`。
- 重点搜索：`shutdown`、`reboot`、`suspend`、`hibernate`、`power key`、`lid`、`watchdog`、`thermal`、`panic`、`oom`。
- 如果最近一次异常就在当前时间附近，但查不到 `sudo shutdown/reboot`，那“用户手动关机”概率就会明显下降。

6. 需要止血时，只改真正有风险的项。
- 关闭 `GNOME` 的空闲挂起：把 `sleep-inactive-ac-type`、`sleep-inactive-battery-type` 设为 `nothing`，超时设为 `0`。
- 关闭 `GNOME` 的合盖挂起：把 `lid-close-ac-action`、`lid-close-battery-action` 设为 `nothing`。
- 关闭 `GNOME` 的电源键动作：`power-button-action='nothing'`。
- 关闭 `XFCE` 的电源键动作时，要同时改当前 `xfconf` 值和落盘 XML，避免“用户配置为空时回退到系统默认值”。

7. 最后补上持久化日志。
- 创建 `/var/log/journal`。
- 用 `/etc/systemd/journald.conf.d/` drop-in 显式设置 `Storage=persistent`。
- 重启 `systemd-journald` 后，用 `journalctl --list-boots` 验证。

## Validation

- `gsettings list-recursively org.gnome.settings-daemon.plugins.power` 应显示相关动作已改成 `nothing` 或超时为 `0`。
- `xfconf-query -c xfce4-power-manager -lv` 应显示 `power-button-action` 已改为安全值。
- `journalctl --list-boots` 应能列出持久化 boot 记录。
- 若问题再次发生，应优先回看异常时间附近的 `journalctl -b -1` 或对应 boot 日志。

## Safety Rules

- 修改系统电源策略或 `journald` 配置前，先确认用户同意。
- 如果仓库或系统里已有用户自定义的电源配置，不要直接覆盖，先读清楚来源和回退关系。
- 没有直接日志证据时，要明确写“这是推断，不是直证”。

## Resources

- 需要具体命令和判读关键词时，读 [references/command-checklist.md](references/command-checklist.md)。
