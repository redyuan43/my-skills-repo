---
name: lmstudio-auto-updater
description: 为 Linux 上通过 AppImage 安装的 LM Studio 执行自动检查、下载、校验、切换软链和用户级 systemd 定时更新。适用于用户要求“更新 LM Studio”“自动升级 LM Studio”“给 LM Studio 做自动更新脚本/skill”“检查本机 LM Studio 是否有新版本”这类场景。
---

# LM Studio Auto Updater

当用户要在 Linux 上更新 LM Studio 桌面软件，并且本机是 AppImage 安装形态时，使用这个 skill。

这个 skill 优先解决下面这类稳定场景：

- `~/.local/bin/lmstudio` 指向某个 `LM-Studio-*.AppImage`
- `~/.local/bin/lmstudio` 是 wrapper，并自动选择 `~/.local/opt/lmstudio/` 中版本号最高的 `LM-Studio-*.AppImage`
- LM Studio 位于 `~/.local/opt/lmstudio/`
- 机器是 `x64` 或 `arm64` Linux，需要选对对应安装包
- 用户希望先检查版本，再决定是否更新
- 用户希望把更新动作变成用户级定时任务
- 用户通过桌面快捷方式或应用菜单启动 LM Studio
- 用户机器上同时存在旧 Debian 包 `/opt/LM-Studio/lm-studio` 和新 AppImage，导致应用菜单启动旧版本

## 不适用边界

- 如果用户的 LM Studio 只有发行版包管理器安装，不要强行按 AppImage 覆盖；先安装或确认 AppImage 入口。
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
作用：下载最新 AppImage、尽量做 SHA-512 校验、写入 `~/.local/opt/lmstudio/`、更新启动入口，并修正 `~/.local/share/applications/lmstudio.desktop` 和桌面快捷方式。

更新后的固定收尾动作：

- 如果 `~/.local/bin/lmstudio` 是 wrapper，要保留 wrapper，让它继续自动选择最高版本 AppImage；不要覆盖成软链。
- 必须重写 `~/.local/share/applications/lmstudio.desktop`。
- 必须同步或创建 `~/Desktop/LM Studio.desktop` / `~/桌面/LM Studio.desktop`，避免用户点击桌面启动器时仍链接旧版本。
- 必须清理旧 AppImage，默认只保留最新版本。

4. 如果用户反馈“已经最新但启动的还是旧版”，检查重复启动入口
作用：识别并清理 Debian 包安装的旧 LM Studio 与旧桌面菜单项。

先看旧包和旧入口：

```bash
dpkg -S /opt/LM-Studio/lm-studio 2>/dev/null || true
dpkg -l lm-studio 2>/dev/null || true
sed -n '1,80p' ~/.local/share/applications/lm-studio.desktop 2>/dev/null || true
```

如果 `lm-studio` Debian 包仍存在、而 AppImage 已是官网 latest，并且用户同意删除旧应用，运行：

```bash
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh clean-legacy --purge-package
```

这会 purge `lm-studio` Debian 包、移除指向 `/opt/LM-Studio` 的旧 `lm-studio.desktop`，并刷新用户应用菜单数据库。不要只手工删除 `/opt/LM-Studio`，否则会留下脏的包管理器状态。

5. 如需长期自动化，再跑 `install-user-timer`
作用：写入用户级 `systemd` service/timer，每天自动执行一次 `update`。

6. 如果机器像这次一样遇到 Electron sandbox 报错
处理：把桌面启动器和命令行入口统一改成 `--no-sandbox`，避免“终端能起、桌面快捷方式起不来”。

## 关键规则

- 默认只处理当前用户目录下的 AppImage 安装，不碰系统级目录。
- 如果 `lmstudio` 不是直接 AppImage，但 `~/.local/bin/lmstudio` 是本机 wrapper 且 `~/.local/opt/lmstudio/` 有 LM Studio AppImage，也属于支持形态。
- 如果 `lmstudio` 是其他非 AppImage / 非 wrapper 形态，脚本会明确报出“当前不是该 skill 支持的安装方式”。
- Linux 包选择必须跟硬件架构匹配：
  `x86_64/amd64` 选 `x64`，`aarch64/arm64` 选 `arm64`。
- 下载源使用 LM Studio 官网的“latest”跳转入口，而不是把版本号写死。
- 如果能从官网页面取到 Linux 对应架构的 SHA-512，就校验；取不到时给出告警但不伪造校验成功。
- 如果当前环境存在 `chrome-sandbox` / Electron SUID sandbox 报错，默认通过 `--no-sandbox` 修正桌面启动器。
- `update` 默认会清理旧版本 AppImage，只保留最新版本；需要手动调整保留数量时用 `prune --keep N`。
- 如果旧 Debian 包和新 AppImage 并存，优先保留 AppImage wrapper，删除旧包和旧 `/opt/LM-Studio` 菜单入口；不要让两个 desktop entry 同时显示为 “LM Studio”。

## 常用命令

```bash
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh status
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh check
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh update
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh prune --keep 2
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh rewrite-desktop
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh clean-legacy --purge-package
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh install-user-timer
bash lmstudio-auto-updater/scripts/lmstudio_auto_update.sh uninstall-user-timer
```

## 验证口径

- `check` 显示 `update_available=true` 或 `false`
- 如果 `~/.local/bin/lmstudio` 是软链，`readlink -f ~/.local/bin/lmstudio` 指向新的 AppImage 文件
- 如果 `~/.local/bin/lmstudio` 是 wrapper，`~/.local/opt/lmstudio/` 中只保留最新 AppImage，wrapper 会自动启动它
- `~/.local/share/applications/lmstudio.desktop` 的 `Exec=` / `TryExec=` 指向 `~/.local/bin/lmstudio`
- `~/Desktop/LM Studio.desktop` 或 `~/桌面/LM Studio.desktop` 已同步，内容同样指向 `~/.local/bin/lmstudio`
- 如果当前机器需要绕过 sandbox，`Exec=` 中应包含 `--no-sandbox`
- `dpkg -l lm-studio` 不再显示 `ii` 或 `rc` 旧包状态，`/opt/LM-Studio` 不存在
- `~/.local/share/applications/lm-studio.desktop` 不存在，或不再指向 `/opt/LM-Studio`
- `systemctl --user list-timers | rg lmstudio-auto-update` 能看到定时器

## 资源说明

- `scripts/lmstudio_auto_update.sh`
作用：LM Studio AppImage 检查、升级、清理和定时任务安装的主入口。
- `scripts/selftest.sh`
作用：执行无副作用自检，验证脚本参数、官网 latest 跳转与本机探测链路。
- `agents/openai.yaml`
作用：skill 的 UI 元数据。
