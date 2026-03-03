# Bundle Layout

The usable bundle contains:

- repository source files
- scripts
- configs
- tests
- skills
- vendor patch files
- sample assets
- the working GPTQ4 model cache

The bundle excludes:

- `.venv`
- `.vendor`
- logs
- PID files
- outputs
- failed model variants (`bf16`, `awq4`, `nvfp4`)

The cleanup step quarantines failed model variants before the bundle is created.
