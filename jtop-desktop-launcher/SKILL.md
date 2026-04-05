---
name: jtop-desktop-launcher
description: 为 Linux 桌面创建可双击的 `jtop` 启动器：自动重启 `jtop.service`、可选配置单命令免密 sudo，并在服务真正就绪后再进入 `jtop`。适用于“每次重启后都得手动 `systemctl restart jtop.service` 才能打开 jtop”“想做桌面快捷方式双击启动”“pkexec 图形认证失败”这类场景。
---

# JTop Desktop Launcher

当用户说“每次重启后都要先重启 `jtop.service` 才能运行 `jtop`”、“想做桌面双击启动器”、“`pkexec` 双击后报 `No session for cookie`”时使用这个 skill。

## 适用判断

- 当前系统能正常使用 `jtop`，但常见问题是开机后首次启动前需要先执行：

```bash
sudo systemctl restart jtop.service
```

- 用户明确想要桌面图标双击启动，而不是每次手敲命令。
- 桌面环境通常是 XFCE / GNOME / 其他 X11 Linux 桌面。

## 关键经验

- `pkexec` 在桌面双击场景里可能拿不到有效图形认证会话，典型报错是 `No session for cookie`。遇到这种情况，优先改成终端里的 `sudo`，不要继续卡在 `pkexec`。
- 如果要做免密，权限必须收窄到单条命令：

```text
/usr/bin/systemctl restart jtop.service
```

- 不要在 `systemctl restart jtop.service` 返回后立刻启动 `jtop`。服务虽然重启命令已完成，但 `jtop` 客户端可能仍然报 `The jtop.service is not active`。正确做法是轮询 `systemctl is-active --quiet jtop.service`，确认服务 ready 后再打开 `jtop`。

## 标准工作流

1. 先确认依赖存在：

```bash
command -v jtop
command -v xfce4-terminal
command -v systemctl
```

2. 默认用安装脚本生成桌面启动器：

```bash
bash "jtop-desktop-launcher/scripts/install_jtop_desktop_launcher.sh"
```

3. 如果用户明确要求双击时不输入密码，再启用最小免密规则：

```bash
bash "jtop-desktop-launcher/scripts/install_jtop_desktop_launcher.sh" --nopasswd
```

4. 安装后直接让用户双击桌面上的 `JTop.desktop`。

## 结果约定

- 桌面生成两个文件：
  - `~/Desktop/jtop-restart-and-run.sh`
  - `~/Desktop/JTop.desktop`
- 若启用免密，则写入：
  - `/etc/sudoers.d/jtop-restart-nopasswd`

## 验证方式

- 先验证 sudoers 语法：

```bash
sudo visudo -cf /etc/sudoers.d/jtop-restart-nopasswd
```

- 再验证服务状态：

```bash
systemctl is-active jtop.service
```

- 最后用真实终端或真实桌面双击流程验证，不要只看 `systemctl restart` 的退出码。

## 文件

- `scripts/install_jtop_desktop_launcher.sh`：安装桌面快捷方式，可选配置最小免密 sudo 规则