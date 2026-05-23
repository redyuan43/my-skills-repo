#!/usr/bin/env python3
"""Set the Meshy MCP API key in ~/.codex/config.toml and enable the server."""

from __future__ import annotations

import argparse
import getpass
import re
from pathlib import Path


CONFIG = Path.home() / ".codex" / "config.toml"
BLOCK_RE = re.compile(r"(?ms)^\[mcp_servers\.meshy\]\n.*?(?=^\[|\Z)")


def build_block(api_key: str) -> str:
    return (
        "[mcp_servers.meshy]\n"
        'command = "/home/ivan/.local/bin/npx"\n'
        'args = ["-y", "@meshy-ai/meshy-mcp-server"]\n'
        "enabled = true\n"
        f'env = {{ MESHY_API_KEY = "{api_key}", MESHY_API_HOST = "https://api.meshy.ai" }}\n\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", help="Meshy API key. If omitted, prompts without echo.")
    args = parser.parse_args()

    api_key = args.key or getpass.getpass("Meshy API key: ").strip()
    if not api_key.startswith("msy_"):
        raise SystemExit("Meshy API key should start with 'msy_'.")

    text = CONFIG.read_text(encoding="utf-8")
    block = build_block(api_key)
    if BLOCK_RE.search(text):
        text = BLOCK_RE.sub(block, text)
    else:
        text = text.rstrip() + "\n\n" + block
    CONFIG.write_text(text, encoding="utf-8")
    print("Meshy MCP server enabled in ~/.codex/config.toml")
    print("Restart Codex or reload MCP config before using Meshy tools.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
