#!/usr/bin/env python3
"""Prepare a clean-background image and preview page for Meshy image-to-3D."""

from __future__ import annotations

import argparse
import html
import json
import os
import shutil
import subprocess
import sys
import venv
from datetime import datetime
from pathlib import Path


CACHE_DIR = Path.home() / ".cache" / "codex-meshy-image-to-3d"
VENV_DIR = CACHE_DIR / "venv"
DEFAULT_ROOT = Path.home() / "Desktop" / "meshy-3d-previews"


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def ensure_rembg() -> None:
    try:
        import rembg  # noqa: F401
        import PIL  # noqa: F401
        return
    except Exception:
        pass

    if os.environ.get("MESHY_PREVIEW_BOOTSTRAPPED") == "1":
        raise RuntimeError("rembg is still unavailable after bootstrap")

    VENV_DIR.parent.mkdir(parents=True, exist_ok=True)
    py = VENV_DIR / "bin" / "python"

    if py.exists():
        check = subprocess.run(
            [str(py), "-c", "import rembg, PIL"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if check.returncode == 0:
            env = os.environ.copy()
            env["MESHY_PREVIEW_BOOTSTRAPPED"] = "1"
            result = subprocess.run([str(py), *sys.argv], env=env)
            raise SystemExit(result.returncode)

    if not py.exists():
        venv.EnvBuilder(with_pip=True).create(VENV_DIR)

    run([str(py), "-m", "pip", "install", "--upgrade", "pip"])
    run([str(py), "-m", "pip", "install", "rembg", "pillow", "onnxruntime"])

    env = os.environ.copy()
    env["MESHY_PREVIEW_BOOTSTRAPPED"] = "1"
    result = subprocess.run([str(py), *sys.argv], env=env)
    raise SystemExit(result.returncode)


def checkerboard(width: int, height: int, square: int = 24):
    from PIL import Image, ImageDraw

    img = Image.new("RGB", (width, height), "#ffffff")
    draw = ImageDraw.Draw(img)
    for y in range(0, height, square):
        for x in range(0, width, square):
            if (x // square + y // square) % 2:
                draw.rectangle((x, y, x + square - 1, y + square - 1), fill="#d8dde6")
    return img


def make_preview(source: Path, output_root: Path, open_preview: bool) -> dict[str, str]:
    if not source.exists():
        raise FileNotFoundError(f"Input image not found: {source}")
    if not source.is_file():
        raise ValueError(f"Input path is not a file: {source}")

    ensure_rembg()

    from PIL import Image
    from rembg import remove

    run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = output_root.expanduser().resolve() / run_id
    out_dir.mkdir(parents=True, exist_ok=True)

    original_copy = out_dir / f"original{source.suffix.lower() or '.png'}"
    shutil.copy2(source, original_copy)

    with Image.open(source) as im:
        im = im.convert("RGBA")
        clean = remove(im)

    clean_path = out_dir / "clean_transparent.png"
    white_path = out_dir / "clean_white.png"
    checker_path = out_dir / "clean_checkerboard.png"
    html_path = out_dir / "preview.html"

    clean.save(clean_path)

    white = Image.new("RGBA", clean.size, "WHITE")
    white.alpha_composite(clean)
    white.convert("RGB").save(white_path)

    board = checkerboard(*clean.size).convert("RGBA")
    board.alpha_composite(clean)
    board.convert("RGB").save(checker_path)

    html_path.write_text(
        build_html(source, original_copy, checker_path, white_path, clean_path),
        encoding="utf-8",
    )

    if open_preview:
        opener = shutil.which("xdg-open")
        if opener:
            subprocess.Popen([opener, str(html_path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    return {
        "run_id": run_id,
        "source": str(source),
        "output_dir": str(out_dir),
        "html": str(html_path),
        "clean_image": str(clean_path),
        "white_image": str(white_path),
        "checker_image": str(checker_path),
        "original_copy": str(original_copy),
    }


def rel(path: Path, base: Path) -> str:
    return html.escape(path.relative_to(base.parent).as_posix())


def build_html(source: Path, original_copy: Path, checker_path: Path, white_path: Path, clean_path: Path) -> str:
    title = "Meshy image-to-3D preview"
    clean = html.escape(str(clean_path))
    source_text = html.escape(str(source))
    original_rel = rel(original_copy, original_copy)
    checker_rel = rel(checker_path, checker_path)
    white_rel = rel(white_path, white_path)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <style>
    :root {{ color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }}
    body {{ margin: 0; background: #f4f6f8; color: #18202a; }}
    header {{ padding: 24px 28px 12px; }}
    h1 {{ margin: 0 0 8px; font-size: 24px; font-weight: 720; }}
    p {{ margin: 0; color: #53606f; }}
    main {{ display: grid; grid-template-columns: repeat(3, minmax(220px, 1fr)); gap: 16px; padding: 16px 28px 28px; }}
    section {{ background: white; border: 1px solid #dde3ea; border-radius: 8px; overflow: hidden; }}
    h2 {{ margin: 0; padding: 12px 14px; font-size: 14px; border-bottom: 1px solid #e7ebf0; }}
    .frame {{ height: 56vh; min-height: 360px; display: grid; place-items: center; background: #eef1f4; }}
    img {{ max-width: 100%; max-height: 100%; object-fit: contain; }}
    footer {{ margin: 0 28px 28px; padding: 14px 16px; background: #18202a; color: #eaf0f7; border-radius: 8px; overflow-wrap: anywhere; }}
    code {{ color: #aee8ff; }}
    @media (max-width: 900px) {{ main {{ grid-template-columns: 1fr; }} .frame {{ height: 42vh; }} }}
  </style>
</head>
<body>
  <header>
    <h1>Meshy image-to-3D preview</h1>
    <p>Confirm the cleaned image before spending Meshy credits.</p>
  </header>
  <main>
    <section><h2>Original</h2><div class="frame"><img src="{original_rel}" alt="Original image"></div></section>
    <section><h2>Cleaned on transparency</h2><div class="frame"><img src="{checker_rel}" alt="Cleaned image on checkerboard"></div></section>
    <section><h2>White background check</h2><div class="frame"><img src="{white_rel}" alt="Cleaned image on white"></div></section>
  </main>
  <footer>
    Source: <code>{source_text}</code><br>
    Send this file to Meshy after confirmation: <code>{clean}</code>
  </footer>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", help="Path to local input image")
    parser.add_argument("--output-root", default=str(DEFAULT_ROOT), help="Preview output root")
    parser.add_argument("--open", action="store_true", help="Open preview.html with xdg-open")
    args = parser.parse_args()

    try:
        result = make_preview(Path(args.image).expanduser().resolve(), Path(args.output_root), args.open)
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1

    print(json.dumps({"ok": True, **result}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
