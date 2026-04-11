---
name: chromium-v2ray-google-fix
description: 当 Linux 上的 Chromium 在已启动 `v2rayN/xray` 的情况下仍打不开 `www.google.com`，需要定位代理是否生效、识别局域网 DNS 污染、强制 Chromium 走本地 SOCKS/HTTP 代理，并生成指向 `~/.local/bin/chromium` 的桌面快捷方式时使用。
---

# Chromium V2Ray Google Fix

当用户说“Chromium/Chrome 能开百度但打不开 Google”“`www.google.com` 不通”“需要把修通后的浏览器能力固化成桌面图标”时，用这个 skill。

核心判断：

- 先分清是代理没起、浏览器没走代理，还是 DNS 被局域网污染。
- 若 `curl` 通过本地代理可以访问 Google，但浏览器不行，优先给 Chromium 加固定启动包装器。
- 若 `www.google.com` 被解析到可疑 IP，优先怀疑局域网 DNS 污染；这时浏览器必须禁用 `DnsOverHttps/AsyncDns/QUIC` 并强制走代理。
- 桌面快捷方式应指向 `~/.local/bin/chromium`，避免误用 Snap/Flatpak 原始入口。

## 标准工作流

1. 先诊断：

```bash
bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh diagnose
```

重点看：

- `v2rayN/xray` 是否在运行
- `127.0.0.1:10808` 是否监听
- `curl https://www.google.com` 与 `curl --socks5-hostname 127.0.0.1:10808 https://www.google.com` 是否成功
- `resolvectl query www.google.com` 是否返回可疑 IP

2. 若代理是通的，但浏览器不通，安装浏览器包装器与默认入口：

```bash
bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh apply-wrapper
```

它会：

- 写入 `~/bin/chromium-v2ray-launcher`
- 写入 `~/.local/bin/chromium`
- 写入/更新 `~/.local/share/applications/org.chromium.Chromium.desktop`
- 把 XDG 默认浏览器指向这个桌面项

3. 若用户需要桌面快捷方式：

```bash
bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh desktop
```

它会把桌面快捷方式固定到：

```text
Exec=/home/<user>/.local/bin/chromium %U
```

4. 若确认是局域网 DNS 污染，并且用户明确同意修改系统网络设置，再改 DNS：

```bash
bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh set-dns
```

默认写入：

- IPv4: `1.1.1.1 8.8.8.8`
- IPv6: `2606:4700:4700::1111 2001:4860:4860::8888`

脚本会尝试修改当前活跃的 `ethernet` / `wifi` NetworkManager 连接并重新激活。

## 一键模式

若用户已经明确同意修复浏览器入口和桌面快捷方式，可直接：

```bash
bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh all
```

若还要改 DNS，再执行：

```bash
bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh all --with-dns
```

## 验证

重新通过下面路径启动浏览器：

```bash
~/.local/bin/chromium
```

再确认运行中的 Chromium 进程包含这些关键参数：

- `--proxy-server=socks5://127.0.0.1:10808`
- `--disable-quic`
- `--disable-features=...DnsOverHttps...AsyncDns...`

还可在浏览器里执行：

- `chrome://net-internals/#dns` → `Clear host cache`
- `chrome://net-internals/#sockets` → `Flush socket pools`

## 安全规则

- 修改系统 DNS、删除 `xray`、卸载浏览器或改系统级 `/usr/bin` 入口前，必须先得到用户明确确认。
- 默认只改用户目录下的启动器、桌面项和 XDG 关联，不碰系统包。
- 若用户只是要查原因，不要直接修改 DNS。
