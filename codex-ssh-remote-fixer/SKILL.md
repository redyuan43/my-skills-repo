---
name: codex-ssh-remote-fixer
description: 诊断并修复“`ssh host` 能登录，但远端 `codex` 通过 SSH 命令跑不起来”的场景。适用于远端 `codex` 只在交互式 shell 可见、`nvm` 路径未进入非交互 PATH、远端本地代理（如 xray/clash/v2ray）已运行但 `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` 未导出、以及 `codex`/`curl` 裸连 OpenAI 一直超时的情况。
---

# Codex Remote SSH Fixer

## 适用场景

- 用户说：`ssh nx2` 能进去，但 `ssh nx2 'codex ...'` 不行
- 用户必须先手工登录远端服务器，再在里面启动 `codex`
- 远端 `codex` 在交互式 shell 里存在，但非交互执行时显示 `command not found`
- 远端机器本地代理已经跑着，但 `codex` / `curl` 仍然超时

## 目标

把这类问题收敛成一个可重复执行的修复流程：

1. 对比远端交互式与非交互式 shell 的 `PATH`
2. 修复远端 `codex` 的 shell 初始化
3. 检测远端本地代理端口，并导出标准代理环境变量
4. 验证 `codex --version` 与 OpenAI 连通性
5. 可选做一次最小 `codex exec` 端到端验证

## 使用方式

主脚本：

```bash
bash codex-ssh-remote-fixer/scripts/repair_remote_codex_over_ssh.sh <host>
```

常见例子：

```bash
bash codex-ssh-remote-fixer/scripts/repair_remote_codex_over_ssh.sh nx2
bash codex-ssh-remote-fixer/scripts/repair_remote_codex_over_ssh.sh nx2 --proxy-port 10808
bash codex-ssh-remote-fixer/scripts/repair_remote_codex_over_ssh.sh nx2 --exec-check
```

建议顺序：

1. 先不带 `--exec-check` 跑一次，把 shell 与代理修好
2. 看到 `curl https://api.openai.com/v1/models` 返回 `401` 或其他 HTTP 响应后，再按需加 `--exec-check`

## 脚本会做什么

- 在远端创建或更新 `~/.codex-shell-env`
- 让 `~/.profile` 和 `~/.bashrc` 统一加载它
- 尝试把 `codex` 包装器装到 `/usr/local/bin/codex`
  - 如果远端当前用户支持 `sudo -n`
  - 否则退回到 `~/bin/codex`
- 当远端直连 OpenAI 失败时，探测常见本地代理端口：
  - 默认顺序：`10808`、`7890`、`7891`、`1080`、`8080`
- 当某个本地代理端口可用时，把它写成标准环境变量：
  - `HTTP_PROXY`
  - `HTTPS_PROXY`
  - `ALL_PROXY`
  - `NO_PROXY`

## 期望结果

修复后，这两种方式都应该可用：

```bash
ssh <host> 'codex --version'
ssh <host> 'bash -lc "codex --version"'
```

若要做完整验证，可加：

```bash
bash codex-ssh-remote-fixer/scripts/repair_remote_codex_over_ssh.sh <host> --exec-check
```

## 安全边界

- 脚本只改远端当前用户的 dotfiles 和一个 `codex` 包装器
- 修改前会备份：
  - `~/.profile`
  - `~/.bashrc`
  - `~/.codex-shell-env`
- 不会删除远端已有 `~/.codex/auth.json`
- 不会改系统代理服务本身，只是导出环境变量

## 风险与限制

- 如果目标机器既不能直连外网，也没有本地代理监听，这个 skill 只能明确报出“没有可用网络路径”，不能凭空打通网络
- 如果目标机器上的代理需要额外认证、证书或 GUI 登录，本脚本不会代替这些步骤
- `--exec-check` 会真的调用一次远端 `codex exec`，因此会消耗远端账号的 token / quota
- 如果远端没有 `sudo -n`，脚本会退回到 `~/bin/codex` 包装器；这种情况下通常也能工作，但系统级 PATH 一致性不如 `/usr/local/bin/codex`
- 如果远端已有非常定制化的 `~/.bashrc` / `~/.profile`，脚本虽然只做最小插入，但仍应依赖备份文件做人工回退

## 失败时的明确结论

- `codex --version` 成功，但 `curl` 直连超时且脚本提示 no verified outbound path
  - 结论：远端没有可用的 OpenAI 网络出口，需要先准备代理或放通外网
- 只在 `bash -ic` 能找到 `codex`，`ssh host 'codex --version'` 找不到
  - 结论：`nvm` / PATH 只在交互式 shell 加载，脚本应修复这个差异
- `curl` 经过代理能返回 `401`
  - 结论：网络已通；后续若 `codex` 仍失败，应转向认证、登录状态或账户权限排查

## 失败时的判断顺序

1. `ssh <host>` 本身是否通
2. 远端交互式 shell 是否能找到 `codex`
3. 远端本地是否已有代理监听
4. 远端经代理是否能 `curl https://api.openai.com/v1/models`
5. 若仍失败，再看是否是远端认证或 OpenAI 账户问题
