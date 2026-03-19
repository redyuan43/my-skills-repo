---
name: vnc-client-connect
description: 在 Linux 客户端上一键连接远端 VNC 服务，支持 `host`、`host:display` 和 `host:port` 输入，并自动选择本机可用的 VNC viewer。适用于“给客户端一个连接脚本”“从另一台 Linux 电脑连 VNC”“不想手工敲 viewer 参数”这类场景。
---

# VNC Client Connect

Use this skill on the client machine that will connect to a remote VNC server.

This skill is intentionally client-side only:

- It does not install or configure VNC on the server
- It does not repair Chromium or Snap permissions on the server
- It does not change remote host state

For server-side setup and Chromium recovery, use:
- `headless-vnc-chromium-fix`

## Canonical Entry Point

```bash
bash vnc-client-connect/scripts/connect_vnc.sh <target>
```

Supported target forms:

- `192.168.31.10`
- `192.168.31.10:1`
- `192.168.31.10:5901`
- `my-server.local`

Default behavior:

- If only a host is provided, connect to display `:1`
- If `:N` is provided and `N <= 99`, treat it as a VNC display number
- If `:PORT` is provided and `PORT >= 100`, treat it as a TCP port

## Viewer Selection

The script prefers viewers in this order:

1. `xtigervncviewer`
2. `vncviewer`
3. `gvncviewer`
4. `remmina`

If no supported viewer is installed, print a clear install hint and exit non-zero.

## Examples

```bash
bash vnc-client-connect/scripts/connect_vnc.sh 192.168.31.10
bash vnc-client-connect/scripts/connect_vnc.sh 192.168.31.10:1
bash vnc-client-connect/scripts/connect_vnc.sh 192.168.31.10:5901
```

## Notes

- This skill currently targets Linux clients only
- It does not manage password files
- It preserves viewer errors instead of hiding them
