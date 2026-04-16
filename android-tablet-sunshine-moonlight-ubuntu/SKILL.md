# android-tablet-sunshine-moonlight-ubuntu

Use when the user wants to share the current Ubuntu desktop to an Android tablet, or is confused between "mirror/current screen share" and "true extended second monitor".

This skill is for Ubuntu 24.x + Android tablet + ADB-connected workflows.

## What This Skill Solves

- Install and verify Sunshine on Ubuntu.
- Sideload Moonlight to Android through `adb`.
- Pair the Android tablet with Sunshine.
- Record exactly which Ubuntu-side and Android-side apps belong to each path.
- Confirm whether the tablet is showing the current Ubuntu desktop.
- Read the tablet's real display size and density through `adb`.
- Explain the boundary between:
  - current-screen sharing with Sunshine + Moonlight
  - independent remote desktop with VNC
  - true extended monitor output that usually needs a display sink, virtual display stack, or hardware workaround

## Use This Skill For

- "把当前 Ubuntu 屏幕共享到安卓平板"
- "我想用平板当副屏，但先接受镜像/共享当前屏幕"
- "用 adb 看一下平板分辨率，然后按这个分辨率调"
- "Moonlight / Sunshine 装好并帮我验证是否真的连通"
- "为什么我看到的是 VNC 独立桌面，不是当前桌面？"

## Do Not Use This Skill For

- Users who explicitly need a true OS-level extended monitor with separate mouse space and native display output path.
- Users who only want an independent remote desktop session; use a VNC/XRDP-style skill instead.

## Decision Rule

1. If the user wants the current Ubuntu desktop on the tablet:
   use Sunshine + Moonlight.
2. If the user says "我看到的是另一个桌面，不是现在这个桌面":
   stop using VNC as the primary path and switch back to Sunshine + Moonlight.
3. If the user needs a true extended display:
   explain that Sunshine/Moonlight is screen streaming, not a real Linux monitor.
   A dummy HDMI/DisplayLink/virtual-display stack may be required.
4. If there is no hardware display sink and the user still wants "something like a second screen":
   the next-stable fallback is an independent VNC desktop, but it is not the current desktop and not a true extra monitor.

## Standard Workflow

Before operating, read:

- `references/apps-and-roles.md`

### A. Check host and tablet

Run:

```bash
adb devices -l
scripts/adb_tablet_display_info.sh
scripts/sunshine_moonlight_status.sh
```

Confirm:

- the tablet is listed as `device`, not `unauthorized`
- Sunshine service is active
- Sunshine Web UI is reachable
- the current X11 display layout is visible in `xrandr`

### B. Install Moonlight on Android

Use the repo or local helper that downloads the latest official Moonlight Android non-root APK and installs it with `adb install -r`.

If there is already an install helper available, reuse it instead of rewriting the logic.

### C. Pair Moonlight with Sunshine

If the user provides a PIN shown on the tablet, pair via Sunshine's local API.

Typical flow:

- initialize Sunshine credentials if first run
- call Sunshine `/api/pin`
- verify the client appears in Sunshine's client list

### D. Verify the tablet is showing the current desktop

Do all of the following:

1. Bring Moonlight to foreground on the tablet.
2. Check Android focus:

```bash
adb shell dumpsys window | rg 'mCurrentFocus|mFocusedApp'
```

3. Check recent Sunshine logs:

```bash
journalctl --user -u sunshine -n 80 --no-pager
```

Look for signals like:

- `New streaming session started`
- `CLIENT CONNECTED`
- `Screencasting with KMS`

4. Capture a tablet screenshot:

```bash
adb exec-out screencap -p > /tmp/tablet_verify.png
```

Inspect the screenshot to confirm the visible content is the real current Ubuntu desktop, not a separate VNC/XFCE session.

## Resolution Guidance

- Read the physical size from Android with `adb shell wm size`.
- Also inspect `adb shell dumpsys display`, because tablets may currently be rotated and the effective horizontal workspace can differ from the portrait physical value.
- Use the tablet resolution as a target only when the host display path can actually expose that mode.
- If `xrandr --addmode` succeeds but `xrandr --output ... --mode ...` fails with `Configure crtc failed`, the connector/GPU path likely does not accept that mode on the current sink.
- For Sunshine current-screen streaming, a safe fallback such as `1920x1080` is often more stable than forcing an unsupported exact tablet mode.

## Important Distinction

- Sunshine + Moonlight:
  shares the current host desktop.
- TigerVNC/Xvnc:
  creates an independent desktop session.
- Dummy HDMI / some virtual display methods:
  may allow a true extra monitor path.

If the user says "我希望是当前屏幕能够共享一个屏幕", Sunshine + Moonlight is the correct path.

## Common Pitfalls

- Sunshine package mismatch on Ubuntu 24.x can fail with missing ICU libraries.
  Prefer the official Ubuntu 24.04 package if the distro package is broken.
- Android app installed but not paired:
  Moonlight will open but cannot start the stream.
- VNC works, but the user thinks it is "same screen sharing":
  clarify that it is a separate desktop.
- ADB text input into some Android forms is unreliable.
  Prefer manual entry on-device when the app UI blocks reliable automation.

## Completion Checklist

- Tablet is visible in `adb devices -l`
- Sunshine service is active
- Moonlight is installed
- Pairing completed
- Sunshine log shows a live streaming session
- Tablet screenshot confirms the current Ubuntu desktop is being shown
- User is told clearly whether the result is:
  - mirror/current-screen share
  - independent desktop
  - or true extended display

## Files In This Skill

- `SKILL.md`
- `references/apps-and-roles.md`
- `scripts/adb_tablet_display_info.sh`
- `scripts/sunshine_moonlight_status.sh`
