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
If `profile_name` is omitted, the default name is `RDP_<server>`, for example `RDP_192.168.100.165_3389.remmina`.

If the client is another Linux machine reachable over SSH, use:

```bash
bash headless-rdp-remmina-audio/scripts/push_remmina_profile_via_ssh.sh <client-ssh-target> <server[:port]> [username] [profile_name]
```

This writes the same `.remmina` profile directly on the remote client under `~/.local/share/remmina/`.
If `profile_name` is omitted, it uses the same `RDP_<server>` naming rule.

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

### PipeWire-based xrdp audio

On Ubuntu 24.04 and other PipeWire desktops, prefer the packaged PipeWire xrdp module when available:

```bash
dpkg -l | rg 'pipewire-module-xrdp|libpipewire-0.3-modules-xrdp|xrdp|xorgxrdp'
dpkg -L pipewire-module-xrdp libpipewire-0.3-modules-xrdp | rg 'load_pw_modules|libpipewire-module-xrdp|pipewire-xrdp.desktop'
```

Expected files include:

- `/usr/libexec/pipewire-module-xrdp/load_pw_modules.sh`
- `/usr/lib/*/pipewire-0.3/libpipewire-module-xrdp.so`
- `/etc/xdg/autostart/pipewire-xrdp.desktop`

After a real RDP login, verify the xrdp channel sockets:

```bash
lsof -U -a -p "$(pgrep -u "$USER" -n xrdp-chansrv)" | rg 'audio|xrdp_chansrv'
```

Expected socket names:

- `/run/xrdp/sockdir/xrdp_chansrv_audio_out_socket_<display>`
- `/run/xrdp/sockdir/xrdp_chansrv_audio_in_socket_<display>`

Load the module only after those sockets exist. `XRDP_SOCKET_PATH` is the directory, but `XRDP_PULSE_SINK_SOCKET` and `XRDP_PULSE_SOURCE_SOCKET` must be socket basenames, not absolute paths:

```bash
display_id=10
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
export XRDP_SESSION=1
export XRDP_SOCKET_PATH=/run/xrdp/sockdir
export XRDP_PULSE_SINK_SOCKET="xrdp_chansrv_audio_out_socket_$display_id"
export XRDP_PULSE_SOURCE_SOCKET="xrdp_chansrv_audio_in_socket_$display_id"
/usr/libexec/pipewire-module-xrdp/load_pw_modules.sh
```

Validate server-side audio routing:

```bash
pactl info | rg 'Default (Sink|Source)'
pactl list short sinks
pactl list short sources | rg 'xrdp|monitor'
```

Expected state:

- default sink is `xrdp-sink`
- default source is `xrdp-source`
- `xrdp-sink` becomes `RUNNING` while audio is playing
- `xrdp_chansrv_audio_out_socket_<display>` becomes `CONNECTED` while audio is playing

Common pitfall: if logs show a doubled path such as this, the socket variables are wrong:

```text
trying to connect to /run/xrdp/sockdir//run/xrdp/sockdir/xrdp_chansrv_audio_out_socket_10
```

Fix by keeping `XRDP_SOCKET_PATH=/run/xrdp/sockdir` and changing `XRDP_PULSE_SINK_SOCKET` to only `xrdp_chansrv_audio_out_socket_10`.

## Remmina Client Workflow

Install Remmina on the Linux client:

```bash
sudo apt-get update
sudo apt-get install -y remmina remmina-plugin-rdp freerdp2-x11
```

Use the bundled script to write a stable profile:

```bash
bash headless-rdp-remmina-audio/scripts/write_remmina_profile.sh <server-ip>:3389 <server-user>
```

The script writes a profile which:

- enables local audio output with `sound=local`
- selects PulseAudio/PipeWire output explicitly with `audio-output=sys:pulse` when supported by the Remmina version
- keeps clipboard enabled
- uses client resolution mode
- prefers `16bpp` as the default color depth
- enables keyboard grab for better pass-through of key combinations

Open the profile explicitly if Remmina does not refresh the list:

```bash
remmina -c ~/.local/share/remmina/RDP_<server-ip>_3389.remmina
```

If the server has multiple LAN addresses, prefer the address on the interface the client actually reaches, for example the wired NIC address instead of Wi-Fi when both exist.

If the client already has an old `.remmina` profile pointing at a stale IP or stale username, back it up first and write a new profile instead of trying to patch every historical option by hand.

Prefer profile names that mirror the actual target, such as `RDP_192.168.100.165_3389`, instead of semantic suffixes like `direct`. The connection endpoint belongs in `server=IP:port`, and the profile name should stay descriptive but literal.

For the normal "hear remote audio on this client" case, keep Remmina sound set to local:

- `sound=local` means remote desktop audio is redirected to the Remmina client.
- `sound=remote` means audio stays on the remote machine's physical/HDMI audio device.
- `audio-output=sys:pulse` forces FreeRDP/Remmina to output through the client's PulseAudio-compatible PipeWire server.

Patch an existing profile non-interactively:

```bash
remmina --update-profile ~/.local/share/remmina/RDP_<server-ip>_3389.remmina \
  --set-option sound=local \
  --set-option audio-output=sys:pulse
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

### Audio sink exists but the user cannot hear sound

Use facts from both ends before changing more settings.

On the server, play a known file with an audio track and inspect the xrdp sink plus chansrv socket:

```bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
timeout 10 ffplay -nodisp -autoexit -loglevel error /path/to/file.mp4 &
sleep 2
pactl list short sink-inputs
lsof -U -a -p "$(pgrep -u "$USER" -n xrdp-chansrv)" | rg 'audio|xrdp_chansrv'
```

Good server-side signs:

- `pactl list short sink-inputs` shows the player stream attached to `xrdp-sink`
- `xrdp_chansrv_audio_out_socket_<display>` shows `CONNECTED`, not only `LISTEN`

On the client, inspect whether Remmina/FreeRDP reached the local audio server:

```bash
pactl list sink-inputs | rg -n 'Sink Input|Sink:|Mute:|Volume:|application.name|application.process.binary|media.name|node.name'
pactl list short sinks
pactl get-default-sink
```

Good client-side signs:

- a sink input exists with `application.name = "freerdp"` and `application.process.binary = "remmina"`
- the `freerdp` sink input is not muted and volume is not `0%`
- the sink it routes to is the device the user is actually listening to

If the user still hears nothing but the `freerdp` sink input exists, test local output first:

```bash
timeout 3 speaker-test -t sine -f 440 -c 2
```

If this local test is also silent, the RDP path is probably working and the remaining issue is the client's default output route, mixer state, physical speakers, HDMI target, or USB speaker selection. Move the FreeRDP stream or change the default sink, for example:

```bash
pactl set-default-sink <client-sink-name>
pactl move-sink-input <freerdp-sink-input-id> <client-sink-name>
```

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
