---
name: linux-ntfs-offload-symlink
description: 将 Linux 主目录下的大型数据目录迁移到已挂载或待挂载的 NTFS 分区，并在原位置保留软链接。适用于“/home 空间满了”“想把模型/缓存/归档迁到另一块盘”“需要确保重启后自动挂载且软链接不失效”的场景。已在 AMD 395 工作站、Ubuntu、ZFS `/home` + NTFS 数据盘组合上验证。
---

# Linux NTFS Offload Symlink

## Quick Start

1. 识别可用分区与挂载点。

```bash
df -h
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
blkid
```

2. 挂载目标 NTFS 分区并验证可写。

```bash
sudo mkdir -p /mnt/data853
sudo mount -t ntfs3 -o uid=1000,gid=1000,umask=022 /dev/nvme0n1p4 /mnt/data853
touch /mnt/data853/.write-test && rm -f /mnt/data853/.write-test
```

3. 先复制，再切换软链接。

```bash
mkdir -p /mnt/data853/ivan-data/lmstudio/models
rsync -a --info=progress2 ~/.lmstudio/models/lmstudio-community /mnt/data853/ivan-data/lmstudio/models/
mv ~/.lmstudio/models/lmstudio-community ~/.lmstudio/models/lmstudio-community.bak
ln -s /mnt/data853/ivan-data/lmstudio/models/lmstudio-community ~/.lmstudio/models/lmstudio-community
ls ~/.lmstudio/models/lmstudio-community >/dev/null
rm -rf ~/.lmstudio/models/lmstudio-community.bak
```

4. 写入 `fstab` 并做重挂验证。

```bash
printf '\nUUID=685EC346A2AE3EFD /mnt/data853 ntfs3 defaults,uid=1000,gid=1000,umask=022 0 0\n' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
sudo umount /mnt/data853
sudo mount /mnt/data853
ls ~/.lmstudio/models/lmstudio-community >/dev/null
```

## Workflow

1. 优先找“数据盘”，不要先动系统盘。
- 先看 `df -h` 与 `lsblk`，确认哪个分区真正有余量。
- 如果是 Windows 共用盘，Linux 下优先使用 `ntfs3`。

2. 只迁移“大而稳定的数据目录”。
- 推荐：模型目录、下载缓存、归档、导出结果、备份目录。
- 例如：`~/.lmstudio/models` 的大子目录、`~/.cache/huggingface`、`~/models`、`~/chat_archive`。

3. 不要一上来迁整个复杂父目录。
- 优先迁移父目录下的单个大子目录，并分别做软链接。
- 这样回滚更简单，也更容易定位是哪一部分占空间。

4. 先复制，后切换，再删除备份。
- 使用 `rsync -a` 复制到目标盘。
- 保留源目录为 `.bak-<date>`，软链接切好并验证访问正常后再删除备份。

5. 自动挂载必须实测。
- 只写 `fstab` 不够；要执行：
  - `sudo systemctl daemon-reload`
  - `sudo mount -a`
  - `sudo umount <mountpoint>`
  - `sudo mount <mountpoint>`
- 最后再从原始软链接路径做一次 `ls` 或应用级访问验证。

## Recommended Layout

建议在目标盘上使用固定结构，避免散乱：

```text
/mnt/data853/ivan-data/
  lmstudio/models/
  huggingface/
  chat_archive/
  backups/
```

这样以后新增软链接时更清晰，也更容易排查。

## Good Candidates

- `~/.lmstudio/models/<large-subdir>`
- `~/.cache/huggingface`
- `~/models`
- `~/chat_archive`
- `~/backup_from_1TB`

## Avoid Moving First

- 整个 `~/.config`
- 整个 `~/.cache`
- 整个 `~/github`
- 活跃开发仓库
- 强依赖 Linux 权限、可执行位、符号链接语义的环境目录

## Validation Checklist

- `findmnt /mnt/data853`
- `grep data853 /etc/fstab`
- `sudo mount -a`
- `sudo umount /mnt/data853 && sudo mount /mnt/data853`
- `ls <original-path-through-symlink> >/dev/null`
- `df -h /home /mnt/data853`

## Field Note

已在以下组合上完成实测：

- 主机：AMD 395 工作站
- 系统：Ubuntu
- 源分区：ZFS `rpool/USERDATA/home_*` 挂载到 `/home`
- 目标分区：NTFS，使用 `ntfs3`
- 关键验证：写入 `fstab` 后执行 `daemon-reload`、`mount -a`、手动卸载再挂载，软链接路径仍可正常访问

## Safety Rules

- 不要在复制完成前删除原目录。
- 不要把自动挂载验证省略掉。
- 如果目标 NTFS 盘剩余空间不足，不要硬搬整个父目录，改为分批搬大子目录。
- 修改 `/etc/fstab` 前先备份。
- 如果仓库工作区是 dirty，只提交 skill 文件和 README 的预期变更。
