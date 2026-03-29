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

## 5. 检查 XFCE 电源策略

```bash
xfconf-query -c xfce4-power-manager -lv
sed -n '1,120p' ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
sudo sed -n '1,120p' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
```

判读：
- 用户 XML 里 `power-button-action` 为空，不代表没配置；运行态可能仍回退到系统默认值。
- 应同时看 `xfconf-query` 实时值和系统默认 XML。

## 6. 检查 logind 和睡眠配置

```bash
sudo sed -n '1,200p' /etc/systemd/logind.conf
sudo rg -n "IdleAction|HandlePowerKey|HandleLidSwitch" /etc/systemd/logind.conf /etc/systemd/logind.conf.d
sudo sed -n '1,200p' /etc/systemd/sleep.conf
sudo rg -n "SuspendState|Hibernate|Sleep" /etc/systemd/sleep.conf /etc/systemd/sleep.conf.d
```

## 7. 查异常附近日志

```bash
sudo rg -n "shutdown|reboot|suspend|hibernate|power key|lid|watchdog|thermal|panic|oom" /var/log/syslog /var/log/kern.log /var/log/auth.log
journalctl --since "YYYY-MM-DD HH:MM:SS" --until "YYYY-MM-DD HH:MM:SS"
```

如果没有持久化 journal：
- 当前 boot 之外的 `journalctl -b -1` 可能拿不到任何东西。
- 这时更要先补 `journald` 持久化。

## 8. 开启持久化 journald

```bash
sudo install -d -m 0755 /etc/systemd/journald.conf.d
printf '%s\n' '[Journal]' 'Storage=persistent' | sudo tee /etc/systemd/journald.conf.d/99-persistent.conf >/dev/null
sudo install -d -m 2755 -o root -g systemd-journal /var/log/journal
sudo systemctl restart systemd-journald
journalctl --list-boots
```
