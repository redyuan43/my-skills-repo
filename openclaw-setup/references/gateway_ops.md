# OpenClaw Gateway Operations

## 只读验证

```bash
openclaw doctor
openclaw gateway status
openclaw dashboard
```

Control UI 默认地址：`http://127.0.0.1:18789`。

## 启动 gateway

全局安装：

```bash
openclaw gateway run --bind loopback --port 18789 --force
```

源码开发：

```bash
pnpm openclaw gateway run --bind loopback --port 18789 --force
```

后台运行：

```bash
nohup pnpm openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &
```

## 验证日志和 channel

```bash
tail -n 20 /tmp/openclaw-gateway.log
openclaw channels status --probe
```

macOS 优先使用 menu bar app 启动/停止 gateway，不要混用临时进程。

## 重启注意

停止或杀掉 live gateway 可能影响正在使用的 agent/channel。除非用户明确要求，不要自动执行 `pkill` 或替换持久服务。
