# Gate Checklist

## 状态 Gate

- 先运行 `python3 scripts/check_jetson_super_mode.py` 或 `--json`，把状态归类后再继续。
- 记录 `compatible`、`/etc/nvpmodel.conf`、GPU frequency table 和 bootloader 当前版本。
- 只把频率表、bootloader 版本和 Super DTB 同时满足视为真 Super。

## 修改 Gate

- 修改 `/boot/extlinux/extlinux.conf`、`/etc/nv_boot_control.conf`、EFI 规格或触发 capsule 前必须确认。
- 改 `extlinux` 必须先备份，并保留原 `primary` 启动项。
- 触发 bootloader capsule 后必须安排重启验收，不把包版本当成运行中版本。

## 回滚 Gate

- 回滚默认启动项到 `primary`。
- 恢复 `/etc/nv_boot_control.conf` 备份并同步 EFI 平台规格。
- 重启后用只读检查确认 compatible、nvpmodel、bootloader 和 GPU 频率表回到普通模式。
