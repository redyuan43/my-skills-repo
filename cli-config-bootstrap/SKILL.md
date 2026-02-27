---
name: cli-config-bootstrap
description: Create portable, sanitized configuration templates for AI CLIs (Claude, Qwen, Kilo, OpenCode), including export/install workflows with placeholder-based secret redaction and environment variable injection.
---

# CLI Configuration Bootstrap Skill

The `cli-config-bootstrap` skill creates portable, sanitized configuration templates for multiple AI CLI tools (Claude, Qwen, Kilo, OpenCode). It allows users to generate de-identified configuration files that preserve settings, model configurations, and permissions while removing sensitive API keys and tokens. This enables easy setup of AI CLI environments on new machines and secure sharing of configurations without exposing credentials.

## Features

- **Multi-CLI Support**: Handles configurations for Claude, Qwen, Kilo, and OpenCode CLIs
- **Sanitization**: Replaces sensitive values with placeholders (e.g., `__ANTHROPIC_AUTH_TOKEN__`)
- **Template Management**: Maintains configuration templates in the assets directory
- **Environment Variable Injection**: Supports runtime replacement of placeholders with environment variables
- **Home Directory Normalization**: Replaces actual home paths with `__HOME__` placeholder

## Commands

### `/cli-config-bootstrap export`

Extracts current configurations from user directories, sanitizes sensitive fields, and creates new templates.

```bash
/cli-config-bootstrap export
```

### `/cli-config-bootstrap install`

Installs template configurations to user home directories, replacing placeholders with environment variables if provided.

```bash
/cli-config-bootstrap install
```

## Use Cases

- Set up new development environments with consistent CLI configurations
- Share configuration templates while protecting sensitive data
- Create backup configurations without API keys
- Migrate between machines while preserving settings
