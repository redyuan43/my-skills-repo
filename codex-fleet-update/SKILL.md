---
name: codex-fleet-update
description: Maintain Codex CLI across multiple SSH-accessible Linux devices. Use when Codex works on some machines but not others, when `codex --version` differs across a fleet, when nvm/npm only appears in interactive bash, or when the user wants an on-demand `codex-update` command instead of a timer.
---

# Codex Fleet Update

Use this skill to keep `@openai/codex` aligned across a small SSH fleet without background polling.

## Core Pattern

Prefer an on-demand reconciler:

1. Query npm once for the target `@openai/codex` version.
2. SSH to each host.
3. Run checks inside `bash -ic`, because many devices initialize nvm/npm/Codex only from interactive shell startup.
4. Install only when the remote version differs.
5. Verify `codex --version` after installation.
6. Log per-host results.

Do not add a timer unless the user explicitly wants background polling. Codex releases are not frequent enough to justify regular checks for this use case; the operator usually notices an update and then wants to update the rest of the devices.

## Installed Command

If the local fleet command exists, use it:

```bash
codex-update
```

Useful modes:

```bash
codex-update --check
codex-update --hosts "nano nx1 nx2"
codex-update --target 0.125.0
```

The script template lives at `scripts/codex-update.sh`. Install or refresh it with:

```bash
install -m 755 scripts/codex-update.sh "$HOME/.local/bin/codex-update"
```

To distribute the command to known hosts:

```bash
for h in nano nx1 nx2 agx AMD ivan edge spark; do
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$h" 'mkdir -p ~/.local/bin'
  scp -q -o BatchMode=yes -o ConnectTimeout=10 "$HOME/.local/bin/codex-update" "$h":~/.local/bin/codex-update
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$h" 'chmod +x ~/.local/bin/codex-update'
done
```

## Diagnostics

When `ssh host 'codex --version'` fails but an interactive session works, compare these:

```bash
ssh host 'command -v codex || true; echo "$PATH"'
ssh -tt host 'bash -ic "command -v codex; codex --version; command -v npm; npm --version"'
```

If only the second command finds Codex, the fix is not reinstalling blindly; use `bash -ic` for fleet automation so `.bashrc`/nvm initialization is loaded.

## Proxy Notes

For devices that need the local VPN/proxy to reach OpenAI, use SSH reverse forwarding plus a remote shell env file:

```sshconfig
Host nano
  RemoteForward 127.0.0.1:17890 127.0.0.1:10808
```

Remote shell snippet:

```bash
export HTTP_PROXY="http://127.0.0.1:17890/"
export HTTPS_PROXY="http://127.0.0.1:17890/"
export ALL_PROXY="socks5://127.0.0.1:17890"
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export all_proxy="$ALL_PROXY"
export NO_PROXY="localhost,127.0.0.0/8,::1"
export no_proxy="$NO_PROXY"
```

Validate OpenAI reachability with:

```bash
curl -sS -o /dev/null -w "openai_http=%{http_code} remote_ip=%{remote_ip}\n" --max-time 15 https://api.openai.com/v1/models
```

`401` is a successful connectivity signal for an unauthenticated probe.

## Verification Checklist

- `codex-update --check` completes with zero failed hosts.
- Every host reports the same target version.
- Hosts using nvm show Codex under the expected nvm path in `bash -ic`.
- Proxy-bound hosts return `openai_http=401` from the OpenAI probe.
- The command is installed at `~/.local/bin/codex-update` on each device if the user wants local trigger parity.

See `references/field-notes.md` for the incident notes that shaped this workflow.
