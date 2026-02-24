---
name: cli-config-bootstrap
description: 为 Claude CLI / Codex CLI / Qwen CLI / Kilo CLI 生成和维护可迁移的本地配置模板（脱敏版），保留模型、权限、常用设置，移除或占位 API Key / OAuth Token。适用于在新电脑快速恢复 CLI 开发环境、统一多台机器配置、备份配置模板、或批量更新 provider endpoint。
---

# CLI 配置迁移模板（Claude/Codex/Qwen/Kilo）

## 概览

基于当前机器上的真实配置生成脱敏模板，不从零猜格式。输出模板文件和安装脚本，换机后只需替换 token 或重新登录 OAuth。

## 使用场景

- “把 Claude/Codex/Qwen/Kilo 的配置做成模板”
- “新电脑一键恢复 AI CLI 环境”
- “去掉 API key 后分享配置”
- “保留模型/权限设置，只替换 token”

## 工作流程

1. 读取本机配置文件（只读）
2. 识别敏感字段（API Key / access token / refresh token）
3. 用占位符替换敏感字段
4. 输出模板到 `assets/templates/*`
5. 用 `scripts/install_cli_configs.sh` 安装到新机器
6. 手动补 token 或执行登录命令（OAuth 模式）
7. 配置更新后，用 `scripts/export_cli_configs.sh` 重新导出模板

## 配置范围（本技能约定）

- `Claude CLI`
  - 保留：`~/.claude/settings.json`、`~/.claude/config.json`
  - 不迁移：`.claude.json`、`~/.claude/.credentials.json`、历史/缓存/遥测
- `Codex CLI`
  - 保留：`~/.codex/config.toml`
  - 提供：`~/.codex/auth.json` 脱敏模板（`tokens` 置空）
- `Qwen CLI`
  - 保留：`~/.qwen/settings.json`
  - 不默认迁移：`oauth_creds.json` 真实值（建议新机器重登）
- `Kilo CLI`
  - 保留：`~/.config/kilo/config.json`、`opencode.json`、`package.json`
  - 约束：`provider.npm="@ai-sdk/anthropic"` 必须匹配 Anthropic 风格 `baseURL`

## 安装脚本

```bash
bash scripts/install_cli_configs.sh
```

```bash
bash scripts/export_cli_configs.sh
```

支持环境变量注入（不传则保留占位符）：

- `CLAUDE_PRIMARY_API_KEY`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_BASE_URL`
- `OPENAI_API_KEY`
- `BAILIAN_CODING_PLAN_API_KEY`
- `KILO_API_KEY`

## 注意事项

- 不要把真实 OAuth `access_token` / `refresh_token` 提交到仓库。
- 不要迁移历史、遥测、debug、缓存文件。
- 换地域时同步调整 `baseURL`（例如阿里云北京 vs 其他地域）。
- Kilo 若出现 `Not Found`，先检查 `provider.npm` 与 `baseURL` 协议是否匹配。

## 资源

- `scripts/install_cli_configs.sh`：安装模板并按环境变量替换占位符
- `scripts/export_cli_configs.sh`：从当前机器配置重新生成脱敏模板
- `assets/templates/*`：四套 CLI 的脱敏模板
