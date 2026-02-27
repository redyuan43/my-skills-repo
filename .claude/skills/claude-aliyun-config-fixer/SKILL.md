---
name: claude-aliyun-config-fixer
description: 配置和排障 Claude Code 对接阿里云百炼 / Coding Plan（DashScope Anthropic 兼容接口）。当用户说“Claude 配置总报错”“403 invalid api-key”“401 invalid_api_key”“按阿里云文档配置 Claude”“百炼/Coding Plan Claude Code 接入失败”时使用。识别 sk- 与 sk-sp- Key 类型，匹配正确 Base URL 和认证字段（ANTHROPIC_API_KEY vs ANTHROPIC_AUTH_TOKEN），清理 ~/.claude 冲突配置，并做最小验证。
---

# Claude + 阿里云（百炼 / Coding Plan）配置与 403 排障

## 适用场景

- 用户要按阿里云文档配置 `Claude Code`
- 用户报错：`API Error: 403 invalid api-key`
- 用户不确定应该改环境变量还是 `~/.claude/settings.json`
- 用户配置过多次，怀疑有旧配置冲突

## 核心原则（KISS）

- 只保留一套生效配置来源：优先 `~/.claude/settings.json` 的 `env`
- 先读后写：先检查 key 类型、Base URL、模型、冲突项
- 最小改动：只改必要字段，保留用户已有插件/状态栏配置

## 快速判断（最关键）

先看 Key 前缀，再决定 `ANTHROPIC_BASE_URL` 和认证字段：

- `sk-...`（百炼通用 API Key）
  - `ANTHROPIC_BASE_URL=https://dashscope.aliyuncs.com/apps/anthropic`
  - 优先使用 `ANTHROPIC_API_KEY`
- `sk-sp-...`（Coding Plan 专属 API Key）
  - `ANTHROPIC_BASE_URL=https://coding.dashscope.aliyuncs.com/apps/anthropic`
  - 优先使用 `ANTHROPIC_AUTH_TOKEN`（按阿里云 Coding Plan 文档）

如果把 `sk-sp-...` 配到 `dashscope.aliyuncs.com`，通常会报：
- `403 invalid api-key`

如果 `sk-sp-...` 使用了 `ANTHROPIC_API_KEY`（而不是 `ANTHROPIC_AUTH_TOKEN`），常见表现是：
- `401 invalid_api_key`
- `invalid access token or token expired`

## 推荐配置（写入 ~/.claude/settings.json）

在 `~/.claude/settings.json` 的 `env` 中配置（按 Key 类型选择认证字段）：

- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_API_KEY`（百炼 `sk-...`）
- 或 `ANTHROPIC_AUTH_TOKEN`（Coding Plan `sk-sp-...`）
- `ANTHROPIC_MODEL`（Coding Plan 常用：`qwen3-coder-plus`）

不要同时保留 `ANTHROPIC_API_KEY` 和 `ANTHROPIC_AUTH_TOKEN`，避免误判当前生效认证方式。

### Coding Plan（`sk-sp-...`）建议模型映射（可选）

若用户希望兼容 Claude 的 `opus/sonnet/haiku` 别名选择，可在 `env` 中额外配置：

- `ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.5-plus`
- `ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.5-plus`
- `ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3-coder-next`

## 必查冲突项（403 高发原因）

### 1. 旧 API Key 冲突

检查 `~/.claude/config.json`：

- 若存在 `primaryApiKey` 且不是当前阿里云 Key，可能被优先使用
- 建议清理为 `{}` 或移除该字段（在用户确认后执行）

### 2. 模型配置冲突

检查 `~/.claude/settings.json` 顶层 `model`：

- 如果存在类似 `"model": "haiku"`，可能覆盖 `env.ANTHROPIC_MODEL`
- 建议删除顶层 `model`，让 `env.ANTHROPIC_MODEL` 成为唯一模型来源

### 3. Onboarding 未完成

检查 `~/.claude.json`：

- `hasCompletedOnboarding` 应为 `true`

### 4. OAuth 凭证优先级覆盖阿里云配置

检查 `~/.claude/.credentials.json`（Claude OAuth 凭证）：

- 即使 `settings.json` 已包含阿里云 `env`，Claude 仍可能优先使用 `claude.ai` OAuth
- 表现为：本地看起来“识别了 Base URL 和 Key”，但实际请求仍走 OAuth/第一方路径

建议用 `claude auth status --text` 判断当前实际状态：

- 若输出包含 `Auth token: claude.ai`，说明 OAuth 仍在生效
- 若输出包含 `Auth token: ANTHROPIC_AUTH_TOKEN`，说明正在使用 Coding Plan 模式
- 若输出只显示 `API key: ANTHROPIC_API_KEY`，说明正在使用 API Key 模式

## 最小验证（不改文件）

1. 检查 `claude` 命令路径是否存在（例如 `command -v "claude"`）
2. 脱敏打印 `~/.claude/settings.json` 的：
   - `ANTHROPIC_BASE_URL`
   - `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN`
   - `ANTHROPIC_MODEL`
3. 运行 `claude auth status --text`（优先 `--text`，比 `--json` 更直观地显示 `Anthropic base URL` 和 `Auth token`）
4. 检查是否仍有旧 `claude` 进程在运行（进程可能缓存旧环境/旧配置）

若发现旧进程，建议用户完全退出后再重启。

## 标准排障流程（按顺序）

1. 读取并展示（脱敏）：
   - `~/.claude/settings.json`
   - `~/.claude/config.json`
   - `~/.claude.json`（只查 onboarding 字段）
2. 判断 key 类型：
   - `sk-` vs `sk-sp-`
3. 校正 `ANTHROPIC_BASE_URL`
4. 清理冲突项：
   - `~/.claude/config.json` 的旧 `primaryApiKey`
   - `~/.claude/settings.json` 顶层 `model`
5. 脱敏校验当前配置
6. 运行 `claude auth status --text` 确认当前生效认证模式（OAuth / API Key / AUTH_TOKEN）
7. 检查并提示清理旧 `claude` 进程
8. 用户重试
9. 若仍 `401/403`：
   - 判断为云侧问题（Key 无效、未开通权限、过期、套餐/模型权限不足）

## 常见结论模板（可直接复用）

- “本地配置已正确，403 仍存在，基本可判断为阿里云侧 Key/权限问题。”
- “你当前是 `sk-sp-...`（Coding Plan Key），必须使用 `coding.dashscope.aliyuncs.com` 域名。”
- “你当前是 `sk-sp-...`（Coding Plan Key），应使用 `ANTHROPIC_AUTH_TOKEN`，不是 `ANTHROPIC_API_KEY`。”
- “不是 `export` 语句有问题，而是本地存在旧 `primaryApiKey`/顶层 `model`/OAuth 优先级冲突项。”

## 可选实现模式（需要用户明确同意）

当用户希望在阿里云和 Anthropic OAuth 之间快速切换、且不想反复改 `settings.json` 时，可以提供两个包装命令（例如 `claude-aliyun` / `claude-oauth`）：

- `claude-aliyun`：临时隐藏 `~/.claude/.credentials.json`，强制走 `settings.json` 中的阿里云 `env`
- `claude-oauth`：直接执行原始 `claude`

注意：

- 不要并行运行 `claude-aliyun` 和 `claude-oauth`（会竞争同一个 OAuth 凭证文件）
- 包装脚本只应临时移动 `~/.claude/.credentials.json`，不要移动 `~/.claude.json`（会触发误导性提示）

## 安全与确认

在执行以下操作前，先获得用户明确确认：

- 修改 `~/.claude/settings.json`
- 修改 `~/.claude/config.json`
- 杀掉 `claude` 进程（如 `pkill -f claude`）
- 任何 `git commit` / `git push`
