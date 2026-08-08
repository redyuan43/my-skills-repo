# iPadOS Native SSH Notes

## Choose the native path first

Use a-Shell plus the iPadOS Tailscale app for SSH-only work. It has less state,
starts faster, and avoids UTM/JIT/guest-networking failure modes.

UTM is appropriate only when the user needs Linux executables, a package manager,
or a persistent Linux service. An iPadOS Tailscale node and a UTM guest are
separate network identities: the guest can use the iPad's outbound connectivity
but does not automatically become a tailnet node or inherit inbound SSH routing.

## a-Shell file location and control

- a-Shell bundle ID is commonly `AsheKube.app.a-Shell`; discover it instead of
  assuming it.
- The user-visible Documents container is `/Documents`; OpenSSH material belongs
  in `/Documents/.ssh`.
- House Arrest with `documents_only=True` is the least-privileged USB transfer
  path. Full-container access can fail for App Store applications.
- After writing files, use `ashell:` URL commands to run:

  ```sh
  chmod 700 ~/Documents/.ssh
  chmod 600 ~/Documents/.ssh/id_ed25519
  chmod 600 ~/Documents/.ssh/config
  ```

- URL commands are not a substitute for a general interactive shell parser.
  Use one command per URL. For redirects and compound commands, pass one quoted
  script to `sh -c`.

## Key distribution

Generate a unique iPad key with an empty passphrase only when the user wants
one-tap SSH. Keep its private half only in the a-Shell app container and the
temporary trusted provisioning host. Remove temporary copies after successful
verification.

For POSIX targets, append the public key idempotently and preserve existing
`authorized_keys` lines. Use mode `0700` for `.ssh` and `0600` for
`authorized_keys`.

For Windows OpenSSH, use the actual account's authorized-key file and validate
with a real public-key login. Do not assume POSIX permissions or file locations;
administrators can require `administrators_authorized_keys`, while ordinary
users commonly use `%USERPROFILE%\.ssh\authorized_keys`.

## Tailscale diagnosis

The following are distinct checks:

1. The iPad node appears online in `tailscale status`.
2. A peer can `tailscale ping` the iPad.
3. A terminal app on the iPad can make a real TCP connection to the target.
4. OpenSSH accepts the intended key.

Passing 1 or 2 does not prove 3. If a-Shell cannot resolve MagicDNS, obtain
current peer addresses from a trusted node with `tailscale status --json` and
use direct tailnet IPs as a config fallback. If direct `100.x` TCP also times
out, bring the Tailscale app forward and verify the iPadOS VPN state rather
than changing SSH keys or remote servers.

## Keep secrets out of records

Never put device passcodes, Apple ID secrets, VPN credentials, Tailscale auth
keys, SSH passwords, private keys, real UDIDs, or tailnet-specific hostnames in
the skill, git history, terminal logs, or published examples.
