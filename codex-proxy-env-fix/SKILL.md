---
name: codex-proxy-env-fix
description: Diagnose and repair Codex CLI network/proxy startup problems on Linux, including repeated Reconnecting attempts, WebSocket fallback delays, ChatGPT/OpenAI reachability timeouts, and MCP servers failing with HTTP 403/timeout because proxy environment variables are missing or wrong. Use when configuring ~/.codex/.env from the machine's actual xray/v2rayN/clash/mihomo/sing-box listener instead of copying example ports.
---

# Codex Proxy Env Fix

## Overview

Use this skill to make Codex load stable proxy variables from `~/.codex/.env`. This is safer than editing Codex internals or `config.toml`: the `arg0` launcher loads `~/.codex/.env` before Codex creates network clients, so CLI, TUI, app-server, and plugin/MCP startup inherit the same proxy settings.

The field pattern from `edge` was:

- Direct `https://chatgpt.com/backend-api/` timed out.
- `xray` listened on `127.0.0.1:10808` with a `mixed` inbound.
- Writing both upper/lower proxy variables plus `WSS_PROXY` to `~/.codex/.env` made `doctor` report WebSocket `HTTP 101 Switching Protocols` and real `siyuan exec` returned `OK`.

## Workflow

1. Confirm the real host and Codex binary:

```bash
ssh "<host>" 'whoami; uname -m; "$HOME/.local/bin/siyuan" --version 2>/dev/null || siyuan --version'
```

2. Inspect the current environment and actual local proxy listeners. Do not copy random ports from examples.

```bash
ssh "<host>" 'env | grep -Ei "^(wss|https?|all|no)_proxy=" || true'
ssh "<host>" 'ss -ltnp 2>/dev/null | grep -E ":(7890|7891|7897|1080|10808|10809|20171|3128|8080|18080)" || true'
ssh "<host>" 'ps -eo pid,comm,args | grep -Ei "xray|v2ray|clash|mihomo|sing-box|dae" | grep -v grep || true'
```

3. Prefer the bundled script. First dry-run:

```bash
ssh "<host>" 'bash -s -- --codex-bin "$HOME/.local/bin/siyuan"' \
  < scripts/configure_codex_proxy_env.sh
```

Then apply:

```bash
ssh "<host>" 'bash -s -- --apply --codex-bin "$HOME/.local/bin/siyuan"' \
  < scripts/configure_codex_proxy_env.sh
```

If the detector guesses wrong, pass the known listener:

```bash
ssh "<host>" 'bash -s -- --apply --proxy-url http://127.0.0.1:10808 --codex-bin "$HOME/.local/bin/siyuan"' \
  < scripts/configure_codex_proxy_env.sh
```

4. Verify with Codex itself, not only curl:

```bash
ssh "<host>" '"$HOME/.local/bin/siyuan" doctor'
ssh -tt "<host>" 'timeout 60 bash -ic "siyuan exec --skip-git-repo-check --ephemeral \"只回复 OK\""'
```

Good signs:

- `doctor` shows proxy vars present.
- WebSocket check reports `HTTP 101 Switching Protocols`.
- ChatGPT/OpenAI reachability is reachable over HTTP.
- `siyuan exec` returns `OK` without repeated `Reconnecting 2/5 ... 5/5`.

## Rules

- Always discover the actual listener from the target machine. Common ports are only candidates.
- Use `http://127.0.0.1:<port>` for xray/v2rayN `mixed` inbound when HTTP CONNECT works.
- Include `WSS_PROXY` and `wss_proxy`; WebSocket failures are often separate from plain HTTPS.
- Include `NO_PROXY=127.0.0.1,localhost,::1` and lowercase `no_proxy` so local MCP/app-server traffic is not sent through the proxy.
- Back up an existing `~/.codex/.env` before overwriting.
- Do not put account tokens or API keys in this `.env`; this skill is only for connection routing.

## Troubleshooting

- If direct curl times out but proxied curl returns an HTTP response, the proxy path is useful even if the response is `403` from Cloudflare/Vercel.
- If `openaiDeveloperDocs` MCP returns HTTP 403 from a remote edge location, first fix routing with `.env`; then retest because the wrong egress often causes the block.
- If `codex_apps` times out, keep `NO_PROXY` in place. Local MCP endpoints should not be proxied.
- If `doctor` still reports a different npm install target, that is an install/PATH warning, not the proxy fix. Validate network with WebSocket/reachability and `exec`.
