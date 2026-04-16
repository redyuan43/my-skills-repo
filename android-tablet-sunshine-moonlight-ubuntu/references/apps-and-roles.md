# Apps And Roles

This reference records the concrete apps used in the verified Ubuntu 24.x + Android tablet workflow.

## Recommended Primary Path

### Ubuntu host app

- App: `Sunshine`
- Role: host-side low-latency game/desktop streaming server
- Why it is used:
  - shares the current Ubuntu desktop
  - works well with Moonlight on Android
  - exposes a local Web UI and API for pairing and verification

Typical host checks:

```bash
systemctl --user status sunshine --no-pager
curl -kSs -o /dev/null -w '%{http_code}\n' https://127.0.0.1:47990
journalctl --user -u sunshine -n 80 --no-pager
```

### Android tablet app

- App: `Moonlight`
- Android package: `com.limelight`
- Role: Android streaming client for Sunshine
- Why it is used:
  - shows the current Ubuntu desktop on the tablet
  - supports pairing PIN flow with Sunshine
  - suitable when the user wants "当前屏幕共享"

Typical tablet checks:

```bash
adb shell cmd package resolve-activity --brief com.limelight
adb shell dumpsys window | tr -d '\000' | rg 'mCurrentFocus|mFocusedApp'
adb exec-out screencap -p > /tmp/tablet_verify.png
```

## Secondary Fallback Path

### Ubuntu host app

- App: `TigerVNC` / `Xvnc`
- Role: create an independent remote desktop session
- Why it may still be used:
  - useful when no hardware-backed real extra display exists
  - useful as a "quasi second screen" fallback

Important limitation:

- this is not the current Ubuntu desktop
- this is not a true OS-level extra monitor

### Android tablet app

- App: `AVNC`
- Android package: `com.gaurav.avnc`
- Role: Android VNC client for connecting to the independent VNC desktop

Important limitation:

- if the user says they want the current screen mirrored/shared, AVNC is the wrong primary path

## Decision Summary

- Current desktop on tablet:
  use `Sunshine` + `Moonlight`
- Independent extra remote workspace:
  use `TigerVNC` + `AVNC`
- True extended monitor:
  may require dummy HDMI / DisplayLink / virtual display support outside the scope of this skill
