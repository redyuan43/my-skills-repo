---
name: headless-rdp-remmina-audio
description: 在无显示器的 Ubuntu/Linux 主机上通过 `Remmina + RDP` 直连 `xrdp + XFCE` 远程桌面，启用音频重定向，并在 Linux 客户端生成可复用的 `.remmina` 配置；适用于“只靠远程登录主机”“客户端固定用 Remmina”“要听到服务器声音”“需要处理分辨率/剪贴板问题”这类场景。
---

# Headless RDP Remmina Audio

Use this skill as the default direct-connect path when the user wants a Linux host to be reached from a Linux client through `Remmina` in `RDP` mode, with working desktop audio on the client.

The primary path in this skill is client-first:

- client-side `Remmina` profile generation for direct `server:3389` access
- the expected server-side target is `xrdp + XFCE`
- troubleshooting for low resolution, session startup failures, and clipboard quirks

This skill is not for:
- `VNC server` setup or migration as part of the main flow
- Tailscale or other internet-facing overlay access
- physical desktop sharing

If the user explicitly requires VNC, use:
- `headless-vnc-chromium-fix`
- `vnc-client-connect`

If the user explicitly needs Tailscale or off-LAN access, use:
- `remmina-tailscale-xrdp`

## Canonical Entry Point

The canonical client-side entry point is:

```bash
bash headless-rdp-remmina-audio/scripts/write_remmina_profile.sh <server[:port]> [username] [profile_name]
```

This writes a reusable `.remmina` profile for `Remmina` `RDP` mode against a direct `xrdp` listener.

If the client is another Linux machine reachable over SSH, use:

```bash
bash headless-rdp-remmina-audio/scripts/push_remmina_profile_via_ssh.sh <client-ssh-target> <server[:port]> [username] [profile_name]
```

This writes the same `.remmina` profile directly on the remote client under `~/.local/share/remmina/`.

## Server Workflow

This section is the minimum server-side prerequisite for the direct-connect path. If the server is already running a healthy `xrdp + XFCE` stack, skip to the Remmina client workflow.

Install the base RDP stack:

```bash
sudo apt-get update
sudo apt-get install -y xrdp xorgxrdp xfce4 xfce4-goodies dbus-x11 libpulse-dev libsndfile1-dev git
```

Ensure the target user starts `XFCE` for xrdp sessions by creating `~/.xsession`:

```sh
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

exec startxfce4
```

Set permissions:

```bash
chmod 700 ~/.xsession
```

Add the `xrdp` service user to `ssl-cert` so the daemon can read its key material:

```bash
sudo adduser xrdp ssl-cert
sudo systemctl restart xrdp-sesman.service xrdp.service
```

Useful validation:

```bash
systemctl status --no-pager xrdp.service xrdp-sesman.service
ss -ltnp | rg '3389'
```

## Audio Workflow

Ubuntu 22.04 commonly lacks a ready-made `pulseaudio-module-xrdp` package, so build it from the official repository.

Fetch the module source:

```bash
git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git /tmp/pulseaudio-module-xrdp
```

Install build helpers:

```bash
sudo apt-get install -y build-essential libltdl-dev pkg-config debootstrap schroot lsb-release
```

Prepare the PulseAudio source tree with the repo’s wrapper:

```bash
cd /tmp/pulseaudio-module-xrdp
./scripts/install_pulseaudio_sources_apt_wrapper.sh
```

Build and install:

```bash
cd /tmp/pulseaudio-module-xrdp
./bootstrap
./configure PULSE_DIR="$HOME/pulseaudio.src"
make -j"$(nproc)"
sudo make install
sudo systemctl restart xrdp-sesman.service xrdp.service
```

After a real RDP login, verify:

```bash
pactl info
pactl list short modules | rg 'xrdp'
pactl list short sinks
```

Expected state:

- default sink becomes `xrdp-sink`
- default source becomes `xrdp-source`

Client-side sound test from inside the remote desktop:

```bash
paplay /usr/share/sounds/alsa/Front_Center.wav
```

