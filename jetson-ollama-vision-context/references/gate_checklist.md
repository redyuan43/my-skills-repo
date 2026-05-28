# Gate Checklist

## 状态 Gate

- 先读取 `ollama show <model>` 和 `ollama ps`，确认模型能力与加载状态。
- Jetson 上探测上下文前记录 `free -m`，必要时记录 `tegrastats`。
- 图片识别必须用真实图片请求确认，不凭模型名猜测 vision 能力。

## 修改 Gate

- 修改 systemd 环境变量、重启 Ollama 服务或调整默认上下文前必须确认。
- 不盲目把 `num_ctx` 拉满；按小到大探测并记录失败点。
- 不把 `OLLAMA_MAX_CONTEXT` 当作标准配置，应使用 `OLLAMA_CONTEXT_LENGTH`。

## 回滚 Gate

- 保存修改前的 Ollama 环境配置。
- 若高上下文触发 OOM 或响应异常，恢复到最近稳定 `num_ctx`。
- 回滚后复测 `ollama ps` 和一次最小图片请求。
