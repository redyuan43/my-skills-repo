# Boot Capture Notes

## 目标

在“机器自己消失、重启后第一现场已经没了”的场景里，把上一次 boot 的关键证据在新 boot 一开始就落盘。

这套取证特别适合以下情况：
- 已经开启了持久化 `journald`
- 需要长期蹲守异常重启
- 怀疑 `watchdog`、`suspend/resume`、`pstore`、供电或本地 `GNOME` 会话在作怪

## 脚本能力

`scripts/boot_capture.sh` 会落盘这些内容：
- 时间线：`last -x`、`journalctl --list-boots`
- 上一轮 boot：`journal-previous-boot.log`
- 关键过滤日志：`journal-focus.log`
- `watchdog` 快照：`watchdog.log`
- `pstore` 快照：`pstore-list.log`
- 电源传感器快照：`voltage-snapshot.log`
- 桌面会话拓扑：`session-topology.log`
- live `GNOME` 电源配置：`gnome-live-power.log`

## 手动执行

```bash
bash scripts/boot_capture.sh --report-root /var/log/auto-shutdown-monitor/reports --user nx
```

如果只想先试跑，不一定要放到 `systemd`：
- 先确认 `summary.md`、`journal-previous-boot.log`、`watchdog.log` 都能生成
- 再决定是否装开机 service

## 作为 systemd service 安装

先把脚本放到稳定路径：

```bash
sudo install -m 0755 scripts/boot_capture.sh /usr/local/sbin/boot_capture_auto_shutdown.sh
```

然后写 service：

```ini
[Unit]
Description=Capture boot evidence for unexpected shutdowns
After=systemd-journald.service multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/boot_capture_auto_shutdown.sh --report-root /var/log/auto-shutdown-monitor/reports --user nx

[Install]
WantedBy=multi-user.target
```

启用：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now auto-shutdown-boot-capture.service
```

## 判读要点

- `journal-previous-boot.log` 里出现 `Starting System Suspend`、`Entering sleep state 'suspend'`，比“自动关机”更说明问题在挂起链路。
- `session-topology.log` 能直接看出是否同时存在本地 `GNOME` 和远程 `XRDP/XFCE`。
- `gnome-live-power.log` 为空或提示没有 `/run/user/<uid>/bus`，说明当次 boot 没有该用户的 live 图形会话，不能拿它做 `GNOME` 配置直证。
- `watchdog.log` 只说明当前 boot 的配置和探针状态；如果没有 `timeout`、`bite` 这类字样，不要直接把锅甩给 `watchdog`。
- `voltage-snapshot.log` 里的传感器值只能当线索，不能单独当根因证据。
