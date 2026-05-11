---
name: edge-tailscale-proxy-ssh-bootstrap
description: Bootstrap an edge Linux device into the Tailscale network by reusing the current machine's v2rayN-generated Xray config, running a headless proxy without GUI, installing/logging in Tailscale through that proxy, then batch installing edge's SSH public key to reachable Tailscale devices while skipping offline hosts. Use when edge cannot reach Tailscale until v2ray/xray proxy is active, or when restoring edge -> fleet passwordless SSH.
---

# Edge Tailscale Proxy SSH Bootstrap

Use this skill when an edge device must:
- start a headless Xray proxy from the current machine's v2rayN generated `binConfigs/config.json`
- join or recover Tailscale without launching v2rayN GUI
- batch run `ssh-copy-id` from edge to reachable fleet devices
- skip devices that are offline in Tailscale or have SSH port 22 closed

## Core Rules

- Do not store real SSH passwords in skill files, repo files, shell history, or persistent scripts.
- Use a temporary password file on edge, `chmod 600`, then delete it after the run.
- Distinguish connectivity from credentials:
  - Tailscale offline means skip.
  - SSH port closed/unreachable means skip.
  - `ssh-copy-id` failure after reachability check is likely credentials or remote SSH policy.
- Prefer headless `xray run -c config.json` over launching v2rayN GUI on remote devices.
- Verify with `ssh -o BatchMode=yes` after every `ssh-copy-id`.

## Standard Workflow

1. From the current machine, confirm v2rayN has a generated Xray config:

```bash
test -r "$HOME/.local/share/v2rayN/binConfigs/config.json"
```

2. Run the local bootstrap script to prepare edge:

```bash
bash scripts/edge_tailscale_proxy_bootstrap.sh --edge edge
```

If Tailscale needs login, the script prints a login URL. Ask the user to open it and wait for success.

3. On edge, create a temporary password file:

```bash
cat > /tmp/edge-target-passwords.tsv <<'EOF'
nx@nx1.taild500c8.ts.net	<password>
nx@nx2.taild500c8.ts.net	<password>
agx@agx.taild500c8.ts.net	<password>
EOF
chmod 600 /tmp/edge-target-passwords.tsv
```

4. Run the edge batch key installer:

```bash
ssh edge 'bash ~/edge-copy-id-batch.sh --password-file /tmp/edge-target-passwords.tsv'
ssh edge 'rm -f /tmp/edge-target-passwords.tsv'
```

## Verification

On edge:

```bash
systemctl is-active edge-xray.service tailscaled.service
tailscale status
ssh -o BatchMode=yes nx@nx1.taild500c8.ts.net hostname
```

## Resources

- `scripts/edge_tailscale_proxy_bootstrap.sh`: local runner that prepares edge proxy + Tailscale.
- `scripts/edge_copy_id_batch.sh`: edge-side batch `ssh-copy-id` runner with offline skipping.
- `references/edge-spark-field-notes.md`: notes from the edge/spark setup case.
