"""Render icon SVG sources using librsvg and Pillow; leave README artwork alone.

Run: python3 assets/src/render-icons.py
"""
from pathlib import Path
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parent


def render(source, output, size):
    subprocess.run([
        "rsvg-convert", "--width", str(size), "--height", str(size),
        str(ROOT / source), "--output", str(output),
    ], check=True)


render("icon-1024.svg", ROOT.parent / "icon-1024.png", 1024)
for size in (16, 32):
    with Image.open(ROOT.parent / "icon-1024.png") as icon:
        icon.resize((size, size), Image.Resampling.LANCZOS).save(
            ROOT / f"icon-preview-{size}.png")
for size, name in ((18, "menubar.png"), (36, "menubar@2x.png")):
    render("menubar.svg", ROOT.parent / name, size)

# Review the native-size assets on light and dark surfaces, plus nearest-neighbor
# enlargements that expose the actual small-size pixels without smoothing.
preview = Image.new("RGB", (640, 240), "#b8b8b8")
for column, (name, scale) in enumerate([
    (ROOT / "icon-preview-32.png", 4),
    (ROOT / "icon-preview-16.png", 8),
    (ROOT.parent / "menubar.png", 7),
    (ROOT.parent / "menubar@2x.png", 3),
]):
    with Image.open(name).convert("RGBA") as asset:
        x = column * 160
        preview.paste(asset, (x + (160-asset.width)//2, 24), asset)
        large = asset.resize((asset.width*scale, asset.height*scale), Image.Resampling.NEAREST)
        preview.paste(large, (x + (160-large.width)//2, 80), large)
preview.save(ROOT / "icon-preview-sheet.png")
