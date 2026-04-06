---
name: publish-skill-to-my-skills-repo
description: Publish a local Codex skill into the user's GitHub skills repository (specifically `my-skills-repo`) using that repository's folder layout and README style. Use when the user asks to add/upload/sync a newly created skill to the cloud GitHub repo, preserve the repo's existing format, generate a README entry, and commit/push the changes.
---

# Publish Skill To My Skills Repo

## Overview

Publish a local skill folder into `my-skills-repo` while preserving that repo's simple format: one top-level folder per skill, `SKILL.md` required, optional `scripts/`, `references/`, and other files, plus a README list entry.

## Workflow

## 1. Confirm the target repo and local clone

Check whether `my-skills-repo` is already cloned locally (for example `~/github/my-skills-repo`).

If not cloned, clone:

```bash
git clone https://github.com/<owner>/my-skills-repo /path/to/my-skills-repo
```

Inspect the repo format before copying:

- Skills live as top-level directories in the repo root
- `README.md` contains a manually maintained skill list
- Existing format is simple (not the full `.codex/skills` internal layout)

Read `references/my-skills-repo-format.md` for the observed structure and conventions.

## 2. Prepare the source skill folder

Confirm the source skill path (usually under `~/.codex/skills/<skill-name>`).

Copy only the files needed by the public repo format:

- Include: `SKILL.md`, `scripts/`, `references/`, `assets/` (if present), other skill runtime files
- Usually skip: `.git`, caches, local temp files
- Usually skip `agents/openai.yaml` unless the target repo also wants UI metadata

Use the bundled script to copy and generate a README entry template:

```bash
python3 scripts/import_skill_to_my_skills_repo.py \
  --source "$HOME/.codex/skills/gh-repo-maintenance" \
  --target-repo "$HOME/github/my-skills-repo"
```

Default behavior:

- Dry-run disabled (it copies files), but it does not commit/push
- Skips `agents/` by default to match the current `my-skills-repo` style
- Prints a README block template based on copied files

## 3. Update `README.md` in the target repo

Add a new skill entry under `## 技能列表` following the existing style in `my-skills-repo/README.md`.

Recommended structure:

- `### N. <skill-name>`
- `功能：...`
- `用途：...`
- `文件：`
- file bullet list

The script prints a template block for fast copy/paste.

## 4. Review and commit

Check the target repo changes before committing:

```bash
git -C /path/to/my-skills-repo status --short
```

Commit and push:

```bash
git -C /path/to/my-skills-repo add README.md <skill-folder>
git -C /path/to/my-skills-repo commit -m "Add <skill-name> skill"
git -C /path/to/my-skills-repo push origin main
```

## Safety Rules

- Do not overwrite an existing skill folder without explicit user confirmation.
- Show the exact target path and copied files before destructive overwrite steps.
- If the target repo has local uncommitted changes, review them before modifying.
- Keep README numbering and formatting consistent with the existing file.

## References

- Read `references/my-skills-repo-format.md` for the target repo layout and README style.
