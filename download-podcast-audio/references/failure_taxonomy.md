# Failure Taxonomy

## 登录态 / Cookie

- login required、paywalled、region-gated：先确认用户是否允许使用浏览器登录态或提供 cookie 文件。
- 只有用户明确授权后才使用 `--cookies-from-browser` 或 `--cookies`。
- 不保存、打印或提交 cookie 内容。

## Generic Extractor

- podcast 页面走 generic extractor 且能解析出直连音频时可接受。
- generic extractor 无法解析时，应报告页面解析失败，不直接说节目不存在。

## 音频容器 / 转码

- 用户要求保留原容器时不要强制转码。
- 用户要求 MP3 等格式时，确认本机有 `ffmpeg` 或报告依赖缺失。

## 权限 / DRM

- 私有、地区限制、DRM、仅流媒体不可下载：报告原始错误，不承诺绕过。

## 产物 Gate

- audio 模式必须检查非空音频文件。
- metadata 模式必须检查 `.info.json`、description 或 thumbnail sidecar。
