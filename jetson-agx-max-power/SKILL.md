---
name: jetson-agx-max-power
description: 在 Jetson AGX Orin 上管理 max power / MAXN：查看当前 power mode 和 clocks 状态，切到 MAXN + jetson_clocks，并在之后恢复到执行前自动保存的状态。适用于用户要求“切 AGX 到 max power”“开 MAXN”“恢复之前的 nvpmodel/power mode”“查看 AGX 当前功耗档位”这类场景。
---

# Jetson AGX Max Power

在目标机器是 `Jetson AGX Orin`，且用户想查看、切到或恢复 `MAXN / max power` 状态时使用这个 skill。

## 标准工作流

1. 先查看当前状态：

```bash
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh status
```

2. 需要切到最大性能时执行：

```bash
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh max
```

3. 需要回到执行 `max` 前的状态时执行：

```bash
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh restore
```

也支持常见中文别名：

```bash
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh status
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh 状态
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh 最大
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh restore
bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh 恢复
```

## 行为约定

- `status`
  - 读取当前机器型号、`/etc/nvpmodel.conf`、当前 power mode、默认 power mode。
  - 列出配置文件里定义的 mode 列表。
  - 输出 `jetson_clocks --show` 的精简摘要。
  - 说明是否存在可用于 `restore` 的快照。
- `max`
  - 首次执行时，自动保存当前 `nvpmodel` mode 和 `jetson_clocks` 状态。
  - 切到配置文件里探测到的 `MAXN` mode。
  - 执行 `jetson_clocks`，把 CPU/GPU/EMC 拉到静态最高频。
  - 如果之前已经有 restore 快照，保留原快照，不覆盖。
- `restore`
  - 恢复到最近一次 `max` 之前自动保存的 mode 和 clocks 状态。
  - 仅在确认恢复成功后删除快照。

## 约束

- 仅支持 `Jetson AGX Orin`。
- 依赖 `nvpmodel` 和 `jetson_clocks`。
- `max` 和 `restore` 需要可用的无交互 `sudo`。
- 这个 skill 不处理 `Super Mode`、bootloader、DTB 或风扇策略。

## 验证方式

- `status` 能看到 `MAXN` 和其他已定义 mode。
- `max` 后 `nvpmodel -q` 显示 `MAXN`。
- `max` 后 `jetson_clocks --show` 里的 CPU/GPU/EMC 上限被锁到高档位。
- `restore` 后 mode 与 clocks 回到执行 `max` 前的状态。

## 文件

- `scripts/jetson_agx_max_power.sh`：状态查看、切到 MAXN、恢复快照的唯一入口
- `agents/openai.yaml`：本地 UI metadata
