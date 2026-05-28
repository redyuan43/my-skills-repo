---
name: jetson-super-mode-upgrade
description: 在 Jetson Orin Nano / Orin NX 上启用并验证真正可用的 Super Mode。用于系统里已经有 `*_super.conf`、`nv-super.dtb` 或 super capsule，但仅靠 `nvpmodel` 切换并没有真正提频、GPU 频率仍停在 `918000000`，需要补齐 extlinux Super DTB、`nv_boot_control.conf` Super 规格、bootloader capsule 更新、双重启验收与回滚路径的场景。
---

# Jetson Super Mode Upgrade

## Overview

先区分“伪 Super”和“真 Super”。在 Orin Nano / NX 上，单纯执行 `nvpmodel -m` 或临时指定 `*_super.conf`，经常只会让界面显示成 `40W` 或 `MAXN_SUPER`，但 GPU 频率表仍然没有放出更高档位。

真正可用的 Super Mode，通常需要同时满足这几层：

1. 启动链已经切到 `nv-super.dtb`。
2. `/etc/nv_boot_control.conf` 与 EFI 的 `TegraPlatformCompatSpec` 已切到 `*-super-` 规格。
3. `nvidia-l4t-bootloader` 已经实际应用了 super capsule，而不是只把包升级到了磁盘上。
4. 重启后 GPU 频率表真的出现更高档位，再用 `MAXN_SUPER + jetson_clocks` 锁上去。

## Workflow

1. 先做事实基线，不要凭 `nvpmodel` 字样判断是否成功。
- 优先先跑 `python3 scripts/check_jetson_super_mode.py`，让脚本先把当前状态判成 `NORMAL_MODE`、`RUNTIME_ONLY_OR_PENDING_REBOOT`、`SUPER_DTB_ONLY`、`SUPER_READY_NOT_PINNED` 或 `FULL_SUPER`。
- 记录 `jetson_release -v`、`sudo nvbootctrl dump-slots-info`、`tr -d '\0' < /proc/device-tree/compatible`。
- 记录 `readlink -f /etc/nvpmodel.conf`、`cat /sys/devices/platform/17000000.gpu/devfreq_dev/available_frequencies`、`sudo jetson_clocks --show`。
- 如果 GPU 可用频率仍只到 `918000000`，那还不是真正的 Super Mode。

2. 先确认系统里有没有 super 相关工件。
- 查 `/etc/nvpmodel/*super*.conf`、`/boot/*super*.dtb`、`/opt/ota_package/t23x/*super*.Cap`。
- 如果这些文件都不存在，优先确认 JetPack / L4T 是否已经升级到支持 Super Mode 的版本，再谈切换。

3. 可选做一次“运行时试切”，用来证明问题不在 `nvpmodel` 命令本身。
- 临时指定 super 配置执行 `sudo nvpmodel -f <super-conf> -m <mode>`，再看 `available_frequencies` 和 `gpu max_freq`。
- 如果界面显示成 `40W` 或 `MAXN_SUPER`，但 GPU 上限没变，甚至 CPU 上限下降，不要把机器停留在这个状态，先恢复原配置。
- 这一步的价值是快速判断“缺的是启动链/bootloader”，而不是继续在运行时命令上兜圈子。

4. 第一阶段先切 Super DTB，而不是一上来就刷整机。
- 备份 `/boot/extlinux/extlinux.conf`。
- 保留原有 `primary` 启动项，再新增一个 `super` 启动项，`FDT` 指向对应的 `*-nv-super.dtb`。
- 把 `DEFAULT` 改成 `super`，但不要删除原来的 `primary`，这样启动异常时还有明确回退入口。

5. 第一次重启后，验证“软件链路”有没有进入 Super 路线。
- `compatible` 应出现 `...-super`。
- `readlink -f /etc/nvpmodel.conf` 应切到对应的 `*_super.conf`。
- 这时如果 `nvpmodel` 已经显示 `MAXN_SUPER`，但 GPU 频率表仍然只有到 `918000000`，通常说明 DTB 已经对了，真正缺的是 bootloader super capsule 尚未应用。

6. 第二阶段处理 bootloader 规格，而不是只看磁盘上安装包版本。
- 重点看 `sudo nvbootctrl dump-slots-info` 的 `Current version`，它代表当前真正运行中的 bootloader，不等于 `dpkg -l` 里包已经升级。
- 同时检查 `/etc/nv_boot_control.conf` 里的 `TNSPEC` 和 `COMPATIBLE_SPEC`。如果还是普通规格，`dpkg-reconfigure nvidia-l4t-bootloader` 仍可能选到普通 capsule。
- 在 `p3767` 家族 devkit 上，即使机器是 Orin NX，普通规格字符串也可能仍是 `jetson-orin-nano-devkit-`。不要凭直觉乱改设备名，应该基于当前值切到匹配的 `*-super-` 变体。

