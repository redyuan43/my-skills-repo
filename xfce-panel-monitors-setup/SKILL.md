---
name: xfce-panel-monitors-setup
description: 在 XFCE 面板上一次性配置 CPU 图表、GPU/RAM 轮播和 IPv4 轮播监控；支持本机执行，也支持通过 SSH 在远端活动图形会话中执行（自动继承 DISPLAY/DBUS 环境），适用于需要快速把同一套状态栏监控部署到多台 Linux 设备的场景。
---

# XFCE Panel Monitors Setup

当用户要在 `XFCE` 状态栏上显示 CPU、GPU、内存和本地 IPv4，并且希望可在多台机器一键部署时，使用这个 skill。

## 功能

- 为 `panel-1` 添加 `cpugraph`（CPU 图表）和两个 `genmon` 项。
- GPU 项轮播显示：`GPU %`、`GMem`、`RAM used/total`。
- IP 项轮播显示：所有非回环 IPv4（逐个轮播，悬停显示完整列表）。
- 自动备份 `xfce4-panel.xml`，重复执行不重复添加插件。

## 标准工作流

1. 本机 XFCE 会话直接执行：

```bash
bash xfce-panel-monitors-setup/scripts/setup-xfce-panel-monitors.sh
```

2. 远端主机（如 `nx1`/`nx2`）通过 SSH 执行时，先从远端 `xfce4-panel` 进程继承图形会话变量再运行：

```bash
ssh nx1 'set -euo pipefail
p=$(pgrep -n xfce4-panel)
envfile=$(mktemp)
tr "\0" "\n" < /proc/$p/environ | grep -E "^(DISPLAY|DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR|XDG_CURRENT_DESKTOP)=" > "$envfile"
set -a
. "$envfile"
set +a
rm -f "$envfile"
bash ~/Desktop/setup-xfce-panel-monitors.sh'
```

3. 验证结果：

```bash
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids
sed -n '1,40p' ~/.config/xfce4/panel/genmon-24.rc 2>/dev/null || true
sed -n '1,40p' ~/.config/xfce4/panel/genmon-25.rc 2>/dev/null || true
```

## 关键约束

- 需要 `xfce4-panel`、`xfconf-query`、`ip`；若缺少 `xfce4-cpugraph-plugin` 或 `xfce4-genmon-plugin`，脚本会尝试安装。
- 在没有 `nvidia-smi` 的设备上，GPU 项会降级显示 `GPU n/a`，不会出现 `XXX`。
- 通过 SSH 执行时，如果不注入 `DISPLAY/DBUS`，通常不会作用到当前可见桌面。

## 文件

- `scripts/setup-xfce-panel-monitors.sh`：一键部署脚本（可直接复用到其他硬件）。
