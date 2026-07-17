---
name: android-device-migration
description: 安全执行 Android 手机之间的设备识别、ADB/无线 ADB 连接、共享存储备份、第三方 APK 迁移、SSH/Tailscale 配置迁移和迁移后验证。用于“备份一台 Android 手机”“把旧手机数据/应用迁移到新手机”“通过 ADB 复制照片、文件和应用”“恢复手机上的 Termux/SSH 工作环境”等任务；必须区分可复制的共享文件、可重装的 APK 和不能在无 root 条件下直接复制的应用私有数据。
---

# Android Device Migration

## 核心原则

- 先识别设备型号、Android API、代号和 ADB 序列号，再执行任何写入。
- 优先 USB ADB；无线 ADB 只作为提速和日常操作通道。手机重启后 `tcpip 5555` 经常失效，需重新通过 USB 恢复。
- 将迁移拆成三层：共享存储文件、应用 APK、应用私有数据/账号。
- 无 root 时不要承诺完整复制 `/data/data`、应用数据库、登录令牌或 DRM 数据；这些通常只能重装应用后由用户登录/解密。
- 源设备只读提取，目标设备按包名比对后安装；不覆盖目标已有应用，不删除源数据。
- 所有报告不得写入密码、私钥、OAuth token、二维码或应用私有数据。

## 工作流

### 1. 盘点和连接

1. 运行 `adb devices -l`，记录每个 serial、model、product、device。
2. 用 `adb -s SERIAL shell getprop` 读取 `ro.product.device`、`ro.build.version.sdk`、Android 版本。
3. 通过 `pm list packages -3 --user 0` 盘点第三方应用；分别保存源和目标清单。
4. 如果使用 Wi-Fi ADB，先确认手机 IP 可达，再执行 `adb connect IP:5555`；连接被拒绝时不要反复重试，改用 USB 执行 `adb tcpip 5555`。
5. 记录迁移前目标剩余空间、电量和网络状态。

### 2. 文件备份和迁移

- 先在主机创建带时间戳的工作目录和 manifest。
- 主要迁移 `/sdcard/DCIM`、`Pictures`、`Movies`、`Music`、`Download`、`Documents`、Termux 可导出的文件和用户明确指定的目录。
- 大目录按子目录或批次传输；每批记录文件数、字节数、开始/结束时间、失败路径和校验结果。
- 推荐路径是“源手机 → 主机临时目录 → 目标手机”。局域网 ADB 可提升速度，但不能绕过 Android 权限。
- 目标端写入临时目录，完成后做文件数量/大小/抽样 SHA-256 对比，再合并到目标公共目录。
- 不把整个 `/sdcard` 盲目覆盖到目标；保留目标已有内容并记录冲突。

### 3. 第三方 APK 迁移

使用 `scripts/migrate_third_party_apks.sh`，或按以下逻辑执行：

1. 比较源和目标的第三方包名，只处理目标缺少的包。
2. 排除源设备专属系统包、输入法、系统搜索/助手、WebAPK、厂商组件和用户明确排除的应用。
3. 对源包运行 `pm path --user 0 PACKAGE`，拉取 base APK 和全部 split APK；不要只拉 base APK。
4. 使用 `adb install-multiple -r BASE.apk SPLITS...` 安装，记录每个包的结果。
5. 安装后用目标 `pm path --user 0 PACKAGE` 和版本信息验证。
6. 将失败分为：`INSTALL_FAILED_OLDER_SDK`、`INSTALL_FAILED_TEST_ONLY`、`INSTALL_FAILED_USER_RESTRICTED`、签名不匹配、split/解析失败和源 APK 不可读；不要把失败包无限重试。
7. `INSTALL_FAILED_USER_RESTRICTED` 只有在目标屏幕确实显示对应安装确认页时才点击；不得自动点击未知弹窗或通过修改安全策略绕过确认。

APK 迁移不等于数据迁移。应用私有数据库、登录状态、加密密钥、推送 token、支付和 DRM 数据必须由应用重新登录或重新同步。

### 4. Termux、SSH 和 Tailscale

- Termux 应用和插件必须来自同一发行渠道/签名；F-Droid Termux 不能安装 GitHub debug 签名的插件。
- SSH 迁移只复制脱敏后的 `config` 模板；为每台手机生成独立 Ed25519 密钥，把公钥追加到目标服务器 `authorized_keys`，不要复制或展示私钥。
- 连接验证使用 `ssh -o BatchMode=yes HOST hostname`，确认真正免密，而不是被桌面 SSH Agent 的另一把密钥掩盖。
- Tailscale 账号和 VPN 凭据不能通过复制 APK/配置安全迁移；目标手机必须由用户完成登录，随后只验证 Tailnet 连通性。
- 多主机终端优先使用一个 Termux + 命名 tmux 会话；如果用户明确需要桌面入口，使用 Termux:Widget，同签名安装并为每个主机生成独立快捷方式脚本。

### 5. 迁移后验收

- 重新盘点目标第三方包，确认目标已安装项没有被重复覆盖。
- 对文件迁移验证 manifest、数量、总大小和抽样校验和。
- 逐个打开关键应用，确认首次启动、账号登录、网络、通知、文件权限和应用内数据同步。
- 对 SSH 验证至少一个远程命令；对 Tailscale 验证设备在线和 SSH/服务连通性。
- 输出成功、跳过、失败三张清单，并明确哪些数据需要用户手动登录或授权。

## 资源

- 详细决策、失败分类和 Android 权限边界见 [references/migration-playbook.md](references/migration-playbook.md)。
- APK 盘点/迁移的可复用脚本见 [scripts/migrate_third_party_apks.sh](scripts/migrate_third_party_apks.sh)。

## 安全边界

- 不把用户提供的密码写进命令、脚本、报告或 Skill。
- 不读取、复制或展示应用私有目录中的令牌、聊天数据库、钱包、验证码和私钥。
- 涉及解锁 bootloader、刷机、清除分区、覆盖目标数据或修改系统安全策略时，先明确说明风险并要求确认。