7. 把 `nv_boot_control` 和 EFI 平台规格一起切到 super。
- 先备份 `/etc/nv_boot_control.conf` 和当前 EFI 变量。
- 把 `TNSPEC` / `COMPATIBLE_SPEC` 调整为与当前板型匹配的 `*-super-` 规格。
- 再运行 `sudo /opt/nvidia/l4t-bootloader-config/nv-l4t-bootloader-config.sh -l`，让 EFI 的 `TegraPlatformCompatSpec` 同步过去。
- 经验上，真正决定 `postinst` 选普通 capsule 还是 super capsule 的关键是 `COMPATIBLE_SPEC`，不是肉眼觉得“我已经换了 super DTB”。

8. 触发 super capsule 更新，再做第二次重启。
- 执行 `sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure nvidia-l4t-bootloader`。
- 重点观察输出里是否出现 `Trigger Capsule update is done` 这类成功信息。
- 如果这个步骤走的是 super 规格，下一次重启后运行中的 bootloader 版本才会真正切到新的 super 路线。

9. 第二次重启后再做最终验收。
- `sudo nvbootctrl dump-slots-info` 的 `Current version` 应和当前安装包预期一致。
- `available_frequencies` 应出现更高 GPU 档位，例如 `1020000000`、`1122000000`、`1173000000`。
- 再执行 `sudo nvpmodel -m 0` 和 `sudo jetson_clocks`，确认 `MAXN_SUPER` 下 GPU 已能锁到新的上限。

## Script

- 快速检查当前状态：`python3 scripts/check_jetson_super_mode.py`
- 需要机器可读结果时：`python3 scripts/check_jetson_super_mode.py --json`
- 这个脚本是只读诊断，不会改 `extlinux`、`nv_boot_control.conf`、`nvpmodel` 或 bootloader。
- 推荐用法是每次重启后先跑一遍，用脚本先判定自己现在处在第几阶段，再决定是否继续往下走。

## Validation

- `tr -d '\0' < /proc/device-tree/compatible` 中包含 `-super`。
- `readlink -f /etc/nvpmodel.conf` 指向 `*_super.conf`。
- `sudo nvbootctrl dump-slots-info` 的 `Current version` 已更新到目标 bootloader 版本。
- `cat /sys/devices/platform/17000000.gpu/devfreq_dev/available_frequencies` 不再只到 `918000000`。
- `sudo nvpmodel -q --verbose` 显示 `MAXN_SUPER`。
- `sudo jetson_clocks --show` 显示 GPU `MinFreq` / `MaxFreq` 已锁到新的高档位。

## Rollback

1. 先把 `extlinux` 默认启动项切回 `primary`，必要时恢复备份的 `/boot/extlinux/extlinux.conf`。
2. 恢复 `/etc/nv_boot_control.conf` 备份，并重新运行 `nv-l4t-bootloader-config.sh -l`。
3. 再次执行 `dpkg-reconfigure nvidia-l4t-bootloader`，让系统重新准备普通 capsule。
4. 重启后确认 `compatible`、`/etc/nvpmodel.conf`、`nvbootctrl dump-slots-info` 和 GPU 频率表都回到普通模式。

## Safety Rules

- 修改 `/boot/extlinux/extlinux.conf` 前，必须先做备份并保留可回退的 `primary` 启动项。
- 修改 `/etc/nv_boot_control.conf`、EFI 规格变量、触发 capsule 更新或安排重启前，必须得到用户明确确认。
- 不要把“`nvpmodel` 显示成 Super”误判为真正成功；频率表和运行中的 bootloader 版本才是硬指标。
- 如果第一次重启后只是进入了 `super dtb`，但 GPU 仍卡在 `918000000`，不要反复试 `jetson_clocks`，应转去检查 `COMPATIBLE_SPEC` 和 capsule 更新路径。
- 不要删除或覆盖用户已有的启动项，只做可逆增量修改。

## Resources

- 需要具体命令顺序、检查点和回滚示例时，读 [references/runbook.md](references/runbook.md)。
- 需要半自动检查当前状态时，运行 [scripts/check_jetson_super_mode.py](scripts/check_jetson_super_mode.py)。
- 状态、修改和回滚 gate 见 [references/gate_checklist.md](references/gate_checklist.md)。
- 已拒绝的过度修改方向见 [references/rejected_edits.md](references/rejected_edits.md)。
- 验证样例见 `eval/val/items.json`。

## Selftest

```bash
bash jetson-super-mode-upgrade/scripts/selftest.sh --safe
```

Safe selftest only checks local files, Python syntax, eval JSON, and gate references. It does not modify bootloader, extlinux, EFI, nvpmodel, or reboot.
