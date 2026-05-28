# OpenClaw Troubleshooting

## `openclaw: command not found`

```bash
node -v && npm -v
npm prefix -g
echo "$PATH"
```

如果全局 bin 不在 PATH，可临时验证：

```bash
export PATH="$(npm prefix -g)/bin:$PATH"
```

写入 `~/.bashrc` 或 `~/.zshrc` 前先确认用户允许修改 shell profile。

## `nohup: failed to run command 'openclaw'`

通常是 PATH 中没有 `openclaw`。源码运行时改用：

```bash
nohup pnpm openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &
```

## Config 验证失败

```bash
openclaw doctor
openclaw doctor --fix
```

`doctor --fix` 可能写配置，执行前确认。

## Control UI 显示 assets not found

源码运行时先构建 UI：

```bash
pnpm ui:build
```

然后重启 gateway。

## Provider 认证失败

1. 确认 API key 写入的是环境变量或私有配置，不要泄露到可提交文件。
2. 确认 `baseUrl` 与 key 类型匹配。
3. 运行 `openclaw doctor`。
4. 检查旧 OAuth token 是否优先于 API key：`openclaw auth status`。
