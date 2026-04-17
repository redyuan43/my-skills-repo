---
name: lan-ssh-alias-and-key-setup
description: Scan a LAN for SSH hosts with shared credentials, map duplicate IPs or hostnames back to one machine, update `~/.ssh/config` aliases without confusing them with remote Linux usernames, and restore passwordless login with `ssh-copy-id`. Use when LAN device IPs drift, one machine appears on both Wi-Fi and Ethernet, or the user wants host aliases like `nx1` / `nx2` corrected without renaming remote accounts.
---

# LAN SSH Alias And Key Setup

Use this skill when the user wants to:
- scan a LAN such as `192.168.100.0/24` for SSH hosts
- find which IPs accept a shared username/password such as `nx` / `nx`
- determine whether two IPs belong to one machine because hostname matches
- update `~/.ssh/config` aliases such as `nx1`, `nx2`, `agx`, `dgx`
- restore passwordless SSH with `ssh-copy-id`
- avoid mixing up local SSH alias names with remote Linux account names

## Core Rule

Treat these as different things:

- SSH alias: local name in `~/.ssh/config`, for example `nx1`
- remote username: Linux account used by SSH, for example `nx`
- hostname: what the remote machine reports, for example `BUS002-GPU`

Do not rename the remote Linux account unless the user explicitly asks for a system account rename and confirms the risk.

## Workflow

1. Read `~/.ssh/config` and identify the current alias set.
2. Scan the target subnet for live hosts and open SSH port 22.
3. Test the requested shared credential only against reachable SSH hosts.
4. Group results by hostname so Wi-Fi and Ethernet addresses of the same box are recognized as one machine.
5. Confirm which IP should be preferred in `~/.ssh/config`.
6. Update aliases in `~/.ssh/config` only after reading the existing file.
7. Run `ssh-copy-id` for the corrected alias and verify with `ssh -o BatchMode=yes`.

## Quick Scan

Use the bundled script:

```bash
python3 scripts/scan_lan_ssh_hosts.py \
  --subnet "192.168.100.0/24" \
  --username "nx" \
  --password "nx"
```

Prefer `--json` if the result will feed another script:

```bash
python3 scripts/scan_lan_ssh_hosts.py \
  --subnet "192.168.100.0/24" \
  --username "nx" \
  --password "nx" \
  --json
```

## Config Update Rules

- Keep alias naming stable even if IPs drift.
- If one hostname appears on multiple IPs, prefer Ethernet over Wi-Fi when the user wants a stable primary alias.
- If both links are useful, keep the main alias on Ethernet and add `-wifi` / `-eth` aliases.
- Do not copy `Include` lines from another machine if they reference local-only key paths that do not exist here.
- Back up `~/.ssh/config` before editing it.

## Passwordless Login Rules

- Before `ssh-copy-id`, remove stale `known_hosts` entries for the alias and the target IP if host key conflicts appear.
- If `ssh-copy-id` says the key already exists, still do a `BatchMode=yes` verification.
- If login fails because the network is unreachable or times out, stop and report it as connectivity, not credentials.

## Dangerous Operations

Ask for explicit confirmation before:
- renaming a remote Linux user
- editing remote `/etc/passwd`, `/etc/group`, or home directory paths
- making destructive SSH config changes that remove multiple aliases at once
- committing or pushing repo changes

## Resources

- `scripts/scan_lan_ssh_hosts.py`: scan a subnet, test one shared credential, and print hostname-grouped matches
