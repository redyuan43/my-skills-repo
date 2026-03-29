---
name: gh-browser-chromium-fix
description: 配置 GitHub CLI 和系统默认 Web 处理器一起打开 Chromium，而不是 Firefox 或一个不可用的 Snap 浏览器。适用于 `gh auth login`、`gh browse` 和 `--web` 链接走错浏览器，或需要把 `gh config browser` 与 XDG 默认浏览器一起固定到 Chromium 时。
---

# GH Browser Chromium Fix

当 `gh auth login` 提示打开浏览器，但实际拉起 Firefox、Snap Chromium，或当前桌面默认浏览器不合适时，用这个 skill。

核心规则：

- `gh` 有自己的 `browser` 配置，但这台机器上的 `gh auth login` 还会跟随系统默认 Web 处理器。
- 所以要同时改 `gh config browser` 和 XDG 默认浏览器，才能稳定把登录页打开到 Chromium。
- 要填 Chromium 的绝对路径，不要只写 `chromium-browser`。
- 如果用户只想改全系统默认浏览器，不想碰 `gh`，就只做 XDG 那部分。

## 标准流程

1. 先看当前值和可用浏览器：

```bash
gh config get browser
xdg-mime query default x-scheme-handler/http
xdg-mime query default x-scheme-handler/https
command -v chromium chromium-browser google-chrome-stable google-chrome
```

2. 选一个可工作的 Chromium 可执行文件。

- 优先使用本机已经验证可用的原生 Chromium，例如 `/home/agx/.local/bin/chromium`
- 如果 `command -v chromium` 直接给出可执行文件，就用它
- 如果只找到 Snap 包装器，不要把包装器当作最终方案

3. 设置 `gh` 的浏览器：

```bash
gh config set browser /abs/path/to/chromium
```

4. 设置系统默认 Web 处理器：

```bash
xdg-mime default org.chromium.Chromium.desktop x-scheme-handler/http x-scheme-handler/https text/html
xdg-settings set default-web-browser org.chromium.Chromium.desktop 2>/dev/null || true
```

5. 验证：

```bash
gh config get browser
xdg-mime query default x-scheme-handler/http
xdg-mime query default x-scheme-handler/https
gio mime x-scheme-handler/http
gio mime x-scheme-handler/https
```

## 推荐脚本

优先使用：

```bash
bash gh-browser-chromium-fix/scripts/set_gh_browser.sh
bash gh-browser-chromium-fix/scripts/set_gh_browser.sh /home/agx/.local/bin/chromium
```

## 失败处理

- 如果 `gh auth login` 还打开 Firefox，先确认 `gh config get browser` 和 `xdg-mime query default x-scheme-handler/http` 都已经指向 Chromium。
- 如果本机只有 Snap Chromium，而且它在当前环境里不可靠，改用 `chromium-flatpak-fallback` 先把 Chromium 跑起来，再回来设置浏览器默认值。
- 如果用户要的是“所有网页链接都默认开 Chromium”，这就是这个 skill 的主任务，不要只改 `gh config browser`。
