---
name: lmstudio-llmster-gui-reconcile
description: 修复 Linux 上通过 `install.sh` 安装 `llmster` 后，LM Studio GUI 与桌面启动器仍停留在旧 AppImage 的分叉状态；统一检查 `llmster`、`lmstudio` 软链、桌面 `.desktop`、最新 GUI AppImage 下载与旧包清理。适用于“`lms daemon up` 是新的，但桌面图标还是老版本”“`install.sh` 后 GUI 没跟着升级”“桌面入口仍指向旧 AppImage”“需要删掉旧 LM Studio 包只留新版”这类场景。
---

# LM Studio llmster / GUI Reconcile

当用户在 Linux 上执行：

```bash
curl -fsSL https://lmstudio.ai/install.sh | bash
```

之后发现：

- `llmster` / `lms daemon` 已经是新链路
- 但桌面图标仍启动旧 `LM-Studio-*.AppImage`
- `~/.local/bin/lmstudio` 还指向旧版本
- `~/.local/share/applications/lmstudio.desktop` 仍然沿用旧入口

就使用这个 skill。

这个 skill 专门解决“headless daemon 已更新，但 GUI 没切过去”的分叉问题。

## 典型症状

- 终端里 `lms daemon up` 正常，但点击桌面 `LM Studio` 还是旧版界面
- `which lmstudio` 指向 `~/.local/bin/lmstudio`
- `readlink -f ~/.local/bin/lmstudio` 指向旧的 `LM-Studio-0.x.y-1-*.AppImage`
- `~/.lmstudio/llmster/<version>/llmster` 已经比 GUI 新
- Electron 报 `chrome-sandbox` / `SUID sandbox helper binary`，而用户原来的桌面入口依赖 `--no-sandbox`

## 不适用边界

- Windows / macOS 不用这个 skill
- 如果机器并不是 AppImage 安装形态，不要强行覆盖
- 如果用户只要 `llmster` 头less 服务，不需要 GUI，就不用下载 AppImage
- 如果用户明确要求保留多个旧版本，不要自动清理

## 推荐入口

先看状态：

```bash
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh status
```

执行统一修复：

```bash
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh repair
```

如果还要清理旧包：

```bash
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh repair --prune-old
```

只改桌面入口，不下载：

```bash
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh rewrite-desktop
```

## 工作流

1. 先跑 `status`
作用：确认当前 `llmster` 路径、`lmstudio` 软链目标、桌面入口、系统架构和旧包分布。

2. 判断是否是“daemon 新、GUI 旧”
重点看：
- `~/.lmstudio/llmster/` 里是否已有新版本
- `~/.local/bin/lmstudio` 是否仍指向旧 AppImage
- `.desktop` 是否还在走旧入口

3. 跑 `repair`
作用：
- 根据架构选择 `x64` 或 `arm64`
- 通过 `https://lmstudio.ai/download/latest/linux/<arch>?format=AppImage` 下载最新 GUI AppImage
- 把 `~/.local/bin/lmstudio` 原子切到新 AppImage
- 重写 `~/.local/share/applications/lmstudio.desktop`

4. 如有 Electron sandbox 报错
处理：默认保留 `--no-sandbox` 在桌面入口里，避免桌面图标仍然启动失败。

5. 用户明确允许删旧包时，再加 `--prune-old`
作用：删除当前新版本之外的旧 `LM-Studio-*.AppImage`。

## 关键规则

- 默认只处理当前用户目录：
  `~/.local/bin/`
  `~/.local/opt/lmstudio/`
  `~/.local/share/applications/`
- 下载 GUI AppImage 与 `install.sh` 安装 `llmster` 是两条不同链路，不能假设前者会自动更新后者
- Linux 架构映射必须正确：
  `x86_64/amd64 -> x64`
  `aarch64/arm64 -> arm64`
- 默认重写桌面入口为：
  `Exec=~/.local/bin/lmstudio --no-sandbox %U`
- `TryExec=` 也要同步指向 `~/.local/bin/lmstudio`
- 只有用户明确允许时才删除旧 AppImage

## 常用命令

```bash
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh status
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh repair
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh repair --prune-old
bash lmstudio-llmster-gui-reconcile/scripts/reconcile_lmstudio_gui.sh rewrite-desktop
bash lmstudio-llmster-gui-reconcile/scripts/selftest.sh
```

## 验证口径

- `readlink -f ~/.local/bin/lmstudio` 指向最新 `LM-Studio-*.AppImage`
- `~/.local/share/applications/lmstudio.desktop` 的 `Exec=` 与 `TryExec=` 指向 `~/.local/bin/lmstudio`
- `Exec=` 中保留 `--no-sandbox`
- `~/.local/opt/lmstudio/` 中只剩用户想保留的版本
- 重新从桌面图标启动后，不再落到旧版 AppImage

## 资源说明

- `scripts/reconcile_lmstudio_gui.sh`
作用：检查、下载、切换 LM Studio GUI AppImage，并统一桌面入口。

- `scripts/selftest.sh`
作用：做无副作用自检，验证脚本存在、命令可解析和下载 URL 生成逻辑。
