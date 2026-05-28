# OpenClaw Install Methods

## 一键安装脚本

```bash
# macOS / Linux / WSL2
curl -fsSL https://openclaw.ai/install.sh | bash

# Windows PowerShell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

脚本会检测 Node 版本、安装 CLI，并启动 onboarding 向导。执行前确认用户允许联网安装和写入当前用户环境。

## npm / pnpm 手动安装

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

```bash
pnpm add -g openclaw@latest
pnpm approve-builds -g
openclaw onboard --install-daemon
```

macOS 上若 `sharp` 报错：

```bash
SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest
```

## 源码构建

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build
pnpm build
pnpm link --global
openclaw onboard --install-daemon
```

开发时不链接全局可直接用：

```bash
pnpm openclaw <command>
```

## 首次 onboarding

```bash
openclaw onboard --install-daemon
```

向导会引导选择 provider 和 API key。非交互式 provider 配置见 `provider_config.md`。
