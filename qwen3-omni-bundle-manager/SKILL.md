---
name: qwen3-omni-bundle-manager
description: Safely quarantine unusable Qwen3-Omni model caches, create a usable deployment bundle, and verify the bundle contents. Use when the user wants to keep only the working GPTQ4 path, package the repository for transfer, or validate that the archive excludes failed model variants.
---

# Qwen3-Omni Bundle Manager

Use this skill when the user wants a safe cleanup-and-package workflow for this repository.

## Workflow

1. Resolve the project root.
   Prefer `QWEN_OMNI_PROJECT_ROOT=/path/to/Qwen3-Omni`.
2. Stop model and API services first.
3. Dry-run model quarantine.
4. Apply model quarantine.
5. Build the usable bundle.
6. Verify the bundle checksum and contents.

## Commands

Dry-run cleanup:

```bash
skills/qwen3-omni-bundle-manager/scripts/prune_and_bundle.sh --dry-run
```

Apply cleanup and build:

```bash
skills/qwen3-omni-bundle-manager/scripts/prune_and_bundle.sh --apply-prune
```

Verify archive:

```bash
skills/qwen3-omni-bundle-manager/scripts/prune_and_bundle.sh --verify dist/Qwen3-Omni-gptq4-usable-<timestamp>.tar.zst
```

## Safety rules

- `prune_model_cache.sh` is dry-run by default.
- Unusable models are moved to `var/trash/models/<timestamp>/`, not deleted immediately.
- `purge_quarantined_models.sh --apply` is the only permanent delete path.

## References

- Read `references/bundle-layout.md` for exactly what the bundle contains.
