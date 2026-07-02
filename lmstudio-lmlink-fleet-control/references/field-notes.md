# LM Link Field Notes

These notes capture a real Linux LM Studio / LM Link incident and should be used as a pattern, not as hard-coded state.

## Signals That Mattered

- `lms link status` is the decisive LM Link activation check.
- `lms whoami` verifies account state; editing `~/.lmstudio/.internal/user-profile.json` or similar cache files is not authentication.
- `lms server status` is separate from LM Link. The OpenAI-compatible server can be stopped while LM Link is online.
- Listener evidence such as `127.0.0.1:41343` indicates LM Studio internal services; `127.0.0.1:1234` indicates the local OpenAI-compatible API when enabled.

## edge Pattern

The `edge` host needed LM Studio started inside the desktop session from a non-GUI shell:

```bash
systemd-run --user --unit=lmstudio-manual --collect \
  --setenv=DISPLAY=:1 \
  --setenv=XAUTHORITY=/run/user/1000/gdm/Xauthority \
  --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  "$HOME/.local/bin/lmstudio" --no-sandbox --disable-gpu
```

Expected verification:

```text
This device: edge
Status: Online
```

## AMD Pattern

The AMD host used an LM Studio AppImage wrapper at `~/.local/bin/lmstudio` and SSH alias `AMD`.

The root problem was Electron GPU helper failure, not LM Link account failure. Logs included:

```text
GPU process isn't usable. Goodbye.
```

The wrapper kept LM Studio alive by setting software-render environment and adding flags such as:

```bash
LIBGL_ALWAYS_SOFTWARE=1
MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
ELECTRON_DISABLE_GPU=1
--no-sandbox
--disable-gpu
--disable-gpu-compositing
--disable-software-rasterizer
--disable-features=VizDisplayCompositor
--use-gl=disabled
--disable-dev-shm-usage
--disable-gpu-process-crash-limit
```

After the workaround, recurring `libva` / `radeonsi` messages were acceptable noise only if process and link checks were healthy.

Expected verification:

```bash
ssh AMD '~/.local/bin/lmlinkctl status'
```

Expected signal:

```text
This device: ivan-SuperAI
Status: Online
```

## Portable Rules

- Keep host-specific desktop, proxy, AppImage, and GPU quirks in `~/.local/bin/lmstudio`.
- Keep fleet-level status/start/restart behavior in `lmlinkctl`.
- Prefer SSH aliases from the user's `~/.ssh/config`; do not hard-code tailnet hostnames into the skill unless a task requires it.
- Use `$HOME` paths in instructions and scripts so the skill can be copied to different Linux users.
