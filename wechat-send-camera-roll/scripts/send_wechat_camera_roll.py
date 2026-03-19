#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import sys
import tempfile
import time
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="send_wechat_camera_roll")
    parser.add_argument("--chat", required=True, help="Standalone WeChat chat window title")
    parser.add_argument("--dir", type=Path, required=True, help="Directory containing camera photos")
    parser.add_argument(
        "--app-root",
        type=Path,
        default=Path(os.environ.get("WECHAT_AUTO_REPLY_ROOT", "/home/ivan/github/DevToolbox/wechat-auto-reply")),
        help="Path to the local wechat-auto-reply project",
    )
    parser.add_argument("--display", default=":0", help="X11 DISPLAY value")
    parser.add_argument(
        "--xauthority",
        default="/run/user/1000/gdm/Xauthority",
        help="XAUTHORITY value",
    )
    parser.add_argument(
        "--delay-seconds",
        type=float,
        default=1.0,
        help="Extra delay between files after each send completes",
    )
    parser.add_argument(
        "--start-after",
        help="Resume after this filename; files are sent in sorted order",
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Only send the first N resolved files",
    )
    parser.add_argument(
        "--print-only",
        action="store_true",
        help="Print the resolved files and command context without sending",
    )
    return parser


def resolve_files(root: Path, start_after: str | None, limit: int | None) -> list[Path]:
    if not root.is_dir():
        raise FileNotFoundError(f"Directory not found: {root}")
    allowed = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp"}
    files = sorted(path for path in root.iterdir() if path.is_file() and path.suffix.lower() in allowed)
    if start_after:
        passed = False
        filtered: list[Path] = []
        for path in files:
            if passed:
                filtered.append(path)
            elif path.name == start_after:
                passed = True
        files = filtered
    if limit is not None:
        files = files[: max(0, limit)]
    return files


def main() -> int:
    args = build_parser().parse_args()
    app_root = args.app_root.expanduser().resolve()
    if not app_root.is_dir():
        raise FileNotFoundError(f"wechat-auto-reply root not found: {app_root}")
    sys.path.insert(0, str(app_root))

    from wechat_auto_reply.config import (  # noqa: PLC0415
        AppConfig,
        AttachmentsConfig,
        GuardConfig,
        GuardContextConfig,
        GuardWhitelistConfig,
        OllamaConfig,
        SafetyConfig,
        ToolsConfig,
        ToolsSendFileConfig,
        WindowConfig,
    )
    from wechat_auto_reply.service import AutoReplyService  # noqa: PLC0415
    from wechat_auto_reply.state import StateStore  # noqa: PLC0415

    files = resolve_files(args.dir.expanduser().resolve(), args.start_after, args.limit)
    if not files:
        print("No matching image files resolved.", file=sys.stderr)
        return 1

    state_dir = Path(tempfile.mkdtemp(prefix="wechat-send-camera-roll-"))
    config = AppConfig(
        window=WindowConfig(
            display=args.display,
            xauthority=args.xauthority,
            monitor_mode="standalone",
            focus_allowed=True,
        ),
        guard=GuardConfig(
            whitelist=GuardWhitelistConfig(private_chats=[args.chat]),
            context=GuardContextConfig(strategy="current_screen"),
        ),
        ollama=OllamaConfig(base_url="http://127.0.0.1:11434", timeout_s=1),
        safety=SafetyConfig(dry_run=False),
        tools=ToolsConfig(
            send_file=ToolsSendFileConfig(
                enabled=True,
                attachments=AttachmentsConfig(
                    explicit_send_extensions=["jpg", "jpeg", "png", "heic", "heif", "webp"],
                    chooser_open_delay_ms=800,
                    post_send_delay_ms=1200,
                ),
            )
        ),
        state_dir=state_dir,
        config_dir=state_dir,
    )
    store = StateStore(config.state_dir, config.runtime_state_path, config.audit_log_path)
    service = AutoReplyService(config, store)

    print(f"chat={args.chat}")
    print(f"dir={args.dir.expanduser().resolve()}")
    print(f"total={len(files)}")
    if args.print_only:
        for index, image in enumerate(files, start=1):
            print(f"[{index}/{len(files)}] would_send {image}")
        print(f"app_root={app_root}")
        print(f"display={args.display}")
        print(f"xauthority={args.xauthority}")
        return 0

    for index, image in enumerate(files, start=1):
        service.send_file(args.chat, image)
        print(f"[{index}/{len(files)}] sent {image.name}", flush=True)
        time.sleep(max(0.0, args.delay_seconds))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
