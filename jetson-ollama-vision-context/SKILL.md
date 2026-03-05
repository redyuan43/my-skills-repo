---
name: jetson-ollama-vision-context
description: 在 Jetson 等共享显存/内存设备上配置和排查 Ollama 的上下文窗口，并验证 qwen3.5 的图片识别与性能指标。用于以下场景：模型显示 context 过小（如 4096）、怀疑模型不支持图片、需要在 16G 级设备上确定可稳定运行的 num_ctx、需要生成可复现的性能测试结果。
---

# Jetson Ollama Vision Context

## Quick Start

1. 检查模型能力与当前加载状态。

```bash
ollama show qwen3.5:latest
ollama ps
```

2. 使用脚本验证图片识别与性能。

```bash
scripts/ollama_vision_perf.sh --image "/abs/path/test.png" --model "qwen3.5:latest" --ctx 100000 --repeat 1
```

3. 使用脚本探测可用上下文区间。

```bash
scripts/ollama_context_probe.sh --model "qwen3.5:latest" --ctx-list "4096,8192,16384,24576,32768,65536,100000"
```

## Workflow

1. 先验证能力，不猜测。
- 运行 `ollama show <model>`，确认 `Capabilities` 是否包含 `vision`。
- 运行一次图片请求，确认 `done=true` 且 `message.content` 为图片内容描述。

2. 再做上下文探测。
- 从小到大递增 `num_ctx`，观察是否报错、是否触发 OOM、时延是否可接受。
- 记录 `ollama ps`、`free -m`、`tegrastats`（Jetson）作为证据。

3. 最后固化默认配置。
- 在 systemd 环境使用 `OLLAMA_CONTEXT_LENGTH`，不要使用 `OLLAMA_MAX_CONTEXT`。
- 配置后重启服务并复测。

## Critical Notes

- 在 Ollama 0.17.6，默认上下文由显存自动决策，Jetson 16G 常见默认是 `4096`。
- `qwen3.5:latest` 支持图片，但必须按 chat API 的 `messages[].images` 传 base64。
- 共享显存/内存设备上，高 `num_ctx` 可能触发 OOM。实测经验（Orin NX 16G）见 [references/jetson-findings.md](references/jetson-findings.md)。
- 若目标是超长上下文 + 多图，优先采用分块/RAG 或更小模型，而不是盲目拉满窗口。

## Resources

- `scripts/ollama_vision_perf.sh`: 单图识别 + 性能统计（load/total/prompt/eval/token/s）+ 内存快照。
- `scripts/ollama_context_probe.sh`: 批量探测不同 `num_ctx` 的可用性。
- `references/jetson-findings.md`: Jetson 16G 的已验证参数与故障特征。
