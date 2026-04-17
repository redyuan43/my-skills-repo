# Proxy Socket Runbook

## 现象归类

这类问题常见于 Linux 桌面环境 + 本地代理组合：

- `ALL_PROXY=socks://127.0.0.1:10808/`
- `HTTP_PROXY=http://127.0.0.1:10808/`
- 程序库对 `socks://` 不兼容，只接受 `socks5://`

典型报错：

- `ValueError: Unknown scheme for proxy URL URL('socks://127.0.0.1:10808/')`
- `Using SOCKS proxy, but the 'socksio' package is not installed`
- 某些 CLI、Python SDK、Node SDK、浏览器包装器只能在一部分程序里工作

## 为什么不是简单“关闭代理”

很多机器确实需要代理访问外网：

- 包管理器
- GitHub / OpenAI / Hugging Face
- 各类 AI CLI
- 浏览器和桌面应用

因此更合理的处理通常是：

1. 保留本地代理入口
2. 统一 shell 里的代理变量格式
3. 把 `socks://` 改为 `socks5://`
4. 缺什么语言运行时依赖，再按应用环境补，例如 `httpx[socks]`

## 为什么会“一部分程序行，一部分不行”

- 不同运行库对 SOCKS URL 兼容性不同
- 有的只接受 `socks5://`
- 有的接受 `socks5h://`
- 有的会自动读用户站点包，有的只看 venv
- GUI 代理、GNOME `gsettings`、shell 环境变量、systemd user environment 可能不是同一层

因此排障时不要只看一处。

## 建议顺序

1. 先确认本地代理进程和监听端口
2. 再看 shell 变量值是否错误
3. 若 shell 变量错误，先修格式
4. 若应用仍报错，再检查应用运行环境是否缺少 SOCKS 依赖
5. 最后再考虑更深层的桌面会话或 systemd 环境问题
