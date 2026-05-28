# Gate Checklist

## 状态 Gate

- 先确认 `nvfancontrol`、`systemctl`、`/sys/class/thermal` 和目标温度节点存在。
- 记录当前 `nvfancontrol` 状态和服务安装状态。
- 明确高温阈值、恢复阈值与轮询间隔，避免阈值反转。

## 修改 Gate

- 安装脚本会写入 `/usr/local/bin` 和 `/etc/systemd/system`，执行前必须确认。
- 启用或重启 `jetson-gpu-fan-guard.service` 前必须说明会接管风扇模式。
- 不在非 Jetson 或缺少 `nvfancontrol` 的机器上安装服务。

## 回滚 Gate

- 停止并禁用 `jetson-gpu-fan-guard.service`。
- 删除或保留服务文件需按用户要求执行。
- 恢复 `nvfancontrol` 自动模式，并检查日志确认风扇控制权已交回。
