#!/usr/bin/env python3
"""Push a dedicated SSH identity and config into a-Shell's Documents container."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


DEFAULT_BUNDLE_ID = "AsheKube.app.a-Shell"
REMOTE_DIR = "/Documents/.ssh"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Push a dedicated SSH key and config into a-Shell over USB."
    )
    parser.add_argument("--udid", required=True, help="Trusted iPad UDID.")
    parser.add_argument(
        "--identity",
        type=Path,
        required=True,
        help="Local Ed25519 private-key path.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        required=True,
        help="Local OpenSSH config path.",
    )
    parser.add_argument(
        "--public-key",
        type=Path,
        help="Public-key path. Defaults to <identity>.pub.",
    )
    parser.add_argument(
        "--bundle-id",
        default=DEFAULT_BUNDLE_ID,
        help=f"a-Shell bundle ID (default: {DEFAULT_BUNDLE_ID}).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace existing a-Shell .ssh files.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Perform the mobile-device write. Without this, only validate inputs.",
    )
    return parser.parse_args()


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise SystemExit(f"{label} is not a readable file: {path}")


def main() -> int:
    args = parse_args()
    public_key = args.public_key or Path(f"{args.identity}.pub")
    require_file(args.identity, "Identity")
    require_file(public_key, "Public key")
    require_file(args.config, "SSH config")

    names = ("id_ed25519", "id_ed25519.pub", "config")
    print(f"Target bundle: {args.bundle_id}")
    print(f"Target directory: {REMOTE_DIR}")
    print("Files: " + ", ".join(names))

    if not args.apply:
        print("Dry run only. Re-run with --apply after confirming the target.")
        return 0

    try:
        from pymobiledevice3.lockdown import create_using_usbmux
        from pymobiledevice3.services.house_arrest import HouseArrestService
    except ImportError as exc:
        raise SystemExit(
            "pymobiledevice3 is required on the USB-connected macOS host."
        ) from exc

    lockdown = create_using_usbmux(serial=args.udid)
    service = HouseArrestService(
        lockdown, args.bundle_id, documents_only=True
    )

    try:
        service.makedirs(REMOTE_DIR)
    except Exception as exc:
        if "OBJECT_EXISTS" not in str(exc):
            raise

    existing = set(service.listdir(REMOTE_DIR))
    conflicts = set(names) & existing
    if conflicts and not args.force:
        joined = ", ".join(sorted(conflicts))
        raise SystemExit(
            f"Refusing to overwrite existing a-Shell files: {joined}. "
            "Inspect them first, then use --force if replacement is intended."
        )

    sources = {
        "id_ed25519": args.identity,
        "id_ed25519.pub": public_key,
        "config": args.config,
    }
    for remote_name, source in sources.items():
        service.set_file_contents(
            f"{REMOTE_DIR}/{remote_name}", source.read_bytes()
        )

    print("Wrote a-Shell SSH files. Run a-Shell chmod commands before SSH use.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
