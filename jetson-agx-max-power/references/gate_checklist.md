# Gate Checklist

## 状态 Gate

- 先运行 `status` 或等价只读命令，确认目标确实是 Jetson AGX Orin。
- 记录当前 `nvpmodel` mode、`jetson_clocks --show` 摘要和 restore 快照状态。
- 不把 `MAXN` 字样当成唯一成功证据，必须同时看 clocks 输出。

## 修改 Gate

- 执行 `max` 或 `restore` 前必须获得用户明确确认。
- 任何需要 `sudo` 的动作都必须先说明会改变 power mode 或 clocks 状态。
- 不在非 AGX Orin 设备上尝试套用本 skill。

## 回滚 Gate

- `max` 前应保留首次快照，不覆盖已有 restore 快照。
- `restore` 仅在恢复成功后删除快照。
- 如果恢复失败，保留快照并报告需要人工检查的命令输出。
