---
name: remmina-tailscale-xrdp
description: 在 Linux 服务端与 Linux 客户端之间打通 Tailscale + xrdp + XFCE + Remmina 远程桌面，覆盖登录态检查、Remmina 参数优化和服务端 XFCE 性能优化。
---

# Remmina Tailscale XRDP

## 触发条件

当用户已经采用 `Remmina + RDP + xrdp`，且局域网直连已通或计划继续保留该链路，但需要通过 `Tailscale` 从外网访问时使用本 skill。

不要用于：

- 只需要局域网直连 `server:3389`；改用 `headless-rdp-remmina-audio`。
- VNC、NoMachine、RustDesk 或共享物理桌面。
- 不允许安装系统服务或登录 Tailscale 的机器。

## 入口

先读状态，再决定是否修改：

```bash
tailscale status --json
ss -tlnp | rg '3389|xrdp'
systemctl is-active xrdp xrdp-sesman
```

安全自检：

```bash
bash remmina-tailscale-xrdp/scripts/selftest.sh --safe
```

## 确认 Gate

执行以下动作前必须获得用户明确确认：

- 安装或启动 `tailscale` / `tailscaled`。
- 执行 `sudo tailscale up`、`tailscale set` 或任何会改变 tailnet 登录态的命令。
- 修改 xrdp、XFCE、`~/.xsession`、`~/.xsessionrc`。
- 重启 `xrdp`、`xrdp-sesman`、`tailscaled` 或图形会话。

若 `tailscale status --json` 返回 `AuthURL`，必须让用户完成网页登录授权后再继续验收。

## Runbook

完整状态识别、Tailscale 登录、xrdp/XFCE 排障和客户端 Remmina 参数步骤见：

- [references/runbook.md](references/runbook.md)

## 产物 Gate

- Tailscale 验收以 `BackendState=Running` 且存在 `TailscaleIPs` 为准。
- Remmina profile 应继续使用 `RDP`，地址应使用 Tailscale IP 或 MagicDNS 名称。
- xrdp 验收必须看到 `3389/tcp` 监听、`xrdp` 与 `xrdp-sesman` active，以及真实 Remmina 登录成功。

## 文件

- `references/runbook.md`：完整运维步骤和故障模式。
- `scripts/selftest.sh`：无副作用结构、语法、依赖和 runbook gate 检查。
