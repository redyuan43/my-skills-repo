# WeChat Archive Deployment Notes

## HTTP and cross-device use

Read-only commands can run against an explicit local or remote HTTP endpoint:

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh search "自动驾驶" --limit 5 --http-url "http://127.0.0.1:1934"
```

Use explicit `--http-url` whenever the client machine is different from the service machine.

Current behavior:

- Client machines need the repo checkout plus Python environment.
- Clients do not need local embedding, rerank, or source archive paths for read-only HTTP commands.
- `index` should stay on the service machine because it depends on local archive paths.
- If `--http-url` is omitted, read-only commands may auto-start the default local HTTP service and fall back to embedded mode.

## Environment overrides

- `OPENVIKING_REPO_DIR`
- `OPENVIKING_PYTHON_BIN`
- `OPENVIKING_SERVER_PYTHON`
- `OPENVIKING_SERVER_CONFIG`
- `OPENVIKING_SERVER_HOST`
- `OPENVIKING_SERVER_PORT`

To expose archive search to LAN or VPN clients, override `OPENVIKING_SERVER_HOST=0.0.0.0` and point clients at `--http-url "http://<server-ip>:1934"`.

Do not expose embed (`8766`) or rerank (`8765`) directly to clients; the archive HTTP server on `1934` is the intended entrypoint.
