---
name: gh-repo-maintenance
description: Audit and maintain GitHub repositories with `gh` CLI. Use when the user wants to check/fix GitHub CLI login, list repositories with metadata, classify cleanup candidates (test repos, stale repos, old forks), delete named repositories safely with confirmation, or "hide" repositories by changing visibility to private (including handling `gh` version differences and public fork visibility limitations). Also use when the user refers to this skill with common misspellings such as `gh-repo-maintenace`.
---

# Gh Repo Maintenance

## Overview

Check `gh` authentication and scopes before any repo mutations. Use `gh repo list --json` for reliable inventory and classification. Use GitHub API via `gh api PATCH ... private=true` as a fallback when `gh repo edit --visibility private` lacks newer confirmation flags or behaves inconsistently.

## Workflow

## 1. Verify `gh` login first

Run:

```bash
gh auth status
```

Handle outcomes:

- If token is invalid, ask the user to run `gh auth login -h github.com`.
- If deletion is requested and `delete_repo` scope is missing, ask the user to run:

```bash
gh auth refresh -h github.com -s delete_repo
```

Prefer re-checking `gh auth status` after refresh and confirm scopes include `delete_repo`.

## 2. List repositories with structured JSON

Use `gh repo list` with JSON fields instead of parsing text output:

```bash
gh repo list --limit 300 --json name,nameWithOwner,isPrivate,visibility,isFork,createdAt,updatedAt,pushedAt,description,url
```

Use this output to:

- Count `PUBLIC` / `PRIVATE`
- Count `FORK` / non-fork
- Identify stale repos (for example `updatedAt` older than 180/365 days)
- Flag likely test repos (`test`, `demo`, `tmp`, `local`, etc.)
- Build a user-confirmed delete candidate list (do not delete by heuristic without confirmation)

For cutoff-based visibility work (for example "2021 年以前"), interpret it explicitly as:

- `createdAt < YYYY-01-01T00:00:00Z`

State the exact cutoff date in the reply.

## 3. Delete repositories safely (named-only)

Use named deletion after explicit user confirmation:

```bash
gh repo delete owner/repo --yes
```

Best practices:

- Repeat the list back to the user before deleting.
- Batch is acceptable when the user provides explicit repo names.
- After deletion, verify with `gh repo view owner/repo` and confirm it no longer resolves.

For repeated cleanup of old forks, prefer the bundled batch-delete script in section 6 instead of hand-writing loops every time.

## 4. Hide repositories (make private)

Primary intent for "隐藏" is usually "change visibility to private".

Try:

```bash
gh repo edit owner/repo --visibility private
```

If local `gh` version lacks needed flags or the command is interactive/fragile, use API fallback:

```bash
gh api -X PATCH repos/owner/repo -F private=true --silent
```

Important limitations:

- Public forks often cannot be converted to private. GitHub may return `HTTP 422 Validation Failed`.
- Report these repos as "cannot hide due to GitHub fork visibility rules" instead of retrying repeatedly.
- A non-fork repo (for example a personal site repo) can often be changed successfully.

## 5. Use the bundled script for cutoff-based list/hide tasks

Use `scripts/repo_cutoff_visibility.py` to avoid rewriting the same logic:

```bash
python3 scripts/repo_cutoff_visibility.py --before 2021-01-01 --action list
python3 scripts/repo_cutoff_visibility.py --before 2021-01-01 --action hide --apply
```

Behavior:

- `list`: Print matching repos and summary
- `hide` without `--apply`: Dry run
- `hide --apply`: Call `gh api PATCH ... private=true` and report `PRIVATE_OK` / `PRIVATE_FAIL`

## 6. Use the bundled script for batch deleting old forks (with confirmation)

Use `scripts/repo_bulk_delete_forks.py` when the user asks to delete many old forks (for example "删所有老 fork（>2年）").

Examples:

```bash
python3 scripts/repo_bulk_delete_forks.py --created-before 2024-01-01
python3 scripts/repo_bulk_delete_forks.py --created-before 2024-01-01 --updated-before 2025-01-01
python3 scripts/repo_bulk_delete_forks.py --created-before 2024-01-01 --apply
```

Behavior:

- Default mode is dry-run (`WOULD_DELETE`)
- `--apply` performs `gh repo delete owner/repo --yes`
- Prints per-repo `DELETE_OK` / `DELETE_FAIL`
- Supports optional owner filtering and limits

Always show the candidate list to the user first, then wait for explicit confirmation before running `--apply`.

## Error Handling

- `error connecting to api.github.com`: Often sandbox/network restriction, not auth failure. Retry in a context with network access.
- `gh auth status` shows invalid token: Re-login or refresh auth.
- `HTTP 403 ... needs delete_repo scope`: Ask user to run `gh auth refresh -h github.com -s delete_repo`.
- `HTTP 422 Validation Failed` while setting private: Usually unsupported visibility change (commonly public forks).

## References

- Read `references/gh-github-repo-maintenance-notes.md` for common failure modes and response patterns.
