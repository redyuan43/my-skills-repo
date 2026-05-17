---
name: codex-wechat-hook
description: Install, check, and troubleshoot a Codex Stop hook that sends the final assistant message to a WeClaw/WeChat bot. Use when the user asks to add Codex completion notifications to this machine or a remote device, mentions /hooks trust, WeClaw text notification, AI/NX/AGX remote Codex notification, or wants the hook workflow reproduced from DevToolbox scripts.
---

# Codex WeChat Hook

Use the DevToolbox script package as the source of truth:

```bash
/home/ivan/github/DevToolbox/codex-hooks/weclaw-stop-notify
```

## Install locally

1. Confirm WeClaw is reachable:

```bash
curl -fsS http://127.0.0.1:18011/health
```

2. Install the Stop hook:

```bash
/home/ivan/github/DevToolbox/codex-hooks/weclaw-stop-notify/install.sh \
  --to "USER_ID@im.wechat"
```

3. Open Codex CLI, run `/hooks`, and trust the `Stop` hook.

4. Verify:

```bash
/home/ivan/github/DevToolbox/codex-hooks/weclaw-stop-notify/check.sh --send-test
```

## Install on a remote device

If the remote device has its own local WeClaw, run `install.sh` on that device and keep `api_url` as `http://127.0.0.1:18011/api/send`.

If the remote device does not run WeClaw, keep WeClaw private on the local machine and install the hook with a reverse tunnel:

```bash
/home/ivan/github/DevToolbox/codex-hooks/weclaw-stop-notify/install_remote.sh \
  --host SSH_ALIAS \
  --to "USER_ID@im.wechat" \
  --with-tunnel \
  --service-name codex-SSH_ALIAS-weclaw-tunnel.service
```

`SSH_ALIAS` is the actual SSH target name that already works from this machine, for example `ai`, `nx1`, `nx2`, `spark`, or another alias in `~/.ssh/config`. Use a service name that matches the same alias so multiple device tunnels do not overwrite each other.

Example:

```bash
/home/ivan/github/DevToolbox/codex-hooks/weclaw-stop-notify/install_remote.sh \
  --host nx1 \
  --to "USER_ID@im.wechat" \
  --with-tunnel \
  --service-name codex-nx1-weclaw-tunnel.service
```

The user must trust the hook in the remote Codex CLI with `/hooks`. Existing Codex sessions may need to be restarted because hooks are loaded when the session starts.

## Notes

- The hook sends only `last_assistant_message`, prefixed with session id, cwd, and hostname.
- It does not send files.
- The script bypasses proxy settings for the WeClaw HTTP request.
- If smoke tests work but real turns do not notify, first check hook trust and whether the Codex session was started before installation.
