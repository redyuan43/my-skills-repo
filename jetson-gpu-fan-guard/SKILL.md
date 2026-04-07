---
name: jetson-gpu-fan-guard
description: 在 Jetson 设备上安装 GPU 温度联动风扇守护进程：使用高温阈值与恢复阈值的滞回策略，当 GPU 温度高于阈值时切换到最大风扇，降到恢复阈值以下时恢复 `nvfancontrol` 自动模式，并写入 `systemd` 开机自启。适用于用户要求“新设备一键配置风扇温控策略”“把 GPU 超过 70 度时风扇拉满、降到 65 度再恢复自动”“安装一个开机自动运行且不会频繁抖动的风扇脚本/skill”这类场景。
---

# Jetson GPU Fan Guard

在目标机器是 Jetson，且用户想把 GPU 温度和风扇模式联动起来时使用这个 skill。

## 标准工作流

1. 先确认机器具备 Jetson 风扇控制组件：

```bash
command -v nvfancontrol
command -v systemctl
test -d /sys/class/thermal
```

2. 默认执行安装脚本，把守护脚本和 `systemd` 服务写入系统并立即启用：

```bash
sudo bash "jetson-gpu-fan-guard/scripts/install_jetson_gpu_fan_guard.sh"
```

如果用户想在安装时直接指定高温阈值和恢复阈值，改用：

```bash
sudo bash "jetson-gpu-fan-guard/scripts/install_jetson_gpu_fan_guard.sh" --threshold 70 --resume-threshold 65
```

3. 安装完成后检查服务状态：

```bash
sudo systemctl status jetson-gpu-fan-guard.service --no-pager
journalctl -u jetson-gpu-fan-guard.service -n 50 --no-pager
```

## 行为约定

- 默认高温阈值是 `70°C`，默认恢复阈值是 `65°C`。
- 当 GPU 温度 `>= 70°C` 时，脚本停止 `nvfancontrol`，切换到 `user_space`，并把 PWM 设为最大值。
- 当 GPU 温度 `<= 65°C` 时，脚本启动 `nvfancontrol`，恢复自动控风扇。
- 在 `66°C` 到 `69°C` 之间保持当前模式，不切换，避免在阈值附近抖动。
- 安装脚本支持 `--threshold` 和 `--resume-threshold` 参数；新设备优先在安装时直接传入阈值，避免再手改服务文件。
- 服务文件通过环境变量暴露两个阈值和轮询间隔；如果系统已经装好，也可以直接修改服务文件里的环境变量后再 `daemon-reload`。

## 调整阈值

如果用户要求改阈值，例如改成高温 `70°C`、恢复 `65°C`，直接修改服务文件里的环境变量：

```bash
sudo sed -i 's/^Environment=GPU_TEMP_THRESHOLD_C=.*/Environment=GPU_TEMP_THRESHOLD_C=70/' /etc/systemd/system/jetson-gpu-fan-guard.service
sudo sed -i 's/^Environment=AUTO_RESUME_TEMP_C=.*/Environment=AUTO_RESUME_TEMP_C=65/' /etc/systemd/system/jetson-gpu-fan-guard.service
sudo systemctl daemon-reload
sudo systemctl restart jetson-gpu-fan-guard.service
```

## 验证方式

- 查看日志里是否出现：
  - `GPU temperature >= ... switched fan to manual max`
  - `GPU temperature < ... restored automatic fan control`
- 查看服务是否已启用：

```bash
systemctl is-enabled jetson-gpu-fan-guard.service
systemctl is-active jetson-gpu-fan-guard.service
```

## 文件

- `scripts/jetson_gpu_fan_guard.sh`：常驻监控 GPU 温度并切换风扇模式
- `scripts/install_jetson_gpu_fan_guard.sh`：把脚本安装到 `/usr/local/bin`，写入 `systemd` 服务并启用开机自启
