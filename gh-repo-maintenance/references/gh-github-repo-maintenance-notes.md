# GH Repo Maintenance Notes

## Common auth checks

- Run `gh auth status` before any mutation.
- If deletion fails with `403` and mentions `delete_repo`, refresh auth:
  - `gh auth refresh -h github.com -s delete_repo`

## Listing repos reliably

Prefer JSON output:

```bash
gh repo list --limit 300 --json name,nameWithOwner,isPrivate,visibility,isFork,createdAt,updatedAt,pushedAt,description,url
```

## Hiding repos (making private)

`gh repo edit owner/repo --visibility private` may fail or be version-sensitive on older `gh` versions.

Fallback:

```bash
gh api -X PATCH repos/owner/repo -F private=true --silent
```

## Expected failure: public forks to private

GitHub commonly rejects public fork -> private visibility changes with:

- `Validation Failed (HTTP 422)`

Treat this as a product/platform limitation, not a retryable transport error.

## Batch deleting old forks

Preferred pattern:

1. Produce a dry-run candidate list filtered by `createdAt` (and optionally `updatedAt`)
2. Show the exact repo names to the user
3. Only run deletion with explicit confirmation (`--apply`)
4. Verify a sample or all repos with `gh repo view` if requested

Use the bundled script:

```bash
python3 scripts/repo_bulk_delete_forks.py --created-before 2024-01-01
python3 scripts/repo_bulk_delete_forks.py --created-before 2024-01-01 --apply
```

## User-facing wording pattern

- Say what was attempted.
- List successes and failures separately.
- Include exact cutoff dates for time-based rules (example: `createdAt < 2021-01-01T00:00:00Z`).
- For failures, explain whether it is auth (`403`), network/sandbox, or GitHub policy (`422`).
