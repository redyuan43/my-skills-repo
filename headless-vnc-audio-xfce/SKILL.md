---
name: headless-vnc-audio-xfce
description: 在无显示器 Ubuntu/Linux 上部署固定会话 TigerVNC + 精简 XFCE + PulseAudio TCP 音频回传，覆盖服务端安装、客户端接入、黑屏排障和内存优化。适用于“只用 VNC 登录 GUI”“想让客户端听到远端声音”“重启后黑屏但端口还通”“想继续压 XFCE 占用”这类场景。
---

# Headless VNC Audio XFCE

在“只保留 VNC 图形桌面，不再使用本地 GNOME/GDM”的机器上使用这个技能。

这是一个服务端 + 客户端成对的技能：

- 服务端：`TigerVNC :1` 常驻桌面、`XFCE` 精简启动、`PulseAudio` TCP 音频输出
- 客户端：普通 `VNC` viewer 显示画面，单独用 `parec | pacat` 拉远端声音

如果只需要基础的 headless VNC 与 Chromium 排障，优先使用：
- `headless-vnc-chromium-fix`

如果只需要 Linux 客户端发起 VNC 连接，不改服务端：
- `vnc-client-connect`

## 覆盖范围

- 安装 `TigerVNC + XFCE`
- 把系统默认目标切到 `multi-user.target`，停用本地 `gdm3`
- 创建固定的 `:1` 常驻桌面
- 给 VNC 桌面加远端音频回传
- 修复“端口通但进桌面黑屏”的典型 `xfce4-screensaver` 覆盖问题
- 给出当前已验证过的内存优化优先级

## `sync-latest-skills` 之后的最短使用示例

如果这个技能已经通过 `sync-latest-skills` 同步到 `~/.codex/skills`，最短可按下面顺序落地：

### 服务端

```bash
cd ~/.codex/skills/headless-vnc-audio-xfce

install -Dm700 assets/xstartup "$HOME/.vnc/xstartup"
install -Dm700 scripts/vnc_session_poststart.sh "$HOME/.local/bin/vnc-session-poststart.sh"
install -Dm644 assets/xfce4-session.xml "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml"
install -Dm700 scripts/vnc_audio_server_setup.sh "$HOME/.local/bin/vnc-audio-server-setup.sh"
install -Dm700 scripts/vnc_audio_status.sh "$HOME/.local/bin/vnc-audio-status.sh"

sudo install -Dm644 assets/vncserver-headless.service /etc/systemd/system/vncserver-headless.service
sudo systemctl daemon-reload
sudo systemctl enable --now vncserver-headless.service

bash "$HOME/.local/bin/vnc-audio-server-setup.sh"
```

### 客户端

```bash
cd ~/.codex/skills/headless-vnc-audio-xfce
scp <server>:/home/<user>/.config/pulse/vnc-audio.cookie ~/.config/pulse/vnc-audio.cookie
export VNC_AUDIO_SERVER=<server-ip>
bash scripts/vnc_audio_client_attach.sh
```

上面是最短路径，默认假设：

- 远端用户是当前登录用户
- `assets/vncserver-headless.service` 里的占位符已经先替换好
- 客户端已装 `parec` 和 `pacat`
- 画面连接仍然通过普通 `VNC` viewer 访问 `<server-ip>:5901`

## 标准工作流

### 1. 服务端安装轻量桌面

```bash
sudo apt-get update
sudo apt-get install -y tigervnc-standalone-server xfce4 xfce4-goodies dbus-x11 pulseaudio
```

如果机器以后只通过 VNC 访问 GUI，可改为纯命令行启动目标：

```bash
sudo systemctl disable --now gdm3
sudo systemctl set-default multi-user.target
```

这是高风险动作。执行前要确认用户不再需要本地物理登录界面。

### 2. 写入 VNC 与 XFCE 精简配置

按需替换模板里的占位符后安装：

```bash
install -Dm700 assets/xstartup "$HOME/.vnc/xstartup"
install -Dm700 scripts/vnc_session_poststart.sh "$HOME/.local/bin/vnc-session-poststart.sh"
install -Dm644 assets/xfce4-session.xml "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml"
install -Dm644 assets/autostart/xfce4-screensaver.desktop "$HOME/.config/autostart/xfce4-screensaver.desktop"
install -Dm644 assets/autostart/xiccd.desktop "$HOME/.config/autostart/xiccd.desktop"
install -Dm644 assets/autostart/print-applet.desktop "$HOME/.config/autostart/print-applet.desktop"
install -Dm644 assets/autostart/xfce4-notifyd.desktop "$HOME/.config/autostart/xfce4-notifyd.desktop"
install -Dm644 assets/autostart/xfce4-power-manager.desktop "$HOME/.config/autostart/xfce4-power-manager.desktop"
install -Dm644 assets/autostart/nm-applet.desktop "$HOME/.config/autostart/nm-applet.desktop"
install -Dm644 assets/autostart/tracker-miner-fs-3.desktop "$HOME/.config/autostart/tracker-miner-fs-3.desktop"
install -Dm644 assets/autostart/org.gnome.Evolution-alarm-notify.desktop "$HOME/.config/autostart/org.gnome.Evolution-alarm-notify.desktop"
install -Dm644 assets/autostart/update-notifier.desktop "$HOME/.config/autostart/update-notifier.desktop"
```

