---
name: xfce-panel-monitors-setup
description: 在 Linux 桌面状态栏配置 CPU、GPU/RAM 和 IPv4 监控；支持 XFCE 面板原生插件，也支持 Ubuntu/GNOME 顶栏 AppIndicator；适用于需要快速把同一套状态栏监控部署到本机或多台 Linux 设备的场景。
---

# Linux Status Bar Monitors Setup

当用户要在 Linux 桌面状态栏显示 CPU、GPU、内存和本地 IPv4，并且希望可在多台机器一键部署时，使用这个 skill。

## 支持范围

- `XFCE`：为 `panel-1` 添加 `cpugraph`（CPU 图表）和两个 `genmon` 项。
- `Ubuntu/GNOME`：创建用户级 `AppIndicator` 状态栏小程序，并排显示 CPU、GPU、GPU 显存、RAM 和 IPv4。
- 两种方式都支持重复执行；XFCE 会备份 `xfce4-panel.xml`，GNOME 会覆盖同名用户级启动项。

## 标准工作流

1. 当前 Ubuntu/GNOME 桌面：

```bash
bash xfce-panel-monitors-setup/scripts/setup-ubuntu-statusbar-monitors.sh
```

如果缺少 AppIndicator 依赖，脚本默认只提示安装命令；得到用户确认后再执行：

```bash
AUTO_INSTALL_DEPS=1 bash xfce-panel-monitors-setup/scripts/setup-ubuntu-statusbar-monitors.sh
```

2. 本机 XFCE 会话：

```bash
bash xfce-panel-monitors-setup/scripts/setup-xfce-panel-monitors.sh
```

3. 远端 XFCE 主机（如 `nx1`/`nx2`）通过 SSH 执行时，先从远端 `xfce4-panel` 进程继承图形会话变量再运行：

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

4. 验证结果：

Ubuntu/GNOME：

```bash
pgrep -af ubuntu-statusbar-monitors.py
grep -n . ~/.config/autostart/ubuntu-statusbar-monitors.desktop
```

XFCE：

```bash
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids
sed -n '1,40p' ~/.config/xfce4/panel/genmon-24.rc 2>/dev/null || true
sed -n '1,40p' ~/.config/xfce4/panel/genmon-25.rc 2>/dev/null || true
```

## 关键约束

- XFCE 路径需要 `xfce4-panel`、`xfconf-query`、`ip`；若缺少 `xfce4-cpugraph-plugin` 或 `xfce4-genmon-plugin`，脚本会尝试安装。
- Ubuntu/GNOME 路径需要 `python3`、`python3-gi`、`gir1.2-gtk-3.0`、`gir1.2-ayatanaappindicator3-0.1`、`gnome-shell-extension-appindicator`、`ip`；默认不自动安装全局依赖，除非设置 `AUTO_INSTALL_DEPS=1`。
- 在没有 `nvidia-smi` 的设备上，GPU 项会降级显示 `GPU n/a`，不会出现 `XXX`。
- 通过 SSH 执行时，如果不注入 `DISPLAY/DBUS`，通常不会作用到当前可见桌面；GNOME 路径还需要可用的用户图形会话和 AppIndicator 扩展。

## 文件

- `scripts/setup-ubuntu-statusbar-monitors.sh`：Ubuntu/GNOME 顶栏 AppIndicator 部署脚本。
- `scripts/setup-xfce-panel-monitors.sh`：XFCE 面板一键部署脚本（可直接复用到其他硬件）。
