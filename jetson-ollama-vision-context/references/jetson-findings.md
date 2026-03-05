# Jetson Orin NX 16G Findings (Ollama 0.17.6 + qwen3.5:latest)

## Confirmed Facts

- `qwen3.5:latest` 能力包含 `vision`，支持图片输入。
- 仅在调用 `/api/chat` 且将图片放入 `messages[].images`（base64）时可触发视觉。
- 服务环境变量应使用 `OLLAMA_CONTEXT_LENGTH`；`OLLAMA_MAX_CONTEXT` 不生效。

## Context Observations

- `num_ctx=100000`：可成功，返回正常。
- `num_ctx=200000`：触发 OOM，`ollama.service` 被系统杀死并重启。
- 200K 失败日志特征：
  - `KvSize:200000`
  - `total memory size="17.6 GiB"`
  - `A process of this unit has been killed by the OOM killer`

## Practical Defaults for 16G Shared Memory

- 稳妥档：`8192 ~ 24576`
- 可尝试档：`32768`
- 高风险档：`>=65536`（依赖并发、系统负载、图像大小）

## Recommended Systemd Snippet

```ini
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=24576"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_KEEP_ALIVE=5m"
```

说明：
- 在 16G 设备先用 `OLLAMA_NUM_PARALLEL=1` 降低并发挤占。
- 若追求高 context，请优先降低并发和 keep-alive，再逐步提升 context。
