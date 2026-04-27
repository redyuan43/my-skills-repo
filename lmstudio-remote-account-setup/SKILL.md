---
name: lmstudio-remote-account-setup
description: Configure or switch LM Studio accounts on remote Linux devices over SSH using the official `lms login` pairing flow. Use when the user wants devices such as `nx1`, `nx2`, or `nano` logged into a target LM Studio account and can approve browser pairing links from the current machine.
---

# LM Studio Remote Account Setup

Use this skill when the user asks to set, switch, or verify the LM Studio account on one or more remote Linux devices over SSH.

Typical requests:

- "把 nx1 / nx2 / nano 的 LM Studio 账号改成 ivanfeng3333"
- "LM Studio 现在是 redyuan43，帮我换号"
- "给我 LM Studio 授权链接，我在当前浏览器通过"
- "远端 headless LM Studio 需要重新登录"

## Goal

Make each requested device actually authenticate with the target LM Studio account through the official `lms login` pairing flow, then verify with `lms whoami` or `lms login --status`.

Do not treat edits to `~/.lmstudio/.internal/user-profile.json` as authentication. That file is only a local cache and can produce false confidence.

## Known Device Map

For this workspace, common SSH targets are:

- `nx1`: `nx@nx1.taild500c8.ts.net`
- `nx2`: `nx@nx2.taild500c8.ts.net`
- `nano`: `nano@nano.taild500c8.ts.net`

Prefer direct Tailscale SSH when local aliases disconnect or contain complex `ProxyCommand` logic:

```bash
ssh -o ProxyCommand=none nx@nx2.taild500c8.ts.net
ssh -o ProxyCommand=none nano@nano.taild500c8.ts.net
```

For long-running installs, add keepalives:

```bash
ssh -o ProxyCommand=none \
  -o ServerAliveInterval=10 \
  -o ServerAliveCountMax=12 \
  -o TCPKeepAlive=yes \
  user@host
```

## Workflow

1. Check whether `lms` exists.

```bash
ssh -o ProxyCommand=none user@host \
  '[ -x "$HOME/.lmstudio/bin/lms" ] && "$HOME/.lmstudio/bin/lms" --version || echo NO_LMS'
```

2. Install LM Studio headless CLI / `llmster` if missing or incomplete.

```bash
ssh -o ProxyCommand=none user@host \
  'curl -fsSL https://lmstudio.ai/install.sh | bash; "$HOME/.lmstudio/bin/lms" --version'
```

3. Start the daemon.

```bash
ssh -o ProxyCommand=none user@host \
  'export PATH="$HOME/.lmstudio/bin:$PATH"; lms daemon up'
```

4. Generate a pairing link.

Use a TTY so the pairing prompt is displayed cleanly:

```bash
ssh -tt -o ProxyCommand=none user@host \
  'export PATH="$HOME/.lmstudio/bin:$PATH"; lms logout >/dev/null 2>&1 || true; lms login'
```

5. Send the direct pairing URL to the user.

The command prints both a code and a direct URL. Give the user the direct URL, for example:

```text
https://lmstudio.ai/pairing?code=grove-toilet-smile
```

Keep the command running until it prints:

```text
Authentication successful.
```

If the user says the page expired, interrupt the command and generate a new link.

6. Verify the final account.

```bash
ssh -o ProxyCommand=none user@host \
  'export PATH="$HOME/.lmstudio/bin:$PATH"; lms whoami; lms login --status'
```

Expected result:

```text
You are currently logged in as: ivanfeng3333
```

## Common Failures

### Alias SSH Disconnects

If `ssh nx2 '...'` repeatedly fails with `client_loop: send disconnect: Broken pipe`, bypass the local alias and connect directly:

```bash
ssh -o ProxyCommand=none nx@nx2.taild500c8.ts.net 'echo ok'
```

### Missing `lms` on Headless Devices

Some devices, especially `nano`, may have models or skill folders but no LM Studio CLI. Install with:

```bash
curl -fsSL https://lmstudio.ai/install.sh | bash
```

The install can be large. Keep the SSH session alive and wait for checksum verification plus:

```text
Installation finished successfully! llmster is ready to launch.
```

### Invalid Passkey

If `lms login` fails with:

```text
Invalid passkey for lms CLI client. Please make sure you are using the lms shipped with LM Studio.
```

Reset the local daemon key and restart `llmster`:

```bash
export PATH="$HOME/.lmstudio/bin:$PATH"
lms daemon down || true
pkill -u "$USER" -f "llmster|[.]lmstudio/.internal/utils/node" || true
ts=$(date +%Y%m%d-%H%M%S)
[ -f "$HOME/.lmstudio/.internal/lms-key-2" ] &&
  mv "$HOME/.lmstudio/.internal/lms-key-2" "$HOME/.lmstudio/.internal/lms-key-2.bak.$ts"
rm -f "$HOME/.lmstudio/.internal/llmster-pid.lock"
nohup "$HOME/.lmstudio/bin/lms" daemon up >/tmp/lms-daemon-up.log 2>&1 &
sleep 5
lms daemon status
```

Then retry `lms login`.

### False Login From Cache Edits

Avoid "fixing" account state by only editing:

```text
~/.lmstudio/.internal/user-profile.json
~/.lmstudio/.internal/lm-link-account-status-cache.json
```

Those files can be useful for inspection, but the completion criterion is `lms whoami` and `lms login --status`.

## Verification Checklist

For every target device:

- `~/.lmstudio/bin/lms --version` works.
- `lms daemon status` reports `llmster` running or the daemon can be reached.
- `lms login` has completed with `Authentication successful`.
- `lms whoami` shows the target account.
- `lms login --status` shows the target account.

## Example Session

```bash
# nx1
ssh -tt -o ProxyCommand=none nx@nx1.taild500c8.ts.net \
  'export PATH="$HOME/.lmstudio/bin:$PATH"; lms logout >/dev/null 2>&1 || true; lms login'

# nx2 direct Tailscale fallback
ssh -tt -o ProxyCommand=none nx@nx2.taild500c8.ts.net \
  'export PATH="$HOME/.lmstudio/bin:$PATH"; lms logout >/dev/null 2>&1 || true; lms login'

# nano install, then login
ssh -o ProxyCommand=none nano@nano.taild500c8.ts.net \
  'curl -fsSL https://lmstudio.ai/install.sh | bash'
ssh -tt -o ProxyCommand=none nano@nano.taild500c8.ts.net \
  'export PATH="$HOME/.lmstudio/bin:$PATH"; lms login'
```
