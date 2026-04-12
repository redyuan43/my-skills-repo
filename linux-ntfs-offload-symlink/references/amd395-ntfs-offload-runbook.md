# AMD 395 NTFS Offload Runbook

## Context

- Host: AMD 395 workstation
- OS: Ubuntu
- `/home`: ZFS dataset on `rpool/USERDATA/home_*`
- Target data disk: NTFS
- Linux driver: `ntfs3`

## Why this pattern

When `/home` is on ZFS and a separate large NTFS data disk exists, the safest quick recovery is often:

1. Move large model/cache/archive directories to the NTFS disk.
2. Keep the original paths as symlinks.
3. Enforce persistent mounting through `/etc/fstab`.
4. Prove it by unmounting and remounting before declaring success.

## Validated commands

Mount:

```bash
sudo mkdir -p /mnt/data853
sudo mount -t ntfs3 -o uid=1000,gid=1000,umask=022 /dev/nvme0n1p4 /mnt/data853
```

Persist:

```fstab
UUID=685EC346A2AE3EFD /mnt/data853 ntfs3 defaults,uid=1000,gid=1000,umask=022 0 0
```

Reload and verify:

```bash
sudo systemctl daemon-reload
sudo mount -a
sudo umount /mnt/data853
sudo mount /mnt/data853
findmnt /mnt/data853
```

Symlink verification:

```bash
ls ~/.lmstudio/models/lmstudio-community >/dev/null
ls ~/.lmstudio/models/unsloth >/dev/null
ls ~/.lmstudio/models/noctrex >/dev/null
```

## Practical lessons

- Prefer moving the largest subdirectories under a model root instead of moving the whole root at once.
- `ntfs3` with `uid=1000,gid=1000,umask=022` is a good default for user-owned data access.
- `mount -a` alone is not enough confidence; manual `umount` + `mount` catches more setup mistakes.
- If the target disk is already close to full, recover space on `/home` first by moving only the highest-yield subdirectories.
