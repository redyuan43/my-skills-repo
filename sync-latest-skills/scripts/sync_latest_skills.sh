#!/usr/bin/env bash
set -euo pipefail

REPO="${HOME}/github/my-skills-repo"
SKILL_ROOT="${HOME}/github/ivan-SuperAI/.codex/skills"
DO_PULL=1
PULL_MODE="ff-only"
FORCE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  sync_latest_skills.sh [--repo PATH] [--skill-root PATH] [--dry-run] [--force] [--no-pull] [--rebase]

Defaults:
  --repo       ${HOME}/github/my-skills-repo
  --skill-root ${HOME}/github/ivan-SuperAI/.codex/skills

Behavior:
  - Pull the repo with `git pull --ff-only` by default
  - Use `--rebase` to pull with `git pull --rebase --autostash`
  - Sync top-level skill directories into the selected skill root as symlinks
  - Skip non-skill files such as README.md
  - Refuse to overwrite existing directories unless --force is set
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || die "--repo requires a path"
      REPO="$2"
      shift 2
      ;;
    --skill-root)
      [[ $# -ge 2 ]] || die "--skill-root requires a path"
      SKILL_ROOT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --no-pull)
      DO_PULL=0
      shift
      ;;
    --rebase)
      PULL_MODE="rebase"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

REPO="$(cd "$REPO" && pwd -P)"
mkdir -p "$SKILL_ROOT"
SKILL_ROOT="$(cd "$SKILL_ROOT" && pwd -P)"

[[ -d "$REPO/.git" ]] || die "not a git repo: $REPO"

if (( DO_PULL )); then
  log "PULL $REPO"
  if [[ "$PULL_MODE" == "rebase" ]]; then
    git -C "$REPO" pull --rebase --autostash
  else
    git -C "$REPO" pull --ff-only
  fi
fi

mapfile -t skill_dirs < <(
  find "$REPO" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.git' \
    ! -name '.codex' \
    ! -name '.serena' \
    | sort
)

if ((${#skill_dirs[@]} == 0)); then
  die "no skill directories found in $REPO"
fi

synced=0
skipped=0

for src in "${skill_dirs[@]}"; do
  [[ -f "$src/SKILL.md" ]] || continue

  name="$(basename "$src")"
  dst="$SKILL_ROOT/$name"

  if [[ -L "$dst" ]]; then
    current_target="$(readlink "$dst")"
    if [[ "$current_target" == "$src" ]]; then
      log "OK  $name (already linked)"
      continue
    fi
    if (( DRY_RUN )); then
      log "DRY-RUN replace symlink: $dst -> $src"
      synced=$((synced + 1))
      continue
    fi
    if (( FORCE )); then
      rm -f "$dst"
      ln -s "$src" "$dst"
      log "LINK $name"
      synced=$((synced + 1))
      continue
    fi
    warn "skip existing symlink with different target: $dst -> $current_target"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ -e "$dst" ]]; then
    if (( FORCE )); then
      if (( DRY_RUN )); then
        log "DRY-RUN replace existing path: $dst"
        synced=$((synced + 1))
        continue
      fi
      rm -rf "$dst"
      ln -s "$src" "$dst"
      log "LINK $name"
      synced=$((synced + 1))
      continue
    fi

    warn "skip existing path (use --force to replace): $dst"
    skipped=$((skipped + 1))
    continue
  fi

  if (( DRY_RUN )); then
    log "DRY-RUN link: $dst -> $src"
    synced=$((synced + 1))
    continue
  fi

  ln -s "$src" "$dst"
  log "LINK $name"
  synced=$((synced + 1))
done

log "SUMMARY synced=$synced skipped=$skipped root=$SKILL_ROOT"
