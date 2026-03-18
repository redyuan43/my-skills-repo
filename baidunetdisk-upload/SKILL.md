---
name: baidunetdisk-upload
description: Upload local files to Baidu Netdisk through the installed Linux desktop client. Use when the user wants a file sent to Baidu Netdisk with minimal manual steps, gives an exact path or a rough filename, or needs the upload verified by reading the remote folder after enqueueing.
---

# Baidu Netdisk Upload

## Overview

Use `scripts/upload_to_baidunetdisk.py` for the stable workflow:

1. resolve local files from exact paths or rough names
2. stage them into a new local bundle directory
3. enqueue the bundle through the installed Linux Baidu Netdisk client
4. verify success by reading the remote folder back

Treat remote readability as the final success signal. `upload.db` history is useful, but some successful uploads still record non-zero `error_code`.

## When To Use

- 用户说“把这个文件传到百度网盘”
- 用户只给了一个大概文件名或目录关键词，希望你自己定位
- 用户希望尽量少交互，直接跑通上传
- 用户希望上传后还能读取远端目录，给出可人工审核的结果

## Workflow

1. Before any real upload, use the required dangerous-operation confirmation flow. Uploading to a real Netdisk account is a production network action.
2. Prefer the script over ad hoc shell glue.
3. If the user gives an exact path, pass it directly.
4. If the user gives a rough name, pass the rough query directly; the script reuses the existing harness path resolver.
5. Unless the user explicitly names a folder, let the script generate a timestamped remote folder under Netdisk root.
6. After upload, report the remote folder path and ask the user to inspect it manually when the action matters.

## Quick Use

Upload one exact file:

```bash
python3 "/home/ivan/.codex/skills/baidunetdisk-upload/scripts/upload_to_baidunetdisk.py" \
  "/home/ivan/Documents/report.pdf" \
  --confirm-live-upload
```

Upload by rough local name:

```bash
python3 "/home/ivan/.codex/skills/baidunetdisk-upload/scripts/upload_to_baidunetdisk.py" \
  "IMG_2024.HEIC" \
  --confirm-live-upload
```

Upload multiple files into a named root folder:

```bash
python3 "/home/ivan/.codex/skills/baidunetdisk-upload/scripts/upload_to_baidunetdisk.py" \
  "/home/ivan/Documents/a.pdf" \
  "/home/ivan/Pictures/photo.jpg" \
  --remote-folder "project-review-20260318" \
  --confirm-live-upload
```

Inspect without real upload:

```bash
python3 "/home/ivan/.codex/skills/baidunetdisk-upload/scripts/upload_to_baidunetdisk.py" \
  "photo" \
  --dry-run \
  --json
```

## Constraints

- This skill depends on the existing harness at `/home/ivan/github/CLI-Anything/baidunetdisk/agent-harness`.
- Current stable workflow uploads into a newly created root-level Netdisk folder. Do not promise nested remote placement unless the harness is extended first.
- If the local query resolves to multiple matches, stop and let the user pick. Do not guess.
- Verification should prefer remote folder listing over local queue state.

## Resources

- `scripts/upload_to_baidunetdisk.py`: resolve local targets, stage files, launch upload, and verify by remote listing
