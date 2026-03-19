---
name: linux-wx-decrypt
description: Export and decrypt Linux WeChat local databases through the existing PyWxDump project. Use when the user wants to extract keys from a running Linux WeChat client, decrypt `db_storage`, or prepare local WeChat data for inspection, backup, or downstream analysis on the current machine.
---

# Linux Wx Decrypt

## Overview

Use this skill to run the existing PyWxDump Linux WeChat decryption flow on the current machine:

1. find `db_storage`
2. extract keys from the running WeChat process
3. decrypt databases into a local output directory

This skill is PyWxDump-specific and assumes the repo exists at `/home/ivan/github/PyWxDump`.

## Workflow

1. Confirm Linux WeChat is running and logged in.
2. If key extraction requires privileged kernel settings, ask for explicit confirmation before changing them.
3. Run `scripts/run_linux_wx_decrypt.sh`.
4. Inspect the generated key file and decrypted output directory.

## Quick Use

Run the full flow:

```bash
skills/linux-wx-decrypt/scripts/run_linux_wx_decrypt.sh
```

Use a custom decrypted output directory:

```bash
skills/linux-wx-decrypt/scripts/run_linux_wx_decrypt.sh \
  --output "/home/ivan/wx_decrypted"
```

Only extract keys:

```bash
skills/linux-wx-decrypt/scripts/run_linux_wx_decrypt.sh \
  --key-only
```

Only decrypt using an existing key file:

```bash
skills/linux-wx-decrypt/scripts/run_linux_wx_decrypt.sh \
  --decrypt-only \
  --key-file "/home/ivan/.wx_db_keys.json"
```

## Constraints

- This skill does not automatically change `kernel.yama.ptrace_scope`; if that is needed, ask before doing it.
- This skill assumes PyWxDump exists at `/home/ivan/github/PyWxDump`.
- This skill is for the current machine and the current logged-in WeChat client.

## Selftest

真实验收默认会：

1. 向 `新技术讨论` 发送开始回执
2. 执行提 key 与全量解密
3. 向 `新技术讨论` 发送完成回执

```bash
skills/linux-wx-decrypt/scripts/selftest.sh
```

只做无副作用检查：

```bash
skills/linux-wx-decrypt/scripts/selftest.sh --safe
```

## Resources

- `scripts/run_linux_wx_decrypt.sh`: wrap `linux_get_wx_key.py` and `linux_decrypt_wx_db.py`
- `scripts/selftest.sh`: real selftest for key extraction, decrypt flow, and visible WeChat receipts
