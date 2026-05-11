# Edge/Spark Field Notes

- Spark's working pattern was `xray run -c config.json` listening on `127.0.0.1:10808`, with Tailscale as normal `tailscaled.service`.
- Edge does not need v2rayN GUI; use the generated Xray config plus an ARM64 Xray binary.
- Configure `tailscaled` with a systemd drop-in pointing proxy variables at `127.0.0.1:10808`.
- If `tailscale up` prints a login URL, pause for browser authorization.
- Before `ssh-copy-id`, skip peers that are offline in `tailscale status --json` or whose SSH port is closed.
