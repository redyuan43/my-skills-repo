# 发布操作参考

## 控制目录与远端版本

```bash
cd /home/ivan/github/PyWxDump
gh api repos/redyuan43/PyWxDump/git/ref/heads/master --jq .object.sha
```

该目录是发布控制端。节点上的 `/opt/siyuan-audio/current` 只运行 release，不是日常编辑位置。

## 发布

代码已测试并合并到 GitHub `master` 后，用户明确要求发布时执行：

```bash
./deploy.sh all
```

该命令会复用当前 master 对应的 `edge-v...` tag，或创建下一个 tag；随后对 Nano1、Nano2、Nano3 预部署同一 commit，全部预部署成功后才激活。

单节点验证或灰度：

```bash
./deploy.sh nano3
```

## 验收

```bash
./deploy.sh status
```

每个节点必须满足：

- `current` 指向同一个 `edge-v...-<short-sha>` release。
- `siyuan-audio-api.service` 与 `siyuan-audio-worker.service` 都是 `active`。
- `/api/version` 的 `release` 和完整 `commit` 相同。
- 未带设备令牌请求 `/api/voice-notes/sync` 返回 `401`，证明同步路由已加载且仍受鉴权保护。

不要在验收输出中打印设备 token、账户密码、私钥或节点配置。

## 回滚

从 `./deploy.sh status` 或最近部署日志得到 release ID 后：

```bash
./deploy.sh rollback nano2 RELEASE_ID
```

仅回滚用户指定的节点。回滚后重新执行 `./deploy.sh status`。若由本次部署导致服务无法启动，优先恢复部署前的 release，再分析日志；不要在生产目录直接编辑 Python 文件。

## 新节点首次接入

节点必须先有到私有 GitHub 仓库的只读 deploy key：

```bash
tools/bootstrap_audio_node_github_access.sh NEW_NODE
```

当前快捷脚本内置的节点名是 `nano1`、`nano2`、`nano3`。新增节点时，先扩展控制脚本和文档，再纳入 `all`；在此之前使用底层发布命令并显式提供 GitHub tag 与 commit。

## 最终汇报

发布或修复完成时，简短说明：

- 已合并的 GitHub `master` 提交或 PR。
- release tag 与 commit。
- 每台被部署节点的结果。
- 运行的测试与验收命令。
- 是否更新了客户端/服务端 `AGENTS.md` 指针。
- 遗留风险或未执行的实机验证。
