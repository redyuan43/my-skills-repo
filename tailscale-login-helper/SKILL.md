---
name: tailscale-login-helper
description: 检查 Linux 机器在重启后是否仍保持 Tailscale 登录，必要时触发重新登录并输出授权链接；也适用于排查 tailscaled 未启动、节点未加入目标 Tailnet、或需要快速恢复 SSH 到另一台 Tailscale 主机的场景。
---

# Tailscale Login Helper

当用户问“重启后还要不要重新登录 Tailscale”、“为什么突然看不到另一台机器了”、“帮我恢复 Tailscale 登录”时使用这个 skill。

## 结论规则

- 正常情况下，Linux 机器重启后不需要重新登录 Tailscale。
- 只要 `tailscaled` 已启用、服务正常、节点 key 没过期，重启后通常会自动恢复到原 Tailnet。
- 需要重新登录的常见原因：
  - 手动执行过 `tailscale logout`
  - 切换了账号或 Tailnet
  - 节点 key 过期或被吊销
  - 设备在 Tailscale 管理台被移除
  - `tailscaled` 服务没启动

## 标准工作流

1. 先运行：

```bash
bash "~/.codex/skills/tailscale-login-helper/scripts/tailscale_login_helper.sh"
```

2. 观察输出：
   - 如果显示 `无需重新登录`，说明重启后通常会自动恢复
   - 如果显示 `需要重新登录`，再运行：

```bash
bash "~/.codex/skills/tailscale-login-helper/scripts/tailscale_login_helper.sh" login
```

3. 若要验证另一台机器是否可达，直接使用：

```bash
tailscale ping "<目标 Tailscale IP 或 DNS 名>"
```

## 经验规则

- 先看 `CurrentTailnet` 和目标机器是否在同一个 Tailnet，再谈 SSH。
- `tailscale status --json` 里 `AuthURL` 非空，通常就是明确需要重新登录。
- 目标主机在线但 `tailscale ping` 只能走 `DERP`，说明能通但不是直连，不影响大多数 SSH 使用。
- 如果只是想确认开机状态，不要先执行 `tailscale logout`；先做只读检查。
- `login` 模式会调用 `sudo tailscale up`，适合在本机交互式恢复授权链接。

## 文件

- `scripts/tailscale_login_helper.sh`：状态检查与登录恢复脚本
