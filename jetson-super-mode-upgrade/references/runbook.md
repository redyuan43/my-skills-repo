# Jetson Super Mode Upgrade Runbook

## 适用范围

- Jetson Orin Nano / Orin NX
- 已安装支持 Super Mode 的 JetPack / L4T
- 本机已经能看到 `*_super.conf`、`*-nv-super.dtb` 或 `*super*.Cap`

## 0. 基线采集

```bash
jetson_release -v
sudo nvbootctrl dump-slots-info
tr -d '\0' < /proc/device-tree/compatible ; echo
readlink -f /etc/nvpmodel.conf
cat /sys/devices/platform/17000000.gpu/devfreq_dev/available_frequencies
sudo nvpmodel -q --verbose
sudo jetson_clocks --show
```

重点看三件事：

- 运行中的 bootloader 版本是不是旧版本。
- 当前设备树是不是已经带 `-super`。
- GPU 频率表是不是仍只到 `918000000`。

## 1. 先确认 super 工件是否齐全

```bash
ls /etc/nvpmodel/*super*.conf
ls /boot/*super*.dtb
ls /opt/ota_package/t23x/*super*.Cap
```

如果这里已经缺文件，不要继续做启动链切换，先确认系统版本。

## 2. 可选：做一次运行时试切

只在需要证明“不是 `nvpmodel` 命令写错了”时做。

```bash
SUPER_CONF="$(ls /etc/nvpmodel/*super*.conf | head -n 1)"
NORMAL_CONF="$(readlink -f /etc/nvpmodel.conf)"
sudo nvpmodel -f "$SUPER_CONF" -m 4
sudo jetson_clocks
sudo nvpmodel -q --verbose -f "$SUPER_CONF"
cat /sys/devices/platform/17000000.gpu/devfreq_dev/max_freq
```

如果这时 GPU 仍没抬频，说明问题不在运行时命令。

恢复示例：

```bash
sudo nvpmodel -f "$NORMAL_CONF" -m 0
```

## 3. 第一阶段：切到 Super DTB

先备份：

```bash
sudo cp /boot/extlinux/extlinux.conf \
  /boot/extlinux/extlinux.conf.pre-super-$(date +%Y%m%d-%H%M%S)
```

关键原则：

- 保留原有 `LABEL primary`
- 新增 `LABEL super`
- `DEFAULT super`
- `FDT` 指向 `*-nv-super.dtb`

修改后重启一次。

## 4. 第一次重启后的检查

```bash
tr -d '\0' < /proc/device-tree/compatible ; echo
readlink -f /etc/nvpmodel.conf
sudo nvpmodel -q --verbose
cat /sys/devices/platform/17000000.gpu/devfreq_dev/available_frequencies
sudo nvbootctrl dump-slots-info
```

典型“半成功”现象：

- `compatible` 已经变成 `...-super`
- `nvpmodel` 已是 `MAXN_SUPER`
- 但 `available_frequencies` 仍只有到 `918000000`
- `nvbootctrl dump-slots-info` 的 `Current version` 仍是旧 bootloader

这说明 DTB 已经切对，但 super capsule 还没有真正应用。

## 5. 第二阶段：切 `nv_boot_control` 到 super

先备份：

```bash
mkdir -p /tmp/jetson_bootloader_super_backup
sudo cp /etc/nv_boot_control.conf /tmp/jetson_bootloader_super_backup/nv_boot_control.conf.$(date +%Y%m%d-%H%M%S)
```

查看当前规格：

```bash
grep -E '^(TNSPEC|COMPATIBLE_SPEC)' /etc/nv_boot_control.conf
```

经验点：

- 在 `p3767` devkit 上，普通规格里即便写着 `jetson-orin-nano-devkit`，也可能对应 Orin NX 模块。
- 不要自行把板型名“脑补纠正”为别的字符串。
- 应该基于当前值切到同一族的 `*-super-` 变体。

同步 EFI 平台规格：

```bash
sudo /opt/nvidia/l4t-bootloader-config/nv-l4t-bootloader-config.sh -l
```

## 6. 触发 super capsule 更新

```bash
sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure nvidia-l4t-bootloader
```

期望看到类似输出：

- `Starting bootloader post-install procedure.`
- `Trigger Capsule update is done.`
- `Reboot the target system for updates to take effect.`

然后再重启一次。

## 7. 第二次重启后的最终验收

```bash
sudo nvbootctrl dump-slots-info
tr -d '\0' < /proc/device-tree/compatible ; echo
readlink -f /etc/nvpmodel.conf
cat /sys/devices/platform/17000000.gpu/devfreq_dev/available_frequencies
sudo nvpmodel -m 0
sudo jetson_clocks
sudo nvpmodel -q --verbose
sudo jetson_clocks --show
```

理想结果：

- `Current version` 已切到目标 bootloader 版本
- 频率表出现 `1020000000` / `1122000000` / `1173000000`
- `MAXN_SUPER` 生效
- `jetson_clocks --show` 中 GPU 已锁到新的高频上限

## 8. 回滚

1. 恢复 `/boot/extlinux/extlinux.conf` 备份，或者把默认项改回 `primary`
2. 恢复 `/etc/nv_boot_control.conf` 备份
3. 重新运行：

```bash
sudo /opt/nvidia/l4t-bootloader-config/nv-l4t-bootloader-config.sh -l
sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure nvidia-l4t-bootloader
```

4. 重启并重新检查 `compatible`、`nvbootctrl dump-slots-info` 与 GPU 频率表

## 9. 最容易踩坑的地方

- `nvpmodel` 显示 Super，不代表真的 Super。
- 包版本升级到新版本，不代表运行中的 bootloader 已更新。
- 只改 `extlinux` 不改 `COMPATIBLE_SPEC`，常见结果是“看起来是 Super，GPU 还是 918 MHz”。
- 只跑 `jetson_clocks` 无法突破频率表上限。
