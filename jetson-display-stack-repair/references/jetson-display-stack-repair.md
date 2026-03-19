# Jetson Display Stack Repair Reference

## Trigger Patterns

Use this workflow when a Jetson board boots with a black screen, no login UI, or a monitor that has signal but no desktop.

Common indicators:
- `graphical.target` is set, but the screen stays blank.
- `gdm3` is installed, but `display-manager.service` is missing or not linked.
- Logs show `drmSetMaster failed: Device or resource busy`.
- `nvweston.service` is enabled and competes with `gdm3`.

## Fast Checks

Run these in order:

```bash
systemctl get-default
systemctl status display-manager.service gdm.service gdm3.service
cat /etc/X11/default-display-manager
systemctl is-enabled nvweston.service
systemctl list-dependencies graphical.target
```

## Repair Order

1. If the target is wrong, set it to `graphical.target`.
2. If `nvweston.service` is enabled, disable and stop it first.
3. Restore `display-manager.service` to point at `gdm.service`.
4. Reload systemd and start `display-manager.service`.
5. Only after `gdm3` is active, inspect Xorg or hardware issues.

## Log Patterns

Look for these in `/var/log/Xorg.0.log` or `journalctl -u gdm.service`:

- `Device or resource busy`
- `drmSetMaster failed`
- `Failed to initialize the NVIDIA graphics device`
- `No modes were requested`

## Do Not Do First

- Do not rewrite `xorg.conf` before checking for service conflicts.
- Do not swap display drivers before confirming `gdm3` can own the DRM device.
- Do not treat a missing desktop as a pure target issue if `nvweston` is still enabled.
