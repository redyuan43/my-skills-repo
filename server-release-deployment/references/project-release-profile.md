# 项目发布配置模板

将下面信息写入项目的 `AGENTS.md` 或发布文档，并保持它与实际脚本一致：

```markdown
## 服务端发布

- 权威代码目录：`/absolute/path/to/repository`
- 远端权威来源：`owner/repository` 的 `main`
- 发布入口：`./deploy.sh`
- 目标：`edge-a`、`edge-b`
- 状态与密钥：`/path/to/state`、`/path/to/config`，不得跨节点复制
- 健康检查：`./deploy.sh status` 或明确的只读命令
- 回滚：`./deploy.sh rollback TARGET RELEASE_ID`
- 最低测试：`command to run tests`
```

不要把密码、token、私钥或实际密钥内容写入该文档。记录引用方式、环境变量名或秘密管理位置即可。

对于已有项目，文档应引用现存脚本而不是重写一套相近但不一致的命令。修改发布脚本、服务位置或节点清单时，同步更新此配置。
