# Linux Auto Shutdown Triage Command Checklist

## 1. 锁定时间线

```bash
date
uptime -s
who -b
last -x | head -n 30
```

判读：
- `last -x` 里有 `shutdown system down`，通常是正常关机链。
- 只有 `crash` 而没有对应关机记录，才更像异常中断或日志缺失。

## 2. 排除定时任务

```bash
systemctl list-timers --all --no-pager
crontab -l
sudo sed -n '1,200p' /etc/crontab
sudo rg -n "shutdown|poweroff|reboot" /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/systemd/system
atq
```

## 3. 排除手动 `sudo shutdown/reboot`

```bash
sudo rg -n "COMMAND=/usr/sbin/(shutdown|reboot)" /var/log/auth.log*
rg -n "shutdown -h now|reboot" ~/.bash_history
```

判读：
- `auth.log` 的 `TTY=pts/...` 往往说明是交互式终端触发。
- `~/.bash_history` 只能作为旁证，不能替代日志时间线。

## 4. 检查 GNOME 电源策略

```bash
gsettings list-recursively org.gnome.settings-daemon.plugins.power | rg "sleep-inactive|lid-close|power-button-action|idle-dim"
gsettings get org.gnome.desktop.session idle-delay
```

常见止血：

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
```

## 5. 检查 live `GNOME` 会话和桌面拓扑

```bash
loginctl list-sessions --no-legend
loginctl show-session <session-id> -p Name -p Service -p Type -p Class -p State -p Remote -p Display -p Seat
sudo sed -n '1,160p' /etc/gdm3/custom.conf
pgrep -a -f "gnome-shell|gsd-power|xfce4-session|xfce4-power-manager|xrdp|xrdp-sesman"
systemctl is-active gdm.service xrdp.service xrdp-sesman.service
```

判读：
- 远程 `xrdp + XFCE` 和本地 `gdm-autologin` 的 `GNOME` 可以并存。
- 如果日志显示系统进入 `suspend`，而 `XFCE` 配置干净，要优先查并存的本地 `GNOME` 会话。

## 6. 通过 live session bus 校验 `GNOME` 的实际生效值

```bash
TARGET_USER=nx
TARGET_UID="$(id -u "${TARGET_USER}")"
sudo -u "${TARGET_USER}" env \
  XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
  gsettings list-recursively org.gnome.settings-daemon.plugins.power \
  | rg "sleep-inactive|lid-close|power-button-action|idle-dim"
```

live session 止血：

```bash
TARGET_USER=nx
TARGET_UID="$(id -u "${TARGET_USER}")"
sudo -u "${TARGET_USER}" env \
  XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
```

判读：
- 普通 shell 里的 `gsettings` 只能作参考，不一定等于当前图形会话真正生效的值。
- live bus 回读仍是 `suspend`，就说明之前那次“已经关掉”的操作没有真正落到当前会话。

## 7. 检查 XFCE 电源策略

```bash
xfconf-query -c xfce4-power-manager -lv
sed -n '1,120p' ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
sudo sed -n '1,120p' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
```

判读：
- 用户 XML 里 `power-button-action` 为空，不代表没配置；运行态可能仍回退到系统默认值。
- 应同时看 `xfconf-query` 实时值和系统默认 XML。

## 8. 检查 logind 和睡眠配置

```bash
sudo sed -n '1,200p' /etc/systemd/logind.conf
sudo rg -n "IdleAction|HandlePowerKey|HandleLidSwitch" /etc/systemd/logind.conf /etc/systemd/logind.conf.d
sudo sed -n '1,200p' /etc/systemd/sleep.conf
sudo rg -n "SuspendState|Hibernate|Sleep" /etc/systemd/sleep.conf /etc/systemd/sleep.conf.d
```

## 9. 查异常附近日志

```bash
sudo rg -n "shutdown|reboot|suspend|hibernate|power key|lid|watchdog|thermal|panic|oom" /var/log/syslog /var/log/kern.log /var/log/auth.log
journalctl --since "YYYY-MM-DD HH:MM:SS" --until "YYYY-MM-DD HH:MM:SS"
```

如果没有持久化 journal：
- 当前 boot 之外的 `journalctl -b -1` 可能拿不到任何东西。
- 这时更要先补 `journald` 持久化。

## 10. 开启开机自动取证

```bash
bash scripts/boot_capture.sh --report-root /var/log/auto-shutdown-monitor/reports
sudo install -m 0755 scripts/boot_capture.sh /usr/local/sbin/boot_capture_auto_shutdown.sh
cat <<'EOF' | sudo tee /etc/systemd/system/auto-shutdown-boot-capture.service >/dev/null
[Unit]
Description=Capture boot evidence for unexpected shutdowns
After=systemd-journald.service multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/boot_capture_auto_shutdown.sh --report-root /var/log/auto-shutdown-monitor/reports --user nx

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now auto-shutdown-boot-capture.service
```

判读：
- 取证不是根因修复，但它能保证下次异常后第一时间落盘 `journal-previous-boot.log`、`watchdog.log`、`pstore-list.log`、`session-topology.log`。

## 11. 开启持久化 journald

```bash
sudo install -d -m 0755 /etc/systemd/journald.conf.d
printf '%s\n' '[Journal]' 'Storage=persistent' | sudo tee /etc/systemd/journald.conf.d/99-persistent.conf >/dev/null
sudo install -d -m 2755 -o root -g systemd-journal /var/log/journal
sudo systemctl restart systemd-journald
journalctl --list-boots
```

## 12. 对只需要 `XRDP + XFCE` 的机器做双保险

```bash
sudo systemctl disable --now gdm.service
sudo systemctl set-default multi-user.target
systemctl is-active gdm.service
systemctl get-default
```

判读：
- 这是“移除本地 `GNOME` 自动登录会话”的做法，适合 headless 或只靠远程桌面的机器。
- 如果本机物理显示器仍要直接进桌面，就不要用这一步。
