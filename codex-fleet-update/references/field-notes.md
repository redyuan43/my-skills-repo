# Field Notes

## July 2026 Fleet Migration

The original reconciler queried:

```bash
npm view @openai/codex version
```

That became unsafe for the Siyuan fleet. On 2026-07-13:

- npm `@openai/codex@latest` reported `0.144.3`.
- the latest `redyuan43/codex` GitHub release was
  `siyuan-v0.145.0-alpha.4-siyuan.1`.
- devices already running the newer Siyuan build were incorrectly reported as
  failures.
- the default host list omitted `nano2`, `nano3`, `nx3`, and `nx4`.

The updater now treats the latest GitHub Siyuan release as the source of truth.

## Installation Layout

Executable archives contain:

- `codex`
- `codex-linux-sandbox`
- `README.txt`

The updater extracts them into:

```text
~/.local/share/siyuan-codex/<version>/
```

It adds a small version-local `siyuan-codex` wrapper and atomically switches:

```text
~/.local/bin/codex
~/.local/bin/siyuan
```

Both links point to the wrapper in the selected version directory. Keeping the
binary and `codex-linux-sandbox` together preserves runtime discovery while
allowing old versions to remain available for rollback.

## Architecture Mapping

| `uname -m` | Release asset |
| --- | --- |
| `aarch64`, `arm64` | `aarch64-unknown-linux-musl` |
| `x86_64`, `amd64` | `x86_64-unknown-linux-musl` |

Unknown architectures fail closed instead of receiving an incompatible binary.

## Connectivity

The controller downloads GitHub assets once and sends them over SSH. Remote
devices do not need GitHub or npm connectivity, which avoids per-device proxy
drift.

Some Tailscale devices may be connected through a high-latency DERP relay
instead of a direct peer-to-peer path. A one-shot `scp` upload loses all
progress when that connection drops. The updater therefore uses:

```bash
rsync --partial --append-verify
```

Uploads also use SSH keepalives and up to five retries with short backoff.
Existing partial files remain in `/tmp`, so a retry resumes instead of sending
the entire compressed archive again.

Interactive Bash is still used for version checks because several devices
define `codex` as an alias in `.bashrc`.

## Known Device Aliases

The NX and Nano fleet consists of these distinct hosts:

```text
nano  nano2  nano3  nx1  nx2  nx3  nx4
```

`nano` and `nano1` address the same device, so only `nano` belongs in the
default list.
