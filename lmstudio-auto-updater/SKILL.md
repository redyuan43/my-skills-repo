---
name: lmstudio-auto-updater
description: 为 Linux 上通过 AppImage 安装的 LM Studio 执行自动检查、下载、校验、切换软链和用户级 systemd 定时更新。适用于用户要求“更新 LM Studio”“自动升级 LM Studio”“给 LM Studio 做自动更新脚本/skill”“检查本机 LM Studio 是否有新版本”这类场景。
---

# LM Studio Auto Updater

当用户要在 Linux 上更新 LM Studio 桌面软件，并且本机是 AppImage 安装形态时，使用这个 skill。

这个 skill 优先解决下面这类稳定场景：

- `~/.local/bin/lmstudio` 指向某个 `LM-Studio-*.AppImage`
- LM Studio 位于 `~/.local/opt/lmstudio/`
- 机器是 `x64` 或 `arm64` Linux，需要选对对应安装包
- 用户希望先检查版本，再决定是否更新
- 用户希望把更新动作变成用户级定时任务
- 用户通过桌面快捷方式或应用菜单启动 LM Studio

## 不适用边界

- 如果用户的 LM Studio 是发行版包管理器安装，不要强行按 AppImage 覆盖。
- 如果用户机器根本没有 LM Studio，需要先安装，再谈更新。
- 如果用户要求更新 Windows 或 macOS 版本，不用这个 skill。

## 推荐入口

优先使用随 skill 附带的脚本：

```bash
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh status
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh check
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh update
```

如果用户希望以后自动更新：

```bash
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh install-user-timer
systemctl --user status lmstudio-auto-update.timer
```

## 工作流

1. 先跑 `status`
作用：确认当前 `lmstudio` 命令、软链目标、当前版本和安装形态。

2. 再跑 `check`
作用：从 `https://lmstudio.ai/download/latest/linux/<arch>?format=AppImage` 读取当前最新版本，并与本机版本比较。

3. 用户明确要更新时，再跑 `update`
作用：下载最新 AppImage、尽量做 SHA-512 校验、写入 `~/.local/opt/lmstudio/`、把 `~/.local/bin/lmstudio` 原子切到新版本，并修正 `~/.local/share/applications/lmstudio.desktop`。

4. 如需长期自动化，再跑 `install-user-timer`
作用：写入用户级 `systemd` service/timer，每天自动执行一次 `update`。

5. 如果机器像这次一样遇到 Electron sandbox 报错
处理：把桌面启动器和命令行入口统一改成 `--no-sandbox`，避免“终端能起、桌面快捷方式起不来”。

## 关键规则

- 默认只处理当前用户目录下的 AppImage 安装，不碰系统级目录。
- 如果 `lmstudio` 不是 AppImage 形态，脚本会明确报出“当前不是该 skill 支持的安装方式”。
- Linux 包选择必须跟硬件架构匹配：
  `x86_64/amd64` 选 `x64`，`aarch64/arm64` 选 `arm64`。
- 下载源使用 LM Studio 官网的“latest”跳转入口，而不是把版本号写死。
- 如果能从官网页面取到 Linux 对应架构的 SHA-512，就校验；取不到时给出告警但不伪造校验成功。
- 如果当前环境存在 `chrome-sandbox` / Electron SUID sandbox 报错，默认通过 `--no-sandbox` 修正桌面启动器。
- 默认保留旧版本 AppImage，不自动删除；需要清理时用 `prune`。

## 常用命令

```bash
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh status
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh check
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh update
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh prune --keep 2
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh rewrite-desktop
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh install-user-timer
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh uninstall-user-timer
```

## 验证口径

- `check` 显示 `update_available=true` 或 `false`
- `readlink -f ~/.local/bin/lmstudio` 指向新的 AppImage 文件
- `~/.local/share/applications/lmstudio.desktop` 的 `Exec=` / `TryExec=` 指向 `~/.local/bin/lmstudio`
- 如果当前机器需要绕过 sandbox，`Exec=` 中应包含 `--no-sandbox`
- `systemctl --user list-timers | rg lmstudio-auto-update` 能看到定时器

## 资源说明

- `scripts/lmstudio_auto_update.sh`
作用：LM Studio AppImage 检查、升级、清理和定时任务安装的主入口。
- `scripts/selftest.sh`
作用：执行无副作用自检，验证脚本参数、官网 latest 跳转与本机探测链路。
- `agents/openai.yaml`
作用：skill 的 UI 元数据。