## Remmina Client Workflow

Install Remmina on the Linux client:

```bash
sudo apt-get update
sudo apt-get install -y remmina remmina-plugin-rdp freerdp2-x11
```

Use the bundled script to write a stable profile:

```bash
bash headless-rdp-remmina-audio/scripts/write_remmina_profile.sh <server-ip>:3389 <server-user> BUS002-GPU
```

The script writes a profile which:

- enables local audio output with `sound=local`
- keeps clipboard enabled
- uses client resolution mode
- prefers `16bpp` as the default color depth
- enables keyboard grab for better pass-through of key combinations

Open the profile explicitly if Remmina does not refresh the list:

```bash
remmina -c ~/.local/share/remmina/BUS002-GPU.remmina
```

If the server has multiple LAN addresses, prefer the address on the interface the client actually reaches, for example the wired NIC address instead of Wi-Fi when both exist.

If the client already has an old `.remmina` profile pointing at a stale IP or stale username, back it up first and write a new profile instead of trying to patch every historical option by hand.

## Troubleshooting

### Login succeeds then immediately exits

Check:

```bash
tail -n 120 ~/.xsession-errors
journalctl -b -u xrdp.service -u xrdp-sesman.service --no-pager | tail -n 120
```

On Jetson / NVIDIA images, `~/.xsessionrc` may contain Bash-only syntax while `Xsession` sources it with `/bin/sh`.

Typical failure:

```text
/etc/X11/Xsession: ... ~/.xsessionrc: Syntax error: "(" unexpected
```

Fix by converting Bash-only constructs to POSIX `sh` syntax.

### Resolution is too small

The authoritative source of truth is the xrdp log:

```bash
journalctl -b -u xrdp.service -u xrdp-sesman.service --no-pager | rg 'width |height '
```

If the session is negotiated as something tiny like `592x440`, the client is still opening a small window or not using client resolution mode.

Rewrite the Remmina profile with the bundled script and reconnect.

### Clipboard or “paste remote text” behaves badly

Check whether clipboard is enabled client-side:

```bash
grep -n 'disableclipboard' ~/.local/share/remmina/*.remmina
```

Check server logs:

```bash
journalctl -b --no-pager | rg -i 'clipboard|cliprdr|xrdp-chansrv'
```

Known bad sign:

```text
xrdp-chansrv: clipboard_event_selection_request: unknown target text/plain;charset=utf-8
```

In this state, ordinary clipboard handling may be flaky. The fastest recovery is:

- fully log out of the remote desktop session
- reconnect and create a fresh session

If the user only needs a working desktop and audio, avoid spending too much time on advanced clipboard quirks unless they are central to the task.

## Direct Cutover From TigerVNC

When replacing an existing `tigervncserver@:1.service` path with `xrdp`, the reliable order is:

1. Install and start `xrdp + xorgxrdp`.
2. Write `~/.xsession` and `~/.xsessionrc` for `XFCE`.
3. Validate `3389` is listening and reachable.
4. Only then disable and stop `tigervncserver@:1.service`.

Minimal command sequence:

```bash
sudo apt-get update
sudo apt-get install -y xrdp xorgxrdp dbus-x11
chmod 755 ~/.xsession
chmod 644 ~/.xsessionrc
sudo adduser xrdp ssl-cert
sudo systemctl restart xrdp-sesman xrdp
systemctl is-active xrdp xrdp-sesman
ss -ltnp | rg ':3389\b|xrdp'
sudo systemctl disable --now tigervncserver@:1.service
```

Why this order matters:

- some machines already have `XFCE` and `TigerVNC`, but no `xrdp` installed at all
- cutting off `VNC` first can strand the host
- leaving old `TigerVNC` running while testing `xrdp` can confuse session-state debugging

## When To Escalate

Pause and confirm with the user before:

- disabling the last remaining remote access path
- rebooting the host for validation
- exposing `3389` directly on an internet-exposed machine
- replacing the existing desktop stack instead of layering `xrdp` onto the current system
