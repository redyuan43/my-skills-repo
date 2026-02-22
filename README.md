# 我的技能仓库

这个仓库存储我的个人技能（skills）集合，每个文件夹包含一个独立的技能。

## 技能列表

### 1. windows-network-share-fix
**功能：** 修复Windows 11网络共享访问问题
**用途：** 当用户无法访问网络共享并收到"组织的安全策略阻止未经身份验证的来宾访问"错误时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `enable_guest_access.reg` - 注册表修复文件
- `fix_network_share.ps1` - PowerShell修复脚本

### 2. gh-repo-maintenance
**功能：** 使用 `gh` CLI 维护 GitHub 仓库（登录检查、仓库盘点、批量筛选、隐藏/删除）
**用途：** 当需要整理 GitHub 仓库、筛选可删除仓库、批量删除老 fork，或把符合条件的仓库改为私有（隐藏）时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `scripts/repo_cutoff_visibility.py` - 按日期列出/隐藏仓库（改私有）
- `scripts/repo_bulk_delete_forks.py` - 批量删除老 fork（默认 dry-run，需 `--apply`）
- `references/gh-github-repo-maintenance-notes.md` - 常见错误与处理说明

### 3. publish-skill-to-my-skills-repo
**功能：** 将本地 Codex skill 按 `my-skills-repo` 格式发布到 GitHub 技能仓库
**用途：** 当需要把新建技能同步到 `my-skills-repo`、保持目录结构一致、生成 README 条目模板并完成提交推送时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `scripts/import_skill_to_my_skills_repo.py` - 复制本地技能到仓库并生成 README 条目模板
- `references/my-skills-repo-format.md` - `my-skills-repo` 的目录与 README 格式说明

## 使用方法

1. 克隆此仓库到本地
2. 找到需要的技能文件夹
3. 按照每个技能的说明文档使用相应的修复工具

## 添加新技能

1. 在仓库根目录创建新的文件夹，命名为技能名称
2. 在新文件夹中创建必要的文件，包括：
   - `SKILL.md` - 技能说明文档（必需）
   - 相关的脚本、工具或配置文件
3. 更新本README.md文件，添加新技能的说明

## 贡献

欢迎提交新的技能或改进现有技能！
