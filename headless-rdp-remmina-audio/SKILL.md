---
name: headless-rdp-remmina-audio
description: 在无显示器的 Ubuntu/Linux 主机上部署 `xrdp + XFCE` 远程桌面，启用音频重定向，并在 Linux 客户端用 Remmina 建立可复用的 RDP 配置；适用于“只靠远程登录主机”“要听到服务器声音”“想替代 VNC”“需要处理分辨率/剪贴板问题”这类场景。
---

# Headless RDP Remmina Audio

Use this skill when the user wants a headless Linux machine to be reachable through RDP rather than VNC, with working desktop audio on the client.

This skill covers both sides:

- server-side `xrdp + XFCE`
- client-side `Remmina` profile generation
- troubleshooting for low resolution, session startup failures, and clipboard quirks

It is not for pure VNC deployments. If the user explicitly requires VNC, use:
- `headless-vnc-chromium-fix`
- `vnc-client-connect`

## Server Workflow

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
bash headless-rdp-remmina-audio/scripts/write_remmina_profile.sh 192.168.31.40:3389 nx BUS002-GPU
```

The script writes a profile which:

- enables local audio output with `sound=local`
- keeps clipboard enabled
- uses client resolution mode
- enables keyboard grab for better pass-through of key combinations

Open the profile explicitly if Remmina does not refresh the list:

```bash
remmina -c ~/.local/share/remmina/BUS002-GPU.remmina
```

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

## Migration Notes

During cutover from VNC:

1. Keep the existing VNC path as fallback.
2. Validate `xrdp`, audio, resolution, and reconnect behavior.
3. Then disable old services such as `x11vnc.service` and `tigervncserver@:1.service`.

Check ports:

```bash
ss -ltnp | rg '3389|5900|5901'
```

## When To Escalate

Pause and confirm with the user before:

- disabling the last remaining remote access path
- rebooting the host for validation
- exposing `3389` directly on an internet-exposed machine
- replacing the existing desktop stack instead of layering `xrdp` onto the current system
