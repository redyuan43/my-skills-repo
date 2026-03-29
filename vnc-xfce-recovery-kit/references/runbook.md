# Runbook

## 目标状态

恢复后应满足：

- `Xtigervnc` 监听 `5901`
- `xfce4-session`、`xfwm4`、`xfdesktop`、`xfce4-panel` 正常存在
- `exo-open --launch TerminalEmulator` 能打开 `gnome-terminal`
- `exo-open --launch WebBrowser` 能打开 `chromium`
- `chromium` 实际走 `Flatpak Chromium`

## 核心恢复动作

1. 重装 `selinux-policy-default`
2. 重装 `dbus` / `dbus-x11`
3. 重装完整 `XFCE` 关键包
4. 备份用户级 `XFCE` 与 `VNC` 配置
5. 恢复标准 `~/.vnc/xstartup`
6. 写入 `~/.vnc/config` 的 `extension = SELinux`
7. 固定 `helpers.rc` 到 `gnome-terminal + chromium`
8. 为 `chromium` 写入 Flatpak 包装器
9. 创建 `vnc-startup-hooks.d` 供后续扩展
10. 重建 `:1` 会话或刷新 `vncserver-headless.service`

## 为什么不继续走 Snap Chromium

Ubuntu 上的 `chromium-browser` 通常只是 `snap` 包装器。  
在 headless、VNC、容器化或权限异常场景里，`snap chromium` 往往是最不稳定的一环。

恢复脚本直接把默认浏览器入口切到 `Flatpak Chromium`，是为了降低回归概率。

## 为什么保留 `-extension SELinux`

某些机器上 `Xtigervnc` 在 `SELinux` policy 目录缺失或不完整时会直接崩在初始化阶段。  
即便补齐了 policy，保留这个绕过项仍然是更稳的默认值。

## 后续扩展建议

如果你以后想把更多动作编进“每次 VNC 桌面启动时自动执行”，优先放到：

```bash
~/.config/vnc-startup-hooks.d/
```

建议每个 hook 只做一件事，例如：

- `10-audio.sh`
- `20-browser.sh`
- `30-im.sh`

这样后续排障时能快速定位是哪一个 hook 破坏了体验。
