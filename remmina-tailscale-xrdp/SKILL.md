---
name: remmina-tailscale-xrdp
description: 在 Linux 服务端与 Linux 客户端之间打通 Tailscale + xrdp + XFCE + Remmina 远程桌面，并完成客户端 Remmina 参数优化、服务端 XFCE 合成器优化、Tailscale 登录与联通验证。适用于“局域网直连已经通了，但外网要继续远程桌面”“Remmina 继续走 RDP”“想让后续客户端按固定步骤自动配通”的场景。
---

# Remmina Tailscale XRDP

## Overview

这个 skill 用于在已经选择 `Remmina + RDP + xrdp` 的前提下，把一台 Linux 图形机扩展成可通过 `Tailscale + RDP` 访问的远程桌面服务端，并把客户端 Remmina 配到可直接使用的状态。

如果用户只需要局域网或同网段直连，不要从这里开始，优先使用：
- `headless-rdp-remmina-audio`

默认目标：
- 服务端跑 `xrdp + XFCE`
- 客户端用 `Remmina`
- 两端通过 `Tailscale` 打通
- 服务端关闭 XFCE compositing
- 客户端 Remmina 优先走 `16bpp`

## 适用前提

- 服务端是 Linux，已有或计划使用 `xrdp`
- 客户端是 Linux，已有或计划使用 `Remmina`
- 允许在服务端安装 `tailscale`
- 客户端能通过 `ssh <host-or-alias>` 登录

如果不是这个结构，不要硬套这个 skill。

## 快速决策

### 何时使用

- 用户说“Remmina 局域网能连，想从外网继续连”
- 用户说“给我把服务端和客户端一起配通”
- 用户说“继续用 xrdp + XFCE，不要换协议”
- 用户说“顺手把桌面性能也优化一下”

### 何时不要使用

- 服务端不是 Linux
- 用户只需要局域网/直连 `server:3389`
- 用户要求共享当前物理桌面而不是单独的 xrdp 会话
- 用户要的是 VNC、NoMachine、RustDesk 或 WireGuard 自建方案
- 服务端不允许装系统服务

## 标准工作流

### 1. 先做只读检查

先确认服务端当前是什么图形链路，不要先改。

服务端本机检查：

```bash
printf 'XDG_SESSION_TYPE=%s\nDESKTOP_SESSION=%s\nXDG_CURRENT_DESKTOP=%s\nDISPLAY=%s\n' \
  "$XDG_SESSION_TYPE" "$DESKTOP_SESSION" "$XDG_CURRENT_DESKTOP" "$DISPLAY"

loginctl show-session "$XDG_SESSION_ID" \
  -p Id -p User -p Remote -p Type -p Display -p Service -p Active

ps -ef | rg -i 'xrdp|sesman|Xorg|xorgxrdp|xfce|xfwm4|remmina|vnc'
```

目标结论通常应是：
- `Service=xrdp-sesman`
- `Type=x11`
- 桌面是 `XFCE`
- 进程里有 `xrdp`, `xrdp-sesman`, `Xorg :10`, `xrdp-chansrv`

### 2. 检查 Tailscale 安装和登录态

服务端：

```bash
command -v tailscale >/dev/null && tailscale status --json || echo server_tailscale_missing
```

客户端：

```bash
ssh <client> 'command -v tailscale >/dev/null && tailscale status --json || echo client_tailscale_missing'
```

判断规则：
- 客户端未装：先装客户端
- 服务端未装：安装服务端
- `AuthURL` 非空：需要网页登录授权
- `BackendState=Running` 且有 `TailscaleIPs`：已登录

### 3. 安装并登录服务端 Tailscale

仅在服务端未安装时执行：

```bash
curl -fsSL https://tailscale.com/install.sh | sh
systemctl is-enabled tailscaled
systemctl is-active tailscaled
```

触发登录：

```bash
sudo tailscale up
tailscale status --json
```

如果输出 `AuthURL`，让用户打开链接完成授权，然后重新检查：

```bash
tailscale status --json
```

### 4. 修正这类机器上常见的 netfilter 告警

如果服务端满足下面两个条件：
- `tailscale status --json` 的 `Health` 有 router / iptables / nftables 告警
- 用户目标只是“远程登录这台主机本身”，不是做子网路由或出口节点

优先做法：

```bash
sudo tailscale set --netfilter-mode=off
tailscale status --json
```

这样做的原因：
- 这类机器上经常混有 `iptables-legacy` 和 `nftables` 残留
- 用户只需要登录本机，不需要 Tailscale 自动代管复杂转发规则
- `netfilter-mode=off` 往往比继续硬修兼容层更稳

只有在明确需要研究系统防火墙兼容性时，才继续折腾 `iptables` / `nftables`。

### 5. 确认 xrdp 监听正常

服务端执行：

```bash
ss -tlnp | rg '3389|xrdp'
systemctl is-active xrdp xrdp-sesman
grep -nE '^(port=|security_layer=|crypt_level=|bitmap_cache=|bulk_compression=|max_bpp=)' /etc/xrdp/xrdp.ini
```

期望至少满足：
- `*:3389` 在监听
- `xrdp` 和 `xrdp-sesman` 都是 `active`
- `bitmap_cache=true`
- `bulk_compression=true`

### 6. 优化 XFCE 远程桌面表现

关闭 XFCE compositing：

```bash
xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s false
nohup xfwm4 --replace >/tmp/xfwm4-replace.log 2>&1 </dev/null &
xfconf-query -c xfwm4 -p /general/use_compositing
```

