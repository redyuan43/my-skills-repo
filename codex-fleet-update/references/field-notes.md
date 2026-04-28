# Field Notes

These notes come from configuring Codex CLI across a local SSH fleet.

## Device Outcomes

- `nano`: had `codex-cli 0.121.0`, no proxy environment, and OpenAI timed out. Adding SSH reverse forwarding and a remote proxy env fixed connectivity; `npm install -g @openai/codex@latest` updated it to `0.125.0`.
- `nx2`: had `codex-cli 0.125.0`, but proxy variables pointed at a mixed `10808`/`10809` setup and OpenAI timed out. Standardizing on the SSH-forwarded `17890` remote proxy fixed it.
- `nx1` and `agx`: appeared to lack Codex in non-interactive SSH checks, but `bash -ic` loaded nvm and revealed `codex-cli 0.125.0`.
- `edge`: was reachable and proxy-capable, but lagged at `0.124.0`; global npm update brought it to `0.125.0`.

## Rules Learned

Use interactive bash for remote Node CLI checks:

```bash
ssh host 'bash -ic "command -v codex; codex --version; command -v npm; npm --version"'
```

Do not treat this as equivalent:

```bash
ssh host 'codex --version'
```

Many hosts install Node via nvm, and nvm is commonly initialized by `.bashrc`, not by non-interactive SSH commands.

For OpenAI reachability, an unauthenticated `/v1/models` request returning `401` is enough to prove network/proxy connectivity:

```bash
curl -sS -o /dev/null -w "openai_http=%{http_code} remote_ip=%{remote_ip}\n" --max-time 15 https://api.openai.com/v1/models
```

Prefer an explicit on-demand command (`codex-update`) over a systemd timer. The package does not change daily, so continuous polling wastes effort and adds noise.

## SSH Reverse Proxy Pattern

Local machine has VPN/proxy on `127.0.0.1:10808`.

Add this to the relevant SSH host stanza:

```sshconfig
RemoteForward 127.0.0.1:17890 127.0.0.1:10808
```

On the remote machine, source a small env file from `.bashrc`:

```bash
[ -r "$HOME/.config/codex-proxy/env.sh" ] && source "$HOME/.config/codex-proxy/env.sh"
```

`env.sh` should point HTTP, HTTPS, and SOCKS proxy variables at `127.0.0.1:17890`.

If SSH reports `remote port forwarding failed for listen port 17890`, another active SSH session may already own that remote port. That warning is not fatal if the existing forward is healthy, but fresh sessions that depend on it should still be validated with the OpenAI probe.
