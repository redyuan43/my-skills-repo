# 双 MI 自动化 Barge-in 回放经验

## 目标链路

最小自动化链路不是“真人说话”，而是：

1. `speaker1` 正在播报助手语音
2. `speaker2` 外放一段固定 TTS 短句，模拟外部插话
3. `mic1` 负责听到这段插话
4. 系统触发：
   - detect
   - stop `speaker1`
   - 录完插话
   - ASR 出最终文本

## 为什么这个方法值得复用

- 可重复，不依赖真人每次说话时机一致
- 可以对 `batch` / `stream` 做严格 A/B
- 可以自动落日志、落音频工件、做回归
- 一旦失败，可以直接定位到声学路由、检测源、还是收尾逻辑

## 已验证出的关键经验

### 1. 不要把 AEC 当成双设备场景的唯一真相源

在单设备自播里，`AEC source` 适合压掉自己外放的回声。  
但在双设备场景里，`speaker2` 明明是“外部插话”，`AEC` 也可能把它一起压掉。

因此：
- 双 `MI` 回放实验：`detector_source=raw`
- `AEC source` 只做旁路观测，不做默认检测源

### 2. 注入播放要优先直打 ALSA

`speaker2` 作为实验注入器时，软件播放成功不等于物理注入一定稳定。

实践上更稳的是：
- 优先按 sink 解析出 `alsa.card` / `alsa.device`
- 用：
`aplay -D plughw:CARD=<n>,DEV=<m> <wav>`

这样可以绕开 `Pulse/PipeWire` 在实验态下的额外不确定性。

### 3. 实验必须串行，不要并行

双 `MI` 是真实声学环境，不是纯计算任务。  
如果并行跑两个 trial，会互相污染：
- 一个 trial 的 `speaker1`
- 另一个 trial 的 `speaker2`
- 同时抢占同一支 `mic1`

正确做法：
- 一次只跑一条 trial
- `batch` 和 `stream` 分开串行跑

### 4. 打断成功不等于收尾正确

常见退化不是“完全没 detect”，而是：
- detect 很快
- 但 `capture_duration_ms` 一直拖到 `max_duration`
- 或最终只识别出半句

这个阶段要重点看：
- `capture_reason`
- `capture_duration_ms`
- `tracker_snapshot`

### 5. 当前默认应优先 batch

在这套双 `MI` 自动回放实验里，当前验证结果是：
- `raw + batch` 可稳定通过最小短句打断
- `raw + stream` 仍会出现漏检或不稳定

所以当前默认策略应该是：
- `barge-in detector source = raw`
- `barge-in asr mode = batch`

`stream` 只作为显式实验开关保留。

## 推荐的最小实验口径

使用固定短句：
- `等一下`

理由：
- 易于判断句首是否丢失
- 容易观察 stop latency
- 易于比较 `batch` vs `stream`

## 交付物检查清单

每轮至少应保留：
- `summary.json`
- `lab.log`
- `assistant_playback.wav`
- `interrupt_stimulus.wav`
- `injector_preflight_raw.wav`
- `captured_input.wav`
- `trace.jsonl`

## 对后续运行时默认值的影响

如果实验台结论稳定指向：
- `raw` 稳定
- `AEC` 明显误伤外部插话
- `batch` 比 `stream` 稳

那么主运行时也应同步：
- 默认 `raw`
- 默认 `batch`
- 把 `stream` 降级为试验开关
