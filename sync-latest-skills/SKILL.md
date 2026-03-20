---
name: sync-latest-skills
description: 从 `my-skills-repo` 拉取最新内容，并把仓库里的顶层技能目录同步到 `~/.codex/skills`；适用于需要一键刷新本地技能目录、修复旧版本、或把仓库更新反映到本机技能链接时使用。
---

# Sync Latest Skills

当需要把 `my-skills-repo` 的最新 skills 同步到本机 `~/.codex/skills` 时使用这个 skill。

## 标准工作流

1. 先运行只读检查：

```bash
bash sync-latest-skills/scripts/sync_latest_skills.sh --dry-run
```

2. 确认要同步的技能列表和冲突项后，再运行：

```bash
bash sync-latest-skills/scripts/sync_latest_skills.sh
```

3. 如果本机 `~/.codex/skills/<skill>` 已经是旧目录而不是链接，并且你确认可以被仓库版本替换，再加 `--force`：

```bash
bash sync-latest-skills/scripts/sync_latest_skills.sh --force
```

## 行为规则

- 先执行 `git pull --ff-only`，确保仓库是最新的
- 只同步仓库根目录下的技能目录
- 跳过 `README.md`、`.git`、`.serena`、`.codex` 等非技能项
- 默认不会删除已有目录；遇到冲突会明确跳过并汇报
- `--force` 仅用于把已有目录替换成指向仓库的符号链接

## 适用边界

- 这是本地同步技能，不负责提交或推送到 GitHub
- 如果要把新技能发布回 `my-skills-repo`，继续使用 `publish-skill-to-my-skills-repo`

## 文件

- `scripts/sync_latest_skills.sh`：拉取仓库并同步顶层技能目录到 `~/.codex/skills`
