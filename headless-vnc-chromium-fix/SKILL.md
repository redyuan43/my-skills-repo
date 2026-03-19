---
name: headless-vnc-chromium-fix
description: 在无显示器的 Ubuntu/Linux 机器上安装 TigerVNC + XFCE，远程打开桌面，并修复 Chromium 因 Snap 包装、图形会话缺失或 snap-confine 权限异常而无法启动的问题。适用于“没接显示器”“想装 VNC”“Chromium 打不开”“snap-confine 权限不对”这类场景。
---

# Headless VNC Chromium Fix

Use this skill when a Linux machine has no monitor attached, the user needs a remote desktop, and Chromium will not launch from a tty or headless session.

This is the server-side skill:

- install and start VNC on the remote Linux host
- repair server-side Chromium and Snap issues
- tell the user which address the client should connect to

It is not the client connector. For a client-side launcher script, use:
- `vnc-client-connect`

## What This Skill Covers

- Detect whether the current session is headless (`DISPLAY` empty, `XDG_SESSION_TYPE=tty`)
- Install a lightweight remote desktop stack with TigerVNC + XFCE
- Create a working `~/.vnc/xstartup`
- Start a VNC desktop on `:1`
- Explain how the remote client connects
- Diagnose Ubuntu's transitional `chromium-browser` package and Snap-backed Chromium
- Repair `snap-confine` when ownership or mode is broken

## Quick Diagnosis

Check the session type first:

```bash
echo "DISPLAY=$DISPLAY"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
command -v chromium-browser
command -v chromium
dpkg -l | rg -i '^ii\s+chromium|^ii\s+snapd'
```

If `DISPLAY` is empty and `XDG_SESSION_TYPE=tty`, Chromium is not failing as a normal desktop app. It has no GUI session to attach to.

## Ubuntu Chromium Note

On Ubuntu 22.04, `chromium-browser` is usually a transitional package that execs the Snap app:

```bash
sed -n '1,160p' /usr/bin/chromium-browser
```

That means Chromium troubleshooting is usually Snap troubleshooting plus GUI-session troubleshooting.

## Preferred Headless Desktop Workflow

Install a lightweight desktop instead of fighting a full GNOME login flow:

```bash
sudo apt-get update
sudo apt-get install -y tigervnc-standalone-server xfce4 xfce4-goodies dbus-x11
```

Create `~/.vnc/xstartup`:

```sh
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

exec startxfce4
```

Set permissions and VNC password:

```bash
chmod 700 ~/.vnc/xstartup
vncpasswd
```

Start VNC on display `:1`:

```bash
vncserver :1 -localhost no -geometry 1920x1080 -depth 24
```

Remote clients connect to:

- `<host-ip>:5901`
- or `<host-ip>:1`

## Chromium Repair Workflow

If Chromium still does not launch after VNC is up:

1. Check whether `snap-confine` has the expected owner and setuid bit:

```bash
stat -c '%U %G %a %n' /usr/lib/snapd/snap-confine
ls -l /usr/lib/snapd/snap-confine
```

Expected state:

- owner: `root root`
- mode: `4755`
- long listing begins with `-rwsr-xr-x`

2. If it is wrong, repair it:

```bash
sudo chown root:root /usr/lib/snapd/snap-confine
sudo chmod 4755 /usr/lib/snapd/snap-confine
sudo systemctl restart snapd
```

You can also use the bundled script:

```bash
bash headless-vnc-chromium-fix/scripts/repair_snap_confine.sh
```

3. Then test Chromium from the VNC desktop, not from a bare tty:

```bash
chromium
```

## Important Validation Note

If Chromium is being tested from an external agent or sandboxed shell, Snap may still fail there even after the host is repaired. Do not over-trust those results. The meaningful test is inside the real VNC/XFCE session on the target machine.

## Logs and Checks

Useful checks:

```bash
ls -la ~/.vnc
tail -n 120 ~/.vnc/*.log
snap debug sandbox-features
dpkg -V snapd
```

## When To Escalate

Pause and realign with the user before:

- opening VNC to non-localhost interfaces on an internet-exposed machine
- reusing the Linux login password as the VNC password
- changing firewall policy
- replacing Snap Chromium with another browser distribution path