这里的核心经验：

- `xstartup` 继续走 `startxfce4`，不要手搓一大串 `xfwm4 & xfsettingsd & ...`
- 精简靠 `xfce4-session.xml` 和 `autostart` 覆盖来做
- `xfdesktop` 可以不启动，但桌面背景会变成纯黑，这不是故障

### 3. 安装 systemd 常驻服务

把 `assets/vncserver-headless.service` 里的这些占位符替换掉：

- `__USER__`
- `__HOME__`
- `__DISPLAY__`
- `__GEOMETRY__`
- `__DEPTH__`

然后安装并启用：

```bash
sudo install -Dm644 assets/vncserver-headless.service /etc/systemd/system/vncserver-headless.service
sudo systemctl daemon-reload
sudo systemctl enable --now vncserver-headless.service
```

默认参数可直接用：

- display: `:1`
- geometry: `1920x1080`
- depth: `24`

### 4. 服务端启用音频输出

安装脚本：

```bash
install -Dm700 scripts/vnc_audio_server_setup.sh "$HOME/.local/bin/vnc-audio-server-setup.sh"
install -Dm700 scripts/vnc_audio_status.sh "$HOME/.local/bin/vnc-audio-status.sh"
```

在 VNC 会话内运行：

```bash
bash scripts/vnc_audio_server_setup.sh
```

它会：

- 创建 `vnc_audio` 虚拟 sink
- 把默认 sink 切到 `vnc_audio`
- 暴露 `module-native-protocol-tcp`
- 自动检测默认网卡地址并监听 `4713/tcp`
- 使用 cookie 认证而不是匿名开放

状态检查：

```bash
bash scripts/vnc_audio_status.sh
ss -ltnp | grep 4713
```

### 5. 客户端连接画面和声音

画面：

- `Remmina` 必须建 `VNC` 配置，不要误用 `RDP`
- 地址填 `<host-ip>:5901`

如果服务端日志出现 `not an RFB client?`，通常是客户端用错了协议。

声音：

```bash
bash scripts/vnc_audio_client_attach.sh
```

客户端脚本依赖：

- `parec`
- `pacat`
- 服务端 cookie 文件

推荐先把 cookie 复制到客户端：

```bash
scp <server>:/home/<user>/.config/pulse/vnc-audio.cookie ~/.config/pulse/vnc-audio.cookie
```

再设置环境变量：

```bash
export VNC_AUDIO_SERVER=<server-ip>
bash scripts/vnc_audio_client_attach.sh
```

## 已验证过的关键经验

### 1. TigerVNC 本身不负责音频

GUI 和音频要拆成两条链路：

- GUI：`VNC/RFB` 走 `5901`
- 音频：`PulseAudio TCP` 走 `4713`

### 2. 客户端优先用 `parec | pacat`

在 `PipeWire-pulse` 客户端上，`module-tunnel-source-new` 可能报 `No such entity`。

更稳的方案是：

```bash
parec --server=tcp:<host>:4713 --device=vnc_audio.monitor ... | pacat --playback ...
```

### 3. 黑屏不一定是桌面挂了

如果端口通、`Xtigervnc` 在跑、`xfwm4` 和 `xfce4-panel` 也在跑，但客户端看到纯黑：

- 先检查是不是 `xfce4-screensaver` 起了全屏黑窗口
- 其次确认是不是只关掉了 `xfdesktop`，导致根窗口背景是黑色

`scripts/vnc_session_poststart.sh` 就是为这个坑准备的。

### 4. 音频 TCP 模块可能会重载回 localhost

如果 `vnc_audio_status.sh` 显示模块在，但 `ss` 里只看到 `127.0.0.1:4713`：

- 先 `pactl unload-module <module-id>`
- 再重新跑 `vnc_audio_server_setup.sh`

## 优化优先级

优先级顺序已经在真实机器上验证过：

1. 先关大应用，比如 `WeChat`
2. 再减 `xfce4-panel` 插件
3. 再减 `xdg-desktop-portal*`
4. 再考虑 `Thunar --daemon`、终端常驻
5. 最后才考虑 `-depth 16`

深度从 `24` 改 `16` 会省一点 framebuffer，但不是大头，画质还会变差。

更详细的数据与取舍写在：
- `references/runbook.md`

## 何时要停下来确认

在这些动作前要先和用户确认：

- `disable --now gdm3`
- `set-default multi-user.target`
- 开放 `5901/tcp` 或 `4713/tcp` 到非可信网段
- 修改 VNC 密码或复用系统登录密码
- 杀掉当前仍在使用的 GUI 会话并重建 `:1`
