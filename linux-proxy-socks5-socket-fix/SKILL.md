---
name: linux-proxy-socks5-socket-fix
description: 当 Linux 机器因代理环境变量写成 `socks://127.0.0.1:PORT`、导致 Python/httpx/Node/CLI 程序报 Unknown scheme、SOCKS socket、代理握手或联网异常时使用。适用于 V2rayN/xray/Clash/sing-box 本地代理场景，支持诊断当前 shell、systemd user、environment.d，读取 V2rayN 端口，批量修正 `~/.bashrc`/`~/.zshrc` 与 `~/.config/environment.d`，并提供可选 `/etc/environment.d` 写入和一键回滚。
---

# Linux Proxy SOCKS5 Socket Fix

当用户说下面这类问题时，用这个 skill：

- “很多程序一启动就报 socket/proxy 错”
- “`httpx` / Python 提示 `Unknown scheme for proxy URL('socks://...')`”
- “Ubuntu 上代理明明开着，但不同程序表现不一致”
- “想保留代理，不是关闭，而是改成能工作的 SOCKS5”
- “帮我把这台机子和其他设备都做成可复用修复脚本”

这个 skill 的目标不是关闭代理，而是把最常见的 Linux 用户态代理问题修正为稳定可复用的形态：

- 把错误的 `socks://127.0.0.1:PORT` 规范成 `socks5://127.0.0.1:PORT`
- 保持 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` 结构一致
- 优先读取 V2rayN 的 `guiNConfig.json` 推断本地 SOCKS 端口
- 把修复固化进 `~/.bashrc`、`~/.zshrc` 和 `~/.config/environment.d`
- 尝试同步进 `systemd --user` 与 D-Bus 激活环境
- 可选写入 `/etc/environment.d`
- 提供 shell/user/system 分层的 `apply` / `revert`

## 何时使用

- 用户要保留本地代理，但现有 shell/CLI 程序因为代理变量格式不兼容而报错
- 用户在 Ubuntu/Linux 上使用 `v2rayN`、`xray`、`clash`、`mihomo`、`sing-box`
- 需要把一次排障经验沉淀成可自动化复用的脚本

## 标准工作流

1. 先诊断：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh diagnose
```

重点看：

- 当前 `ALL_PROXY` / `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`
- `systemd --user` 是否还保留旧代理值
- 是否存在 `socks://...` 这类旧值
- `v2rayN/xray/clash/sing-box` 进程和监听端口
- GNOME `gsettings` 里的代理状态
- `~/.config/environment.d` 和 `/etc/environment.d` 是否残留旧配置
- V2rayN 的 `guiNConfig.json` 是否存在，以及 SOCKS 端口是多少

2. 确认是 `socks://` 兼容问题后，执行默认自动修复：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh apply
```

若要显式指定端口：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh apply --port 10808
```

它会：

- 给 `~/.bashrc` / `~/.zshrc` 写入一段带 marker 的托管块
- 写入 `~/.config/environment.d/89-linux-proxy-socks5-socket-fix.conf`
- 尝试导入到 `systemd --user` 和 D-Bus 激活环境
- 将本地代理规范成：
  - `ALL_PROXY=socks5://127.0.0.1:<port>`
  - `HTTP_PROXY=http://127.0.0.1:<port>/`
  - `HTTPS_PROXY=http://127.0.0.1:<port>/`
  - `NO_PROXY=localhost,127.0.0.0/8,::1`
- 保留现有用户文件其他内容不变

3. 如果只想修 shell 层：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh apply-shell
```

4. 如果终端已正常，但桌面图标、GUI 程序、`systemd --user` 服务仍然异常，单独修用户会话层：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh apply-user
```

5. 如果明确要把规则固化到系统级新会话，再写 `/etc/environment.d`：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh apply-system
```

这一步需要 `sudo`，只对新登录会话和新启动的服务稳定生效，影响范围更大。

6. 如果只想看当前应该如何导出，不写文件：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh print-exports
```

7. 如果想看 `environment.d` 应写什么：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh print-envfile
```

8. 若用户要回滚：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh revert
```

它会删除 shell 层和用户会话层的托管内容。

如需单独回滚：

```bash
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh revert-shell
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh revert-user
bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh revert-system
```

## 验证

修复后新开一个交互式 shell，再检查：

```bash
env | rg -i '^(all|http|https|no)_proxy='
```

预期至少看到：

```text
ALL_PROXY=socks5://127.0.0.1:10808
HTTP_PROXY=http://127.0.0.1:10808/
HTTPS_PROXY=http://127.0.0.1:10808/
NO_PROXY=localhost,127.0.0.0/8,::1
```

如果是当前 shell 立刻验证，可直接执行：

```bash
eval "$(
  bash linux-proxy-socks5-socket-fix/scripts/fix_linux_proxy_socket.sh print-exports --shell bash
)"
```

若要验证用户会话层，再检查：

```bash
systemctl --user show-environment | rg -i '^(all|http|https|no)_proxy='
```

## 安全规则

- 默认 `apply` 只改用户级 shell + user session，不默认写系统级 `/etc/environment.d`
- 默认不关闭代理，不删除 V2rayN/Clash/sing-box，也不改系统 DNS
- `apply-system` / `revert-system` 会动 `/etc/environment.d`，影响更大，执行前应明确确认
- 若用户要求修改 NetworkManager、GNOME 系统代理、`/etc/environment` 本体，需要单独确认

## 参考

- 更详细的判断思路和兼容性说明见：
  [references/proxy-socket-runbook.md](references/proxy-socket-runbook.md)
