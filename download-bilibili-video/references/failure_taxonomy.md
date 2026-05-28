# Failure Taxonomy

## 登录态 / Cookie

- `412 Precondition Failed`、login required、会员或地区限制：先确认用户是否允许使用浏览器登录态。
- 优先使用 wrapper 的浏览器 profile 检测；只有用户明确提供 cookie 文件时才用 raw cookie file。
- 不把 cookie 文件、浏览器 profile 内容或登录态摘要写入仓库。

## 短链 / URL 解析

- `b23.tv` 失败时先展开短链，再用解析后的 `bilibili.com/video/BV...` 重试。
- URL 展开失败应报告解析阶段错误，不归因于下载器。

## 字幕 / 弹幕

- 字幕不存在、自动字幕不存在、弹幕下载失败要分开报告。
- subtitle/danmaku-only 模式成功时，至少应有字幕、弹幕或 `.info.json` sidecar。

## 权限 / DRM

- private、region-restricted、members-only、DRM-protected：报告原始错误和限制，不承诺绕过。

## 产物 Gate

- video/audio 模式必须检查非空媒体文件。
- metadata 模式必须检查 `.info.json` 或描述类 sidecar。
