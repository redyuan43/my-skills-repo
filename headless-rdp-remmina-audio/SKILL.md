---
name: headless-rdp-remmina-audio
description: 在无显示器 Ubuntu/Linux 主机上通过 Remmina + RDP 直连 xrdp + XFCE 远程桌面，生成客户端 Remmina 配置并处理音频、分辨率、剪贴板等常见问题。
---

# Headless RDP Remmina Audio

## 触发条件

当用户要从 Linux 客户端用 `Remmina` 直连一台 Linux 主机的 `xrdp + XFCE` 桌面，并希望客户端能听到远端声音时使用本 skill。

不要用于：

- VNC 服务端部署或迁移；改用 `headless-vnc-audio-xfce` 或 `vnc-client-connect`。
- Tailscale / 外网 overlay 接入；改用 `remmina-tailscale-xrdp`。
- 共享物理桌面；本 skill 面向独立 xrdp 会话。

## 入口

客户端直写 Remmina RDP 配置：

```bash
bash headless-rdp-remmina-audio/scripts/write_remmina_profile.sh <server[:port]> [username] [profile_name]
```

通过 SSH 推送到另一台 Linux 客户端：

```bash
bash headless-rdp-remmina-audio/scripts/push_remmina_profile_via_ssh.sh <client-ssh-target> <server[:port]> [username] [profile_name]
```

安全自检：

```bash
bash headless-rdp-remmina-audio/scripts/selftest.sh --safe
```

## 确认 Gate

执行会修改系统状态的服务端步骤前，必须先得到用户明确确认：

- 安装 `xrdp`、`xorgxrdp`、`xfce4`、音频模块或构建依赖。
- 修改 `~/.xsession`、`~/.xsessionrc`、`/etc/xrdp/*`。
- 运行 `sudo systemctl restart xrdp xrdp-sesman`。
- 构建并 `sudo make install` xrdp 音频模块。

优先先读状态，再动系统。只生成 Remmina profile 属于客户端文件写入，仍应说明目标路径。

## Runbook

完整安装、音频、PipeWire/PulseAudio、Remmina 参数和故障处理步骤见：

- [references/runbook.md](references/runbook.md)

## 产物 Gate

- Remmina profile 写入 `~/.local/share/remmina/*.remmina`。
- profile 中协议必须是 `RDP`，地址必须是 `<server>:3389` 或用户指定端口。
- 服务端验收以真实 RDP 登录后的 `xrdp-sink` / `xrdp-source` 和声音播放为准，不用单条命令伪判成功。

## 文件

- `scripts/write_remmina_profile.sh`：生成本机 Remmina RDP profile。
- `scripts/push_remmina_profile_via_ssh.sh`：通过 SSH 推送 profile 到客户端。
- `scripts/selftest.sh`：无副作用结构、语法、依赖和模板检查。
