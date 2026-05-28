# WeChat Archive Systemd Operations

Service operations are not part of the default read-only workflow. Confirm before enabling, stopping, restarting, or rewriting units.

## Expected services

- `/home/nx/github/OpenViking/systemd/user/openviking-local-embed.service`
- `/home/nx/github/OpenViking/systemd/user/openviking-local-rerank.service`
- `/home/nx/github/OpenViking/systemd/user/openviking-wechat-archive-server.service`

Bundled skill units:

- `systemd/user/openviking-wechat-archive-server.service`
- `systemd/user/openviking-wechat-archive-index.service`
- `systemd/user/openviking-wechat-archive-index.timer`

## Health checks

```bash
curl "http://127.0.0.1:8766/healthz"
curl "http://127.0.0.1:8765/healthz"
curl "http://127.0.0.1:1934/health"
```

## User-level links

Only create or update these links after explicit approval:

```bash
ln -sf /home/nx/github/OpenViking/bot/workspace/skills/wechat-archive/systemd/user/openviking-wechat-archive-server.service \
  /home/nx/.config/systemd/user/openviking-wechat-archive-server.service
ln -sf /home/nx/github/OpenViking/bot/workspace/skills/wechat-archive/systemd/user/openviking-wechat-archive-index.service \
  /home/nx/.config/systemd/user/openviking-wechat-archive-index.service
ln -sf /home/nx/github/OpenViking/bot/workspace/skills/wechat-archive/systemd/user/openviking-wechat-archive-index.timer \
  /home/nx/.config/systemd/user/openviking-wechat-archive-index.timer
```

Then:

```bash
systemctl --user daemon-reload
systemctl --user enable --now openviking-wechat-archive-server.service
systemctl --user enable --now openviking-wechat-archive-index.timer
```
