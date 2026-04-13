# llama.cpp MiniMax-M2.7 WebUI Brave Runbook

## 1. 编译

```bash
cd "$HOME/github/llama.cpp"
cmake -S "." -B "build" -DGGML_CUDA=ON -DLLAMA_CURL=ON
cmake --build "build" --config Release -j --target llama-server
```

## 2. 启动脚本入口

仓库内入口：

```bash
./start_minimax27.sh
```

默认行为：

- 启动 `llama-server`
- 打开 WebUI
- 读取 `config/webui-brave-mcp.json`
- 自动尝试拉起 Brave MCP bridge
- Brave 配置优先读 `~/.config/llama.cpp/brave-mcp.env`
- 若不存在则回退到 `~/.config/gemma4/brave-mcp.env`

## 3. 健康检查

```bash
curl -fsS "http://127.0.0.1:8765/healthz"
curl -fsS "http://127.0.0.1:8093/health"
```

说明：

- `8765` 返回 Brave MCP bridge 健康状态
- `8093` 在模型装载完成前会返回 `503`
- `8093` 变成 `{"status":"ok"}` 后，WebUI 才算 fully ready

## 4. 实际测试

单轮测试：

```bash
curl -fsS "http://127.0.0.1:8093/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "minimax-m2.7",
    "messages": [
      {"role": "user", "content": "请先思考，再用中文一句话回答：地球绕太阳还是太阳绕地球？"}
    ],
    "stream": false,
    "temperature": 1.0,
    "top_p": 0.95,
    "top_k": 40,
    "reasoning_format": "none"
  }'
```

双轮测试重点：

- 把上一轮 assistant 的完整 `content` 原样回放
- 不要删除 `<think>...</think>`
- 如果这样仍正常，说明当前版本已能稳定处理 MiniMax thinking

## 5. 常见问题

### 旧进程占显存

现象：

- 新实例启动时日志显示 free VRAM 明显偏低
- 或 `fit params` 失败/装载非常慢

处理：

```bash
pgrep -af "llama-server.*8092|llama-server.*8093"
kill -9 <old-pid>
```

### Hugging Face cache 迁移提示干扰

处理：

- 在启动时显式设置 `XDG_CACHE_HOME=/tmp/llama-cache-test`
- 当前 `start_minimax27.sh` 已内置这个默认值

### 看到 `[e~[`、`]~b]` 之类特殊 token

判断：

- 这类问题多见于旧版 `llama.cpp` 或错误的解析/模板路径
- 优先确认版本是否已包含 MiniMax 修复
- 保持 `--jinja` 和 `reasoning_format=none` 做基线验证
