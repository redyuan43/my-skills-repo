---
name: linux-headless-memory-trim
description: 为 Linux 推理设备执行可回滚的内存精简。用于“系统空载内存占用偏高”“希望仅保留推理服务（如 Ollama）”“需要关闭桌面与非核心后台”场景。包含基线审计、服务停用、默认目标切换、回滚与验收流程，并明确列出应保持不修改的核心服务。
---

# Linux Headless Memory Trim

## Quick Start

1. 先做基线审计。

```bash
scripts/audit_profile.sh
```

2. 预演将执行的变更（不改系统）。

```bash
scripts/apply_profile.sh --dry-run
```

3. 确认后执行变更。

```bash
scripts/apply_profile.sh --apply
```

4. 验证结果。

```bash
scripts/audit_profile.sh
systemctl get-default
```

## Workflow

1. 固定目标。
- 目标是“纯推理/无头运行”，仅保留推理与远程运维所需组件。
- 默认保留 `ollama.service`、`ssh.service`、`NetworkManager.service`。

2. 先审计再操作。
- 记录 `free -h`、高内存进程、已启用服务，避免凭感觉处理。

3. 执行可回滚精简。
- 停用并禁用非核心服务：桌面、容器、蓝牙、调制解调器、mDNS、snap 常驻与相关 socket。
- 切换默认启动目标到 `multi-user.target`。
- 如果机器使用 `GDM/GNOME`，要额外记录 `/etc/systemd/system/display-manager.service` 是否存在，以及 `graphical.target.wants/display-manager.service` 是否仍指向 `gdm.service`。某些机器在 `disable --now gdm.service` 后，这两条启动链会被移除。

4. 明确“未修改项”。
- 核心网络、远程登录、推理服务与硬件必需服务保持不改。
- 参考 [references/service-profiles.md](references/service-profiles.md) 的 `KEEP_UNCHANGED` 列表。

5. 验收并按需回滚。
- 验证内存下降、目标服务 inactive、核心服务 active。
- 若需要恢复桌面/容器，使用 `scripts/rollback_profile.sh`。
- 若系统已经切回 `graphical.target`，但重启后仍只进命令行，优先检查 `display-manager.service` 链接是否缺失，而不是先怀疑显卡或桌面包损坏。

## Safety Rules

- 默认使用 `--dry-run`；仅在明确确认后使用 `--apply`。
- 需要 root 权限；优先使用 `sudo`。
- 对生产环境先在维护窗口执行，并保留远程带外入口。
- 禁用桌面前先确认“只需要关闭远程桌面”还是“连本地图形登录也要关闭”。`gnome-remote-desktop.service`、`tigervncserver@:<display>.service` 这类远程桌面服务应与 `gdm.service` 区分处理。

## Lessons Learned

- `systemctl set-default graphical.target` 只决定默认目标，不保证 `gdm.service` 一定会被自动拉起。
- 在一些发行版上，`gdm.service` 是 `static` 单元；如果 `/etc/systemd/system/display-manager.service` 和 `/etc/systemd/system/graphical.target.wants/display-manager.service` 被删掉，系统即使默认目标是 `graphical.target`，重启后也可能只进命令行。
- 关闭远程桌面要先区分具体实现。`gnome-remote-desktop.service` 停掉后，机器仍可能因为 `tigervncserver@:1.service` 之类的旧会话而提示“有远程桌面正在运行”。
- 恢复图形启动链时，优先修复 `display-manager.service -> gdm.service` 和 `graphical.target.wants/display-manager.service -> gdm.service`，再验证 `gdm.service` 是否能正常启动。

## Resources

- `scripts/audit_profile.sh`: 输出基线与验收信息。
- `scripts/apply_profile.sh`: 执行或预演内存精简。
- `scripts/rollback_profile.sh`: 回滚关键服务与默认启动目标。
- `references/service-profiles.md`: 变更项、未修改项、可选卸载项模板。
