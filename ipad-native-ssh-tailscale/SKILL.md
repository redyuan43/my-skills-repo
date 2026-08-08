---
name: ipad-native-ssh-tailscale
description: Configure an iPadOS device for native, passwordless SSH to a Tailscale fleet using a-Shell instead of a full UTM Linux VM. Use when a user wants a Termux-like iPad terminal, wants to distribute a dedicated iPad SSH key and aliases, needs USB/CoreDevice file injection into a-Shell, or needs to diagnose why an iPad Tailscale node is online but terminal-app SSH fails.
---

# iPad Native SSH over Tailscale

Use a-Shell as the primary path when the goal is SSH development access. Do not
start with a UTM Linux VM unless the user genuinely needs Linux-only software.

## Workflow

1. Confirm the iPad has Tailscale and a-Shell installed. The user must approve
   App Store installation and enable the iPadOS VPN; do not bypass those prompts.
2. Verify the Tailscale data plane, not only control-plane presence:
   - From a trusted peer, run `tailscale ping <ipad-node>`.
   - From a-Shell, test a real TCP service on a reachable tailnet peer.
   - If the terminal cannot resolve MagicDNS, use current `100.x` tailnet IPs in
     the SSH config and record that this is a fallback.
3. Generate a dedicated unencrypted Ed25519 key for the iPad. Never reuse a
   workstation private key and never print, commit, or upload the private key.
4. Append only the new public key to each confirmed target's `authorized_keys`.
   Use a target-specific Windows procedure for Windows OpenSSH.
5. Push the key and config into `Documents/.ssh` in a-Shell with
   `scripts/push_ashell_ssh_files.py`. Use `--apply` only after inspecting the
   paths and after the user has confirmed the device.
6. Tighten a-Shell permissions with its URL command interface, then run actual
   passwordless SSH checks from a-Shell. Verify at least one Linux/macOS target
   and one Windows target when both are in scope.

## a-Shell Control

a-Shell supports the `ashell:` URL scheme. This is useful when a Mac has a
trusted USB/CoreDevice connection to the iPad.

- Use one simple command per URL.
- Do not place shell separators such as `;` directly in an `ashell:` command;
  they can become ordinary arguments.
- Wrap pipelines, redirects, or compound commands in `sh -c '...'`.
- `--terminate-existing` makes URL delivery reliable but kills active a-Shell
  jobs. Use it only during bootstrap or with explicit user approval.

Example command shape from macOS:

```bash
xcrun devicectl device process launch \
  --device "<coredevice-id>" \
  --activate \
  --terminate-existing \
  --payload-url "ashell:chmod%20700%20%7E%2FDocuments%2F.ssh" \
  "AsheKube.app.a-Shell"
```

For compound work, URL-encode this as one command:

```sh
sh -c 'ssh -o BatchMode=yes target hostname > ~/Documents/ssh-check.txt 2>&1'
```

Read [references/ios-native-ssh-notes.md](references/ios-native-ssh-notes.md)
before using UTM, modifying Windows authorization, or diagnosing Tailscale.

## Validation

Do not report success from configuration files alone. Confirm:

```sh
ssh -F ~/.ssh/config -o BatchMode=yes <alias> hostname
```

For each successful check, record the alias, target identity, and whether the
session used public-key authentication. Treat `tailscale ping` as path evidence,
not proof that terminal-app TCP works.
