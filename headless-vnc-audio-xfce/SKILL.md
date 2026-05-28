---
name: headless-vnc-audio-xfce
description: 在无显示器 Ubuntu/Linux 上部署固定会话 TigerVNC + 精简 XFCE + PulseAudio TCP 音频回传，覆盖服务端安装、客户端接入、黑屏排障和内存优化。
---

# Headless VNC Audio XFCE

## 触发条件

当用户明确要用 `VNC` 登录一台无显示器 Linux 主机，并希望把远端声音回传到客户端时使用本 skill。

不要用于：

- Remmina RDP / xrdp 直连；改用 `headless-rdp-remmina-audio`。
- Tailscale + xrdp 外网接入；改用 `remmina-tailscale-xrdp`。
- 只需要客户端连现成 VNC 服务；改用 `vnc-client-connect`。

## 入口

服务端脚本：

```bash
bash headless-vnc-audio-xfce/scripts/vnc_audio_server_setup.sh
bash headless-vnc-audio-xfce/scripts/vnc_audio_status.sh
```

客户端音频拉流：

```bash
export VNC_AUDIO_SERVER=<server-ip>
bash headless-vnc-audio-xfce/scripts/vnc_audio_client_attach.sh
```

安全自检：

```bash
bash headless-vnc-audio-xfce/scripts/selftest.sh --safe
```

## 确认 Gate

执行以下动作前必须获得用户明确确认：

- 安装 `tigervnc-standalone-server`、`xfce4`、`pulseaudio` 等系统包。
- 停用 `gdm3` 或切换 `multi-user.target`。
- 写入 `/etc/systemd/system/vncserver-headless.service`。
- `systemctl enable --now`、`daemon-reload`、停止或重启图形服务。

只安装用户目录下的 `~/.vnc/xstartup`、`~/.local/bin/*` 前，也要先说明目标路径。

## Runbook

完整服务端、客户端、音频、黑屏排障和内存优化步骤见：

- [references/runbook.md](references/runbook.md)

## 产物 Gate

- `assets/vncserver-headless.service` 中占位符必须在落地前替换：`__USER__`、`__HOME__`、`__DISPLAY__`、`__GEOMETRY__`、`__DEPTH__`。
- VNC 画面链路走 `5901/tcp`，音频链路走 PulseAudio TCP `4713/tcp`，不要把 Remmina RDP 配置误用于 VNC。
- 验收必须同时检查画面、`vnc_audio` sink、cookie 认证和客户端 `parec | pacat` 拉流。

## 文件

- `assets/`：VNC、XFCE、autostart 和 systemd 模板。
- `scripts/vnc_session_poststart.sh`：会话启动后处理。
- `scripts/vnc_audio_server_setup.sh`：服务端 PulseAudio TCP 音频设置。
- `scripts/vnc_audio_status.sh`：音频状态检查。
- `scripts/vnc_audio_client_attach.sh`：客户端音频拉流。
- `scripts/selftest.sh`：无副作用结构、语法、依赖和模板检查。
