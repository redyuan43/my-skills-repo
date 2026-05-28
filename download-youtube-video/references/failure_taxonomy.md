# Failure Taxonomy

## 登录态 / Cookie

- `Sign in to confirm your age`、members-only、private video：需要用户确认是否可使用登录态。
- 只有在用户明确提供 cookie 文件或确认可使用本机浏览器登录态时，才使用 `--cookies` 或 `--cookies-from-browser`。
- 不把登录态 cookie 写入仓库、日志或最终报告。

## 限流 / Challenge

- `HTTP Error 429`、`Signature solving failed`、`n challenge solving failed`：先切 hardened subtitle path，必要时使用浏览器 cookie、Node runtime 和 remote components。
- 这类错误不等同于“没有字幕”。

## 字幕不存在

- `has no subtitles`：手工字幕不存在。
- `Available automatic captions`：自动字幕存在，应按用户目标决定是否获取。

## 权限 / 区域 / DRM

- private、region-restricted、DRM-protected：报告原始错误和限制，不承诺绕过。

## 产物 Gate

- 下载成功后必须检查目标目录存在非空媒体、字幕或 `.info.json`。
- metadata-only 模式至少应生成 `.info.json` 或描述类 sidecar。
