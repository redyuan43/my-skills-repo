# Rejected Edits

- 不把阈值写死到守护脚本里；优先通过环境变量或安装参数配置。
- 不用无滞回的单阈值策略，避免风扇反复抖动。
- 不在 selftest 中读写真实 PWM、停止服务或调用 sudo。
- 不替换系统自带 `nvfancontrol`，只做可回滚的外层守护。
