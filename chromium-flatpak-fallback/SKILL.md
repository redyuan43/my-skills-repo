---
name: chromium-flatpak-fallback
description: 当 Ubuntu 22.04/Jetson 上的 `chromium-browser` 实际是 Snap 包装器、`snap run chromium` 因 `snap-confine`、user namespace、容器/沙箱限制或宿主环境不兼容而打不开时，改走 Flatpak 安装和启动真正可用的 Chromium。适用于“Chromium 打不开”“必须用 Chromium 但 Snap 一直失败”“浏览器在 agent 里测不通”这类场景。
---

# Chromium Flatpak Fallback

当用户明确需要 Chromium，而 Ubuntu 自带的 `chromium-browser` 只是一个 Snap 包装器时，用这个 skill。

核心经验：

- Ubuntu 22.04 上的 `chromium-browser` 通常不是原生 deb，而是转发到 Snap。
- 在 user namespace、容器、agent sandbox、部分远程桌面或宿主权限异常环境里，`snap run chromium` 很容易假死、直接退出，或者报 `snap-confine` / capability 错误。
- 这时不要反复纠缠包装器。若用户真正需要的是 Chromium，本机又已有图形桌面，直接装 `org.chromium.Chromium` Flatpak 往往更快、更稳。

## 先判断是不是这个问题

先跑：

```bash
sed -n '1,120p' /usr/bin/chromium-browser
```

如果末尾是：

```bash
exec /snap/bin/chromium "$@"
```

说明你面对的不是普通 deb 版 Chromium，而是 Snap 包装层。

再检查：

```bash
snap run chromium --version
```

如果看到这类报错，就应优先切到 Flatpak 路线：

- `snap-confine is packaged without necessary permissions`
- `required permitted capability ... not found`
- Snap 命令卡住不返回
- 在 agent / sandbox 里永远起不来，但机器本身其实有图形桌面

## 标准工作流

1. 先确认机器上有图形会话。

```bash
echo "DISPLAY=${DISPLAY:-}"
echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"
```

2. 如果用户明确需要 Chromium，而 Snap 路线不可靠，安装 Flatpak Chromium：

```bash
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak --user install -y flathub org.chromium.Chromium
```

3. 启动：

```bash
setsid -f env DISPLAY=:1 XDG_RUNTIME_DIR=/run/user/$(id -u) flatpak run org.chromium.Chromium
```

如果当前 shell 已经在桌面会话里，也可以直接：

```bash
flatpak run org.chromium.Chromium
```

4. 如果用户希望像普通桌面应用那样双击图标启动，把启动器放到桌面：

```bash
cp ~/.local/share/flatpak/exports/share/applications/org.chromium.Chromium.desktop ~/Desktop/Chromium.desktop
chmod +x ~/Desktop/Chromium.desktop
```

在 XFCE / Ubuntu 桌面里，必要时右键图标选择 `Allow Launching` 一次即可。

## 推荐脚本

优先使用随 skill 附带的脚本：

```bash
bash chromium-flatpak-fallback/scripts/chromium_flatpak_fallback.sh diagnose
bash chromium-flatpak-fallback/scripts/chromium_flatpak_fallback.sh install
bash chromium-flatpak-fallback/scripts/chromium_flatpak_fallback.sh launch
bash chromium-flatpak-fallback/scripts/chromium_flatpak_fallback.sh desktop
```

## 验证

- `flatpak info org.chromium.Chromium` 应能返回应用信息。
- `ps -ef | grep -i chromium` 应能看到进程。
- 真正的成功标准是桌面里出现 Chromium 窗口，而不是某个 sandbox shell 里 `snap` 看起来正常。

## 什么时候不要用这个 skill

- 用户只想修 Snap 本身，不接受 Flatpak 路线。
- 机器根本没有图形桌面，问题是显示栈/VNC 没起来。那时优先用 `headless-vnc-chromium-fix`。
- 用户接受其他浏览器即可，不要求 Chromium。
