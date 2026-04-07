---
name: lmstudio-brave-mcp-bootstrap
description: 为 LM Studio 安装和配置基于 Brave Search API 的 MCP 搜索能力，生成可迁移的本地配置、凭证模板和自定义 MCP server，适用于新设备快速恢复联网搜索能力。
---

# LM Studio Brave MCP Bootstrap

当用户要把 Brave Search API 接到 LM Studio，并希望这套能力可以迁移到其他 Linux/macOS 设备时，使用这个 skill。

它会安装一套可复用的本地资产：

- `~/.lmstudio/mcp.json`
- `~/.lmstudio/bin/brave-lmstudio-mcp.sh`
- `~/.lmstudio/mcp-servers/brave-search/brave-lmstudio-mcp.mjs`
- `~/.lmstudio/credentials/brave-search.env`

## 适用边界

- 目标环境已安装 LM Studio
- 目标环境可用 `node`、`curl`、`python3`
- 主要面向 Linux/macOS
- Brave API key 由用户提供

## 推荐工作流

1. 用安装脚本落配置：

```bash
bash scripts/install_lmstudio_brave_mcp.sh --api-key "YOUR_BRAVE_API_KEY"
```

2. 如果目标机器联网依赖代理，显式写入代理：

```bash
bash scripts/install_lmstudio_brave_mcp.sh \
  --api-key "YOUR_BRAVE_API_KEY" \
  --proxy-url "socks://127.0.0.1:10808/"
```

3. 重启 LM Studio。

4. 新开聊天验证：

```text
请使用 brave_web_search 搜索 LM Studio 官方文档，返回 3 条结果和链接。
```

## 关键规则

- 默认保留自定义 MCP server，而不是退回官方 `@modelcontextprotocol/server-brave-search`
原因：这套实现支持更多 Brave 端点，也显式处理了代理、IPv4 和重试。
- 如果用户机器必须走代理，不要依赖桌面环境“自动继承代理”。
优先用 `--proxy-url` 写入 `brave-search.env`，让 MCP 行为稳定可复现。
- 如需排查超时，先读 `references/troubleshooting.md`。

## 资源说明

- `scripts/install_lmstudio_brave_mcp.sh`
作用：一键安装或更新 LM Studio 的 Brave MCP 配置。
- `assets/brave-lmstudio-mcp.mjs`
作用：自定义 Brave MCP server，暴露网页、新闻、图片、视频、地点、suggest、spellcheck、summarizer 等工具。
- `references/troubleshooting.md`
作用：记录常见超时、代理、套餐能力受限的判断口径。