期望结果：
- 输出 `false`

这一步的收益：
- 减少阴影、透明等额外绘制
- 对 `xrdp + XFCE` 通常更顺

### 6.1 如果 xrdp 登录后秒退，优先排查会话总线污染

这类问题常见于同一 Linux 用户名下曾经跑过：
- 本地物理 XFCE 会话
- TigerVNC/Xvnc 会话
- 旧的 xrdp/Xorg 会话

典型症状：
- `tailscale ping` 和 `nc -vz <ip> 3389` 都成功
- Remmina 认证通过，但桌面一闪而退，或者黑屏后立即断开
- `journalctl -u xrdp -u xrdp-sesman` 里显示 session start success，但几秒后 terminated
- `~/.xsession-errors` 里出现 `screensaver already running in this session`、`Process already running`、`Disconnected from session manager`、`startxfce4` 崩溃，或者旧的 `DBUS_SESSION_BUS_ADDRESS=/run/user/<uid>/bus`

先检查是否存在旧图形会话或 VNC 残留：

```bash
loginctl list-sessions --no-legend
ps -u "$USER" -o pid,ppid,tty,stat,cmd --sort=pid | egrep 'xfce|xfwm|xfsettingsd|xfdesktop|panel|dbus|Xorg|xorgxrdp|startxfce4|xfce4-session|vnc'
systemctl --user list-unit-files | egrep -i 'vnc|tigervnc' || true
find ~/.config/autostart /etc/xdg/autostart -maxdepth 1 -type f 2>/dev/null | egrep -i 'vnc|tigervnc' || true
tail -n 120 ~/.xsession-errors
```

如果判断是会话污染，不要继续调分辨率，先把 xrdp 会话隔离出来：

```bash
cat > ~/.xsession <<'EOF'
#!/bin/sh
exec xfce4-session
EOF
chmod 755 ~/.xsession

cat > ~/.xsessionrc <<'EOF'
# Isolate xrdp XFCE from any existing user session bus
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce
EOF

: > ~/.xsession-errors
sudo systemctl restart xrdp xrdp-sesman
```

这一步的目的：
- 不让 xrdp 会话复用已有用户总线
- 避免本地会话、旧 VNC 会话、旧 xrdp 会话互相抢 XFCE session manager
- 比继续调整 Remmina 分辨率更对症

如果仍然异常，再继续看：
- `journalctl -u xrdp -u xrdp-sesman -n 160 --no-pager`
- `~/.xorgxrdp.*.log`
- `~/.xsession-errors`

如果机器上还保留 TigerVNC 作为旧方案，建议在 xrdp 方案稳定后停掉用户级 VNC 自启和 VNC 专用 autostart，减少后续冲突面。

### 7. 配置客户端 Remmina

先找现有配置：

```bash
ssh <client> 'ls -la ~/.local/share/remmina'
ssh <client> 'grep -RIl "100\\.|taild.*\\.ts\\.net\\|3389" ~/.local/share/remmina 2>/dev/null || true'
```

如果已有目标配置文件，优先最小修改；不要新建一堆重复连接。

推荐 Remmina 键值：

```ini
[remmina]
protocol=RDP
server=<service_tailscale_ip>:3389
colordepth=16
quality=2
resolution_mode=1
scale=1
sound=local
disableclipboard=0
multimon=0
keyboard_grab=1
ignore-tls-errors=1
```

实际修改示例：

```bash
ssh <client> '
  set -e
  f="$HOME/.local/share/remmina/<profile>.remmina"
  cp "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"
  perl -0pi -e "s/^server=.*/server=<service_tailscale_ip>:3389/m;
                s/^colordepth=.*/colordepth=16/m;
                s/^quality=.*/quality=2/m" "$f"
'
```

### 8. 做联通验证

服务端先确认自己的 Tailscale IP：

```bash
tailscale status --json
```

客户端验证：

```bash
ssh <client> 'tailscale ping -c 4 <service_tailscale_ip>'
ssh <client> 'nc -vz -w 5 <service_tailscale_ip> 3389'
ssh <client> 'tailscale ping -c 4 <service_magicdns_name>'
ssh <client> 'nc -vz -w 5 <service_magicdns_name> 3389'
```

判定规则：
- `pong ... via ...`：Tailscale 已通
- `Connection ... 3389 ... succeeded!`：RDP 已通
- 如果第一次 `tailscale ping` 在刚重启后短暂 `timed out`，但下一行马上 `pong` 且 `3389` 成功，这是正常启动窗口，不要误判为失败

## 输出模板

完成后给用户的结论至少要包含：

- 服务端 Tailscale IP
- 服务端 MagicDNS 名称
- 客户端 Remmina 配置文件路径
- 是否关闭了 XFCE compositing
- `tailscale ping` 是否成功
- `3389` 端口是否成功
- 之后应该在 Remmina 里填什么地址

推荐输出要点：

```text
- 服务端 Tailscale IP：100.x.x.x
- MagicDNS：host.tailxxxx.ts.net
- Remmina 连接地址：100.x.x.x:3389
- XFCE compositing：false
- tailscale ping：成功
- RDP 3389：成功
```

## 已知边界

- 这个 skill 默认适配“只远程登录本机 GUI”的场景
- 如果服务端后续还要承担子网路由、出口节点、复杂防火墙策略，不要直接沿用 `netfilter-mode=off`
- 如果用户要求共享当前物理桌面，应改走桌面共享/VNC/Wayland RDP 方案，不要硬套 xrdp
