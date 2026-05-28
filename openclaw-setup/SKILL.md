---
name: openclaw-setup
description: 安装 OpenClaw、配置模型 provider、启动 gateway 或排查常见故障时使用。覆盖 install/onboarding/provider/gateway/troubleshooting，但主文件只保留路由和安全边界，细节见 references。
---

# OpenClaw Setup

## Scope

用这个 skill 处理：

- 全新安装 OpenClaw（一键脚本、npm/pnpm、源码构建）
- 配置或切换模型 provider（Anthropic、OpenAI、Z.AI/GLM、OpenRouter、Ollama、vLLM、OpenAI-compatible）
- 启动、检查或重启 gateway
- 排查 `openclaw` 命令缺失、provider 认证失败、UI 资源缺失、gateway 无法启动

## Safety

- 安装、全局包管理、写入 `~/.openclaw/openclaw.json`、写入 shell profile、启动/停止持久服务前，先确认用户确实要改当前机器。
- 不要把真实 API key 写进可提交文件或聊天输出；示例配置只使用占位符或环境变量。
- 先跑只读检查，再做安装或写配置。

## Workflow

1. 先判断用户意图属于安装、provider 配置、gateway 操作还是排障。
2. 读取对应 reference：
   - 安装和 onboarding：`references/install_methods.md`
   - provider 配置：`references/provider_config.md`
   - gateway 启动和验证：`references/gateway_ops.md`
   - 常见故障：`references/troubleshooting.md`
3. 对会修改系统、全局依赖、用户配置或 live gateway 的步骤，先请求明确确认。
4. 执行后用只读命令验证，例如 `openclaw doctor`、`openclaw gateway status`、`openclaw channels status --probe`。

## Quick Checks

```bash
openclaw doctor
openclaw gateway status
openclaw channels status --probe
```

Safe selftest for this skill package:

```bash
openclaw-setup/scripts/selftest.sh --safe
```

## References

- `references/install_methods.md`
- `references/provider_config.md`
- `references/gateway_ops.md`
- `references/troubleshooting.md`
