# OpenClaw Provider Config

配置文件：`~/.openclaw/openclaw.json`，JSON5 格式，支持注释和尾逗号。

模型引用格式：`provider/model`，例如 `anthropic/claude-opus-4-6`、`zai/glm-5`。

## Anthropic

```bash
openclaw onboard --auth-choice anthropic-api-key
```

```json5
{
  env: { ANTHROPIC_API_KEY: "${ANTHROPIC_API_KEY}" },
  agents: { defaults: { model: { primary: "anthropic/claude-opus-4-6" } } },
}
```

## OpenAI

```bash
openclaw onboard --auth-choice openai-api-key
openclaw onboard --auth-choice openai-codex
```

```json5
{
  env: { OPENAI_API_KEY: "${OPENAI_API_KEY}" },
  agents: { defaults: { model: { primary: "openai/gpt-5.2" } } },
}
```

## Z.AI / GLM

```bash
openclaw onboard --auth-choice zai-api-key
openclaw onboard --zai-api-key "$ZAI_API_KEY"
```

```json5
{
  env: { ZAI_API_KEY: "${ZAI_API_KEY}" },
  agents: { defaults: { model: { primary: "zai/glm-5" } } },
}
```

常用 model ID：`glm-5`、`glm-4.7`、`glm-4.6`。

## OpenRouter

```bash
openclaw onboard --auth-choice apiKey --token-provider openrouter --token "$OPENROUTER_API_KEY"
```

```json5
{
  env: { OPENROUTER_API_KEY: "${OPENROUTER_API_KEY}" },
  agents: {
    defaults: { model: { primary: "openrouter/anthropic/claude-sonnet-4-5" } },
  },
}
```

## Ollama

OpenClaw 使用 Ollama 原生 API，不要把 base URL 写成 `/v1`。

```bash
ollama pull gpt-oss:20b
export OLLAMA_API_KEY="ollama-local"
```

```json5
{
  agents: { defaults: { model: { primary: "ollama/gpt-oss:20b" } } },
}
```

远程 Ollama：

```json5
{
  models: {
    providers: {
      ollama: {
        baseUrl: "http://ollama-host:11434",
        apiKey: "ollama-local",
        api: "ollama",
      },
    },
  },
}
```

## vLLM / OpenAI-compatible

```json5
{
  models: {
    providers: {
      "my-provider": {
        baseUrl: "https://your-endpoint/v1",
        apiKey: "${MY_PROVIDER_API_KEY}",
        api: "openai-completions",
        models: [
          {
            id: "your-model-id",
            name: "My Model",
            reasoning: false,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 128000,
            maxTokens: 8192,
          },
        ],
      },
    },
  },
  agents: { defaults: { model: { primary: "my-provider/your-model-id" } } },
}
```

## 更改默认模型

```bash
openclaw config set agents.defaults.model.primary "zai/glm-5"
```

也可以在 Control UI 的 Config 标签页修改并保存，gateway 会热重载。
