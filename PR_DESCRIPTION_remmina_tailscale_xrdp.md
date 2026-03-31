## Summary

Add a new skill: `remmina-tailscale-xrdp`.

This skill standardizes the workflow for setting up and validating remote desktop access between a Linux server and a Linux client using:

- Tailscale
- xrdp
- XFCE
- Remmina

It covers both server-side and client-side setup, plus desktop performance optimization and connectivity verification.

## What This Solves

This skill is designed for cases like:

- Remmina works on LAN, but the user wants to keep using it from outside the LAN
- The user wants to keep `xrdp + XFCE` instead of switching to VNC or another protocol
- The user wants one repeatable workflow that:
  - checks the current server GUI session
  - installs/logs in Tailscale if needed
  - optimizes XFCE for remote desktop use
  - adjusts Remmina client settings
  - verifies Tailscale, MagicDNS, and RDP connectivity

In short, it turns an ad hoc remote desktop setup into a reusable skill.

## Included Workflow

The skill now documents and automates the reasoning for:

1. Detecting the current Linux GUI chain on the server
2. Checking whether Tailscale is installed and logged in on both sides
3. Installing and authorizing Tailscale on the server if needed
4. Checking xrdp listener and core config
5. Disabling XFCE compositing for better remote desktop responsiveness
6. Updating Remmina client profile to use the Tailscale address and 16bpp defaults
7. Verifying:
   - `tailscale ping`
   - MagicDNS resolution
   - TCP `3389` reachability

## Prompt Templates

### Long Form

Use `$remmina-tailscale-xrdp` to configure remote desktop connectivity between a Linux server and a Linux client over Tailscale using `xrdp + XFCE + Remmina`.  
Requirements:
1. Check whether the server is currently using `xrdp + XFCE`
2. Check whether both client and server have Tailscale installed and logged in
3. Install and authorize Tailscale on the server if needed
4. Optimize XFCE by disabling compositing
5. Optimize the Remmina client profile, preferring 16bpp and the Tailscale address
6. Verify `tailscale ping`, MagicDNS, and TCP port `3389`
7. Report the final Remmina connection target

### Short Form

Use `$remmina-tailscale-xrdp` to configure and verify `Tailscale + xrdp + XFCE + Remmina` remote desktop connectivity between a Linux server and client, including performance tuning.

## Problems Solved in This Iteration

- Standardized a repeatable setup path for `Tailscale + xrdp + XFCE + Remmina`
- Added clear verification steps for both Tailscale and RDP
- Included practical XFCE remote desktop optimization
- Included Remmina client parameter guidance
- Included guidance for handling common false-negative cases during Tailscale startup

## Remaining Limitations / Follow-ups

- The documented path is optimized for “remote login to this host itself”, not advanced routing use cases
- It assumes Linux server + Linux client; other client platforms are not yet explicitly covered
- It does not cover VNC / GNOME Remote Desktop / physical-session sharing workflows
- It does not cover WireGuard-based alternatives
- If the server later becomes a subnet router / exit node / custom firewall host, the current Tailscale firewall guidance should be re-evaluated instead of reused blindly

## Files Added / Updated

- `remmina-tailscale-xrdp/SKILL.md`
- `README.md`
