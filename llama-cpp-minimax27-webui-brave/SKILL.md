---
name: llama-cpp-minimax27-webui-brave
description: 在 `llama.cpp` 中编译 CUDA 版 `llama-server`，启动 MiniMax-M2.7 WebUI，并接入 Brave MCP 搜索桥接，覆盖编译、启动、健康检查、thinking 验证和常见加载问题处理。
---

# llama.cpp MiniMax-M2.7 WebUI Brave

当用户要在 `llama.cpp` 里跑 `MiniMax-M2.7-GGUF`，并希望同时启用 WebUI 和 Brave MCP 联网搜索时，使用这个 skill。

## 适用场景

- 目标仓库是本地 `~/github/llama.cpp`
- 目标模型是 Unsloth 的 `MiniMax-M2.7-GGUF`
- 需要 Svelte WebUI，而不是纯 API 模式
- 需要 Brave MCP bridge 给 WebUI 提供联网搜索
- 需要复用已经验证过的启动参数和排障经验

## 标准工作流

1. 先编译 `llama-server`：

```bash
cd "$HOME/github/llama.cpp"
cmake -S "." -B "build" -DGGML_CUDA=ON -DLLAMA_CURL=ON
cmake --build "build" --config Release -j --target llama-server
```

2. 准备 Brave API key：

```bash
mkdir -p "$HOME/.config/llama.cpp"
cp "$HOME/github/llama.cpp/config/brave-mcp.env.example" "$HOME/.config/llama.cpp/brave-mcp.env"
```

把 `BRAVE_API_KEY` 改成真实值。

兼容规则：如果 `~/.config/llama.cpp/brave-mcp.env` 不存在，但 `~/.config/gemma4/brave-mcp.env` 已存在，启动脚本会自动回退复用旧配置。

3. 启动整套服务：

```bash
cd "$HOME/github/llama.cpp"
./start_minimax27.sh
```

当前默认参数：

- `ctx-size = 65536`
- `batch-size = 1024`
- `ubatch-size = 1024`
- `parallel = 1`
- `reasoning-format = none`
- `temp = 1.0`
- `top-p = 0.95`
- `top-k = 40`
- `port = 8093`
- Brave MCP health: `127.0.0.1:8765/healthz`

4. 等待健康检查通过：

```bash
bash scripts/check_minimax27_stack.sh
```

## 关键规则

- 直接使用模型分片首文件作为 `-m` 输入，`llama.cpp` 会自动加载同目录其余分片。
- WebUI 模式下保留 `--jinja`，不要自定义覆盖 MiniMax 自带模板，除非明确在排模板 bug。
- 验证 `thinking` 时，优先使用 `reasoning_format = none`，让 `<think>...</think>` 保留在 `message.content` 中。
- 多轮历史回放时，assistant 的完整原始 `content` 必须原样回传，不要剥离 `<think>` 段。
- `503 Loading model` 在大模型装载阶段是正常现象，只要日志持续推进即可。
- 如果空闲显存明显偏低，优先排查是否有旧的 `llama-server` 还在占卡。

## 已验证经验

- 当前 `llama.cpp` 新版本已经可以稳定处理 MiniMax-M2 的 thinking，不再复现早期的乱码边界符泄漏。
- 早期问题集中在旧版解析路径；基线建议至少使用包含 `b8709` MiniMax 修复之后的版本。
- 设定 `XDG_CACHE_HOME=/tmp/llama-cache-test` 可以绕过 Hugging Face cache 迁移提示对启动的干扰。
- 在 `64K ctx + batch 1024 + ubatch 1024` 下，默认并发保持 `1` 更稳妥；更高并发应先实测显存与首 token 延迟。

## 文件

- `SKILL.md`
- `scripts/build_llama_server_cuda.sh`
- `scripts/check_minimax27_stack.sh`
- `references/runbook.md`
