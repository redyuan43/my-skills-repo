# Android 迁移决策与失败处理

## 迁移边界

| 层级 | 无 root 可行性 | 推荐做法 |
|---|---|---|
| 公共文件 | 高 | ADB 拉到主机，再推到目标；manifest + 抽样校验 |
| APK | 中到高 | 比较包名，拉取 base + split，`install-multiple` |
| 应用私有数据 | 通常不可行 | 重装应用，用户登录/云同步；不要伪造解密 |
| 系统设置 | 部分可行 | 逐项配置并验证，不盲目复制 settings 数据库 |
| 账号/令牌 | 不应复制 | 用户在目标设备重新授权 |

## 设备识别

不要只根据设备名称判断。至少记录：

- ADB serial
- `ro.product.device` / 产品代号
- Android API level
- 是否 USB 或 Wi-Fi ADB
- bootloader/root 状态（只有确实需要时检查）

同一品牌的普通版、Pro、运营商版和不同代号可能使用不同签名、分区、内核和 APK ABI；不能因为名称相似就刷入或迁移系统组件。

## APK 兼容性

- 目标 Android API 低于 APK `minSdk`：直接标记不兼容。
- 单 APK 应用可以用 `adb install -r`；存在多个 `split_config` 时必须一起使用 `adb install-multiple -r`。
- `TEST_ONLY` 包通常是开发/测试包，不应通过绕过安全检查安装；寻找正式发布版本。
- `USER_RESTRICTED` 可能是 MIUI 的 ADB 安装确认、安全守护、企业策略或安装来源限制。先检查屏幕和前台 Activity，只确认明确属于该 APK 的安装页。
- `Invalid apk` 可能是拉取不完整、split 缺失、架构/签名不匹配或 APK 本身不是可安装发布包；先重新拉取并检查 SHA-256，再决定是否放弃。
- 厂商系统包、厂商输入法、系统搜索、系统助手、WebAPK 通常依赖目标系统，不应按普通第三方 APK 迁移。

## 文件传输策略

使用批次和可恢复报告：

```text
source_serial -> host_workdir/timestamp -> target_serial
```

每批至少记录：相对路径、字节数、源/目标状态、失败原因和校验结果。目标冲突采用“保留目标 + 另存源文件 + 报告冲突”，除非用户明确要求覆盖。

## 账号和加密数据

应用能启动不代表数据已经迁移。以下内容通常不能通过 APK 或公共存储复制恢复：

- Android Keystore 绑定的密钥
- 登录 token、推送 token、设备绑定信息
- DRM、支付和银行安全模块
- 端到端加密聊天数据库
- 厂商云服务的设备密钥

迁移报告必须把“已安装应用”和“已恢复应用数据”分开统计。

## SSH/Tailscale

- 桌面已有免密 SSH 不代表手机密钥已获授权；用手机专用密钥加 `IdentitiesOnly=yes` 做验证。
- 手机 SSH config 只写 Tailscale DNS/别名、用户名、端口、`IdentityFile`、`StrictHostKeyChecking accept-new` 和 keepalive。
- Tailscale 登录必须由用户完成；复制 `state`、账号 token 或 VPN 私有数据不属于安全迁移。
