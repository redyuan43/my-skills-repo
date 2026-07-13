---
name: codex-fleet-update
description: Keep Siyuan Codex aligned across SSH-accessible Linux devices by resolving the latest redyuan43/codex GitHub release, selecting the correct architecture asset, verifying checksums, and atomically updating codex/siyuan launchers. Use when NX, Nano, Jetson, x64, or mixed fleet devices have different Siyuan Codex versions.
---

# Siyuan Codex Fleet Update

Use this skill to align a small SSH fleet with Siyuan Codex releases from
`redyuan43/codex`.

## Core Pattern

Prefer the installed on-demand reconciler:

```bash
codex-update
```

The reconciler:

1. Resolves the latest GitHub Release from `redyuan43/codex`.
2. Requires a `siyuan-v*` release tag and derives the target CLI version.
3. Checks each host through interactive Bash so existing aliases remain visible.
4. Detects `aarch64` or `x86_64` per host.
5. Downloads each required executable archive once on the controller.
6. Verifies the archive against the Release checksum file.
7. Uses resumable `rsync` uploads with SSH keepalives and retries for VPN links.
8. Installs into `~/.local/share/siyuan-codex/<version>/`.
9. Atomically switches both `~/.local/bin/codex` and
   `~/.local/bin/siyuan`.
10. Verifies the selected launcher reports the target version.

This workflow intentionally does not use `npm view @openai/codex version` or
`npm install @openai/codex@latest`. The official npm version can lag or differ
from the latest Siyuan release and can cause an accidental downgrade.

## Commands

Check every known device without installing:

```bash
codex-update --check
```

Update only the NX and Nano fleet:

```bash
codex-update --hosts "nano nano2 nano3 nx1 nx2 nx3 nx4"
```

Pin a specific Siyuan release:

```bash
codex-update --target 0.145.0-alpha.4-siyuan.1
```

`--target` also accepts the full tag:

```bash
codex-update --target siyuan-v0.145.0-alpha.4-siyuan.1
```

## Installation

Install or refresh the command on the controller:

```bash
install -m 755 scripts/codex-update.sh "$HOME/.local/bin/codex-update"
```

Requirements on the controller:

- authenticated or public-access `gh`
- `ssh` and `rsync`
- `sha256sum`

Remote devices only need SSH access, `bash`, `tar`, `rsync`, and a supported
Linux architecture (`aarch64` or `x86_64`).

## Safety

风险控制：

- Run `codex-update --check` before a fleet-wide update when the target or host
  inventory is uncertain.
- Release archives must pass the published SHA-256 check before upload.
- The remote launcher changes only after extraction and a successful temporary
  binary version check.
- Existing older version directories remain available for rollback.
- Unsupported architectures and version mismatches fail closed.

The update changes executable links on remote devices, so confirm the intended
host list before using a broad `--hosts` value.

Run the non-destructive self-test with:

```bash
scripts/selftest.sh --safe
```

## Verification

- `codex-update --check --hosts "nano nano2 nano3 nx1 nx2 nx3 nx4"` exits 0.
- Every device reports the same GitHub-derived target.
- `readlink -f ~/.local/bin/codex` points into the selected version directory.
- `codex --version` and `siyuan --version` report the same target.

See `references/field-notes.md` for the migration from the obsolete npm-based
workflow.
