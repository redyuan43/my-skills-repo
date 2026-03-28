# Headless VNC Audio XFCE Runbook

这份 runbook 记录的是一套已经在真实 Ubuntu 机器上踩坑并修正过的组合：

- `TigerVNC` 提供固定 `:1` 桌面
- `XFCE` 提供轻量 GUI
- `PulseAudio` 提供远端音频回传
- 开机默认进 `multi-user.target`
- 不再保留本地 `GNOME/GDM`

## 架构

### 画面链路

客户端 viewer
-> `5901/tcp`
-> `Xtigervnc :1`
-> `XFCE`

### 音频链路

远端应用
-> `PulseAudio default sink = vnc_audio`
-> `vnc_audio.monitor`
-> `4713/tcp`
-> 客户端 `parec`
-> 客户端 `pacat`

## 验证命令

### 服务端

```bash
systemctl status --no-pager -l vncserver-headless.service
ss -ltnp | grep -E ':5901|:4713'
ps -ef | grep -E 'Xtigervnc|xfce4-session|xfwm4|xfce4-panel|pulseaudio'
tail -n 120 ~/.vnc/*.log
```

### 音频

```bash
bash scripts/vnc_audio_status.sh
paplay --device=vnc_audio /usr/share/sounds/alsa/Front_Center.wav
```

### 客户端

```bash
export VNC_AUDIO_SERVER=<host-ip>
bash scripts/vnc_audio_client_attach.sh
```

## 典型坑

### 1. Remmina 连得上端口但服务端日志报 `not an RFB client?`

通常不是服务端坏了，而是：

- 客户端用了 `RDP` 配置去连 `5901`
- 或者 Quick Connect 没有显式走 `vnc://`

修法：

- 在 Remmina 明确新建 `VNC` 配置
- 地址写 `<host-ip>:5901`

### 2. 重启后黑屏

真实根因通常有两类：

- `xfce4-screensaver` 起了全屏黑覆盖层
- `xfdesktop` 被禁用了，只剩黑色根背景

区分方法：

- 如果 `xwininfo -root -tree` 里看到 `xfce4-panel`、`xfwm4`、`xfce4-session` 都还在，说明不是 VNC 挂掉
- 如果还看到 `xfce4-screensaver` 的全屏窗口，先把它关掉

### 3. `module-tunnel-source-new` 在客户端不可用

在 `PipeWire-pulse` 客户端上，走模块隧道可能直接失败。已经验证更稳的是：

```bash
parec --server=tcp:<host>:4713 --device=vnc_audio.monitor ... | pacat --playback ...
```

### 4. 音频服务只监听在 `127.0.0.1`

这是重载后常见回归。处理顺序：

1. `pactl list short modules | grep module-native-protocol-tcp`
2. `pactl unload-module <id>`
3. 再跑 `vnc_audio_server_setup.sh`
4. 用 `ss -ltnp | grep 4713` 确认绑定到了实际 LAN IP

## 已测到的内存经验

以下是同一台 `7.4 GiB` 内存机器上的实测口径：

### 关掉 WeChat 前

- 整机 `used` 约 `1.4 GiB`
- `WeChat` 进程族约 `1273 MiB`
- `VNC + XFCE` 主体约 `403 MiB`
- 音频相关约 `31 MiB`

### 关掉 WeChat 后

- 整机 `used` 约 `1.0 GiB`
- 可用内存约 `6.2 GiB`

注意：

- 进程 RSS 求和不会和 `free -h` 的 `used` 一一对应
- 共享页和内核缓存会让两者口径不同

## XFCE 继续优化的建议顺序

### 高收益

- 先关 `WeChat` 这种大应用
- 继续精简 `xfce4-panel` 插件

面板插件在实测里合计大约 `172 MiB`，主要包括：

- `pulseaudio` 插件
- `power manager` 插件
- `notification` 插件
- `systray`
- `actions`

### 中收益

- 关 `xdg-desktop-portal*`
- 关 `Thunar --daemon`
- 改用更轻的终端而不是 `gnome-terminal-server`

### 低收益

- `pulseaudio + pipewire + pipewire-media-session` 这组本身只约 `31 MiB`
- `xfsettingsd` 也不是大头

### 路线切换级优化

如果还想大降，而不是抠几十 MiB：

- 用 `Openbox` / `Fluxbox` 替代 `XFCE`
- 降分辨率
- 把 `-depth 24` 改成 `-depth 16`

`-depth 16` 能省一点，但远不如砍掉大应用或面板插件来得明显。
