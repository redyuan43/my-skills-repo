# my-skills-repo Format Notes

## Observed layout (current)

- Repository root contains one directory per skill
- Each skill directory contains `SKILL.md` and any needed files/subdirectories
- `README.md` maintains a human-written list of skills

Example top-level entries:

- `windows-network-share-fix/`
- `gh-repo-maintenance/`

## README style (current)

`README.md` uses Chinese sections and enumerated skill entries:

- `### 1. <skill-name>`
- `**功能：** ...`
- `**用途：** ...`
- `**文件：**`
- bullet list of files

## Publishing conventions for this repo

- Keep the skill as a top-level folder named after the skill
- Include `SKILL.md` (required)
- Include supporting scripts/references/assets only if useful to users
- Keep `README.md` updated with a new entry
- Commit and push on `main` unless the repo workflow changes
