# LM Studio Brave MCP 排障

## 1. `Error: fetch failed`

如果是旧版实现，通常是 Node `fetch` / `undici` 到 Brave API 的链路不稳。

这套 skill 已经改成 `curl` 出口，不建议回退。

## 2. `curl: (28) Connection timed out`

先分清是直连超时，还是代理链路超时：

- 目标机器如果必须翻墙或走代理访问 Brave API，请显式传 `--proxy-url`
- 不要依赖桌面环境、登录 shell、LM Studio 子进程“碰巧继承到相同代理配置”

建议测试：

```bash
curl --ipv4 --silent --show-error --location --compressed \
  --header "Accept: application/json" \
  --header "X-Subscription-Token: $BRAVE_API_KEY" \
  "https://api.search.brave.com/res/v1/web/search?q=LM+Studio&count=1"
```

如果直连不通，而代理通，就把代理固化到 `~/.lmstudio/credentials/brave-search.env`。

## 3. `OPTION_NOT_IN_PLAN`

这不是配置错误，是 Brave 套餐不包含该端点。

常见受限能力包括：

- `brave_spellcheck`
- `brave_suggest` 的 richer metadata
- `brave_place_search` / `brave_place_details`
- `brave_summarizer_search`

这类情况不需要重装 MCP，应改成：

- 保留能用的 `web` / `news` / `image` / `video`
- 对用户说明是 Brave plan 边界

## 4. LM Studio 里只看到 `mcp/brave-search`

这是正常现象。

- `Integrations` 面板显示的是 MCP server
- 具体工具如 `brave_web_search`、`brave_news_search` 在聊天时按需调用

## 5. 改完配置后仍旧报旧错误

优先重启 LM Studio，而不是只重开会话。

因为旧的 MCP 子进程可能还在运行，未加载新的 `mcp.json` 或新的 server 文件。
