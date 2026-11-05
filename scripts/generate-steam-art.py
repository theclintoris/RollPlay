"""Generate Steam library art for RollPlay.

Dev-only helper. Requires Pillow, fonttools and brotli:
    python -m pip install pillow fonttools brotli

Outputs 600x900 portrait art, 1920x620 hero art, a transparent 1280x720 logo,
and a 600x900 legacy grid image under steam-art/.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "assets" / "fonts"
OUT_DIR = ROOT / "steam-art"
BRAND_DIR = ROOT / "assets" / "branding"
WORK_DIR = ROOT / ".userdata" / "artfonts"

INK = (10, 11, 10, 255)
INK_2 = (17, 20, 17, 255)
CREAM = (242, 234, 215, 255)
LIME = (216, 255, 78, 255)
CORAL = (255, 143, 116, 255)
MUTED = (154, 161, 148, 255)
LINE = (43, 48, 42, 255)
BLACK = (8, 9, 8, 255)

S = 2


def static_font(source: str, target: str, axes: dict | None = None) -> Path:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    out = WORK_DIR / target
    if out.exists():
        return out
    font = TTFont(FONT_DIR / source)
    if axes and "fvar" in font:
        font = instantiateVariableFont(font, axes, inplace=False, updateFontNames=True)
    font.flavor = None
    font.save(out)
    return out


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size * S)


def rgba(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def star(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, color, points: int = 8):
    coords = []
    for i in range(points * 2):
        angle = -math.pi / 2 + i * math.pi / points
        r = radius if i % 2 == 0 else radius * 0.34
        coords.append((cx * S + math.cos(angle) * r * S, cy * S + math.sin(angle) * r * S))
    draw.polygon(coords, fill=color)


def d20(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, color, width: float = 2.5):
    """Faceted twenty-sided die mark, drawn as flat geometry."""
    def point(r: float, angle_deg: float):
        angle = math.radians(angle_deg)
        return (cx + math.cos(angle) * r, cy + math.sin(angle) * r)

    outer = [point(radius, angle) for angle in (-90, -30, 30, 90, 150, 210)]
    draw.line(
        [(x * S, y * S) for x, y in outer + [outer[0]]],
        fill=color,
        width=max(1, round(width * S)),
        joint="curve",
    )
    tri_center = (cx, cy - radius * 0.05)
    tri = [
        (tri_center[0] + math.cos(math.radians(angle)) * radius * 0.61,
         tri_center[1] + math.sin(math.radians(angle)) * radius * 0.61)
        for angle in (90, 210, 330)
    ]
    tri_width = max(1, round(width * 0.86 * S))
    draw.line([(x * S, y * S) for x, y in tri + [tri[0]]], fill=color, width=tri_width, joint="curve")
    for start, end in ((tri[0], outer[3]), (tri[1], outer[5]), (tri[2], outer[1])):
        draw.line([(start[0] * S, start[1] * S), (end[0] * S, end[1] * S)], fill=color, width=tri_width)


def d20_badge(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, color, font, number_color):
    """Icon-scale d20: clean hexagon with a readable natural 20."""
    def point(r: float, angle_deg: float):
        angle = math.radians(angle_deg)
        return (cx + math.cos(angle) * r, cy + math.sin(angle) * r)

    outer = [point(radius, angle) for angle in (-90, -30, 30, 90, 150, 210)]
    draw.line(
        [(x * S, y * S) for x, y in outer + [outer[0]]],
        fill=color,
        width=max(1, round(radius * 0.12 * S)),
        joint="curve",
    )
    draw.text((cx * S, (cy + radius * 0.03) * S), "20", font=font, fill=number_color, anchor="mm")


def tracked_text(draw: ImageDraw.ImageDraw, x: float, y: float, text: str, font, fill, tracking: float = 0, anchor: str = "ls"):
    if tracking == 0:
        draw.text((x * S, y * S), text, font=font, fill=fill, anchor=anchor)
        return
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * S * (len(text) - 1)
    start = x * S
    if anchor.startswith("m"):
        start -= total / 2
    elif anchor.endswith("r"):
        start -= total
    for ch, width in zip(text, widths):
        draw.text((start, y * S), ch, font=font, fill=fill, anchor="ls")
        start += width + tracking * S


def text_width(draw: ImageDraw.ImageDraw, text: str, font, tracking: float = 0) -> float:
    if not tracking:
        return draw.textlength(text, font=font) / S
    return (sum(draw.textlength(ch, font=font) for ch in text) + tracking * S * (len(text) - 1)) / S


def background(w: int, h: int, seed: int = 7, grid: bool = True) -> Image.Image:
    img = Image.new("RGBA", (w * S, h * S), INK)
    bloom = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bloom, "RGBA")
    for cx, cy, rx, ry, color, alpha in [
        (w * 0.03, h * 0.06, w * 0.42, h * 0.72, LIME, 27),
        (w * 0.72, h * 0.12, w * 0.34, h * 0.60, CORAL, 16),
        (w * 0.95, h * 0.88, w * 0.40, h * 0.55, (88, 128, 190, 255), 14),
    ]:
        bd.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=(*color[:3], alpha))
    bloom = bloom.filter(ImageFilter.GaussianBlur(70 * S))
    img = Image.alpha_composite(img, bloom)

    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay, "RGBA")
    if grid:
        step = 64
        for x in range(0, w + 1, step):
            d.line([(x * S, 0), (x * S, h * S)], fill=(*CREAM[:3], 6), width=S)
        for y in range(0, h + 1, step):
            d.line([(0, y * S), (w * S, y * S)], fill=(*CREAM[:3], 6), width=S)

    # Oversized drafting arcs, as in the app backdrop.
    for radius, alpha in [(w * 0.34, 22), (w * 0.47, 15), (w * 0.61, 10)]:
        d.arc(
            [(w * 0.60 - radius) * S, (h * 0.53 - radius) * S, (w * 0.60 + radius) * S, (h * 0.53 + radius) * S],
            start=198,
            end=348,
            fill=(*CREAM[:3], alpha),
            width=S,
        )

    rng = random.Random(seed)
    for _ in range(int(w * h / 4200)):
        x, y = rng.uniform(8, w - 8), rng.uniform(8, h - 8)
        if rng.random() < 0.7:
            d.ellipse([x * S, y * S, (x + 1.5) * S, (y + 1.5) * S], fill=(*CREAM[:3], rng.randint(8, 24)))
        else:
            size = rng.uniform(2, 5)
            d.line([(x * S - size * S, y * S), (x * S + size * S, y * S)], fill=(*CREAM[:3], 18), width=S)
            d.line([(x * S, y * S - size * S), (x * S, y * S + size * S)], fill=(*CREAM[:3], 18), width=S)
    return Image.alpha_composite(img, overlay)


def rounded_panel(img: Image.Image, box, radius: int, fill, outline=None, width: int = 1):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    d.rounded_rectangle(
        [box[0] * S, box[1] * S, box[2] * S, box[3] * S],
        radius=radius * S,
        fill=fill,
        outline=outline,
        width=width * S,
    )
    return Image.alpha_composite(img, layer)


def mystery_card(w: int, h: int, serif, display, body, scale: float = 1.0) -> Image.Image:
    pad = 24
    cw, ch = int(280 * scale), int(420 * scale)
    card = Image.new("RGBA", (cw * S + pad * S * 2, ch * S + pad * S * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(card, "RGBA")
    x, y = pad * S, pad * S

    # Soft shadow.
    d.rounded_rectangle([x + 12 * S, y + 16 * S, x + cw * S + 12 * S, y + ch * S + 16 * S], radius=16 * S, fill=(0, 0, 0, 145))
    d.rounded_rectangle([x, y, x + cw * S, y + ch * S], radius=16 * S, fill=LIME)

    # Inner keyline.
    inset = 10 * scale
    d.rounded_rectangle(
        [x + inset * S, y + inset * S, x + (cw - inset) * S, y + (ch - inset) * S],
        radius=11 * S,
        outline=(10, 11, 10, 60),
        width=S,
    )

    tracked_text(d, x / S + 22 * scale, y / S + 42 * scale, "ROLL TO REVEAL", load_font(body, int(9 * scale)), (10, 11, 10, 255), 2.2, "ls")
    qfont = load_font(display, int(230 * scale))
    draw = ImageDraw.Draw(card)
    center_x = x / S + cw / 2
    draw.text((center_x * S, (y / S + ch * 0.49) * S), "?", font=qfont, fill=(10, 11, 10, 255), anchor="mm")
    d20(draw, center_x, y / S + ch * 0.70, 17 * scale, (10, 11, 10, 255), 2.2 * scale)
    tracked_text(draw, center_x, y / S + ch * 0.86, "YOUR NEXT GAME", load_font(body, int(9 * scale)), (10, 11, 10, 255), 1.8, "ms")
    return card


def paste_rotated(base: Image.Image, item: Image.Image, cx: float, cy: float, angle: float):
    rotated = item.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    x = int(cx * S - rotated.width / 2)
    y = int(cy * S - rotated.height / 2)
    base.alpha_composite(rotated, (x, y))


def make_hero(bricolage, dm, serif) -> None:
    # Steam crops this art to an ultra-wide banner. Keep all meaningful content
    # inside the middle band, and leave the lower-left clear for Steam's logo.
    w, h = 1920, 620
    img = background(w, h, seed=11)
    draw = ImageDraw.Draw(img, "RGBA")

    # A quiet deck edge behind the hero card adds depth without competing with
    # the logo overlay.
    for offset_x, offset_y, angle, alpha in [(-118, 9, -13.0, 90), (-60, 4, -10.0, 150)]:
        layer = Image.new("RGBA", (360 * S, 520 * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer, "RGBA")
        d.rounded_rectangle(
            [1 * S, 1 * S, 358 * S, 518 * S],
            radius=16 * S,
            fill=(18, 23, 18, alpha),
            outline=(*CREAM[:3], min(70, alpha + 25)),
            width=S,
        )
        paste_rotated(img, layer, 1600 + offset_x, 320 + offset_y, angle)

    card = mystery_card(w, h, serif, bricolage, dm, 1.45)
    paste_rotated(img, card, 1600, 320, -7.5)

    img.resize((w, h), Image.Resampling.LANCZOS).convert("RGB").save(OUT_DIR / "rollplay-hero.png", optimize=True)


def make_portrait(bricolage, dm, serif) -> None:
    w, h = 600, 900
    img = background(w, h, seed=23)
    draw = ImageDraw.Draw(img, "RGBA")

    draw.rectangle([(24 * S, 24 * S), ((w - 24) * S, (h - 24) * S)], outline=(*CREAM[:3], 34), width=S)
    d20(draw, 57, 62, 19, LIME, 2.7)
    tracked_text(draw, 84, 74, "ROLLPLAY", load_font(bricolage, 27), CREAM, 2.0)
    tracked_text(draw, 84, 94, "STEAM LIBRARY ROULETTE", load_font(dm, 8), MUTED, 1.6)

    tracked_text(draw, 46, 160, "A SMALL RITUAL FOR A BIG BACKLOG", load_font(dm, 9), (184, 193, 175, 255), 1.9)
    draw.text((43 * S, 238 * S), "Your", font=load_font(bricolage, 67), fill=CREAM, anchor="ls")
    draw.text((43 * S, 305 * S), "library.", font=load_font(bricolage, 72), fill=CREAM, anchor="ls")
    draw.text((45 * S, 405 * S), "one roll.", font=load_font(serif, 103), fill=LIME, anchor="ls")
    draw.line([(47 * S, 440 * S), (228 * S, 440 * S)], fill=(*CREAM[:3], 60), width=S)

    card = mystery_card(w, h, serif, bricolage, dm, 0.82)
    paste_rotated(img, card, 312, 657, 6.5)

    png = img.resize((w, h), Image.Resampling.LANCZOS)
    png.save(OUT_DIR / "rollplay-portrait.png", optimize=True)
    png.save(OUT_DIR / "rollplay-grid.png", optimize=True)


def make_logo(bricolage, dm) -> None:
    # Large, simple wordmark. Steam renders this over the hero at a small size,
    # so avoid the old tagline and excess padding.
    w, h = 1280, 720
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")

    word = "ROLLPLAY"
    tracking = 4.0
    max_word_width = 960
    size = 230
    while size > 110:
        word_font = load_font(bricolage, size)
        if text_width(draw, word, word_font, tracking) <= max_word_width:
            break
        size -= 5
    word_w = text_width(draw, word, word_font, tracking)
    die_r = 45
    gap = 42
    total_w = die_r * 2 + gap + word_w
    start_x = (w - total_w) / 2
    d20(draw, start_x + die_r, 365, die_r, LIME, 5.5)
    tracked_text(draw, start_x + die_r * 2 + gap, 443, word, word_font, CREAM, tracking)

    img.resize((w, h), Image.Resampling.LANCZOS).save(OUT_DIR / "rollplay-logo.png", optimize=True)


def make_icon(bricolage) -> None:
    size = 512
    img = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([0, 0, size * S, size * S], radius=112 * S, fill=INK)
    d.rounded_rectangle(
        [18 * S, 18 * S, (size - 18) * S, (size - 18) * S],
        radius=96 * S,
        outline=LINE,
        width=2 * S,
    )
    number_font = load_font(bricolage, 150)
    d20_badge(d, 256, 260, 158, LIME, number_font, CREAM)
    d.ellipse([(392 - 15) * S, (116 - 15) * S, (392 + 15) * S, (116 + 15) * S], fill=CORAL)
    base = img.resize((size, size), Image.Resampling.LANCZOS)

    BRAND_DIR.mkdir(parents=True, exist_ok=True)
    for px in (512, 256, 128, 64, 48, 32, 16):
        base.resize((px, px), Image.Resampling.LANCZOS).save(
            BRAND_DIR / f"icon-{px}.png", optimize=True
        )
    base.save(
        BRAND_DIR / "icon.ico",
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    base.resize((256, 256), Image.Resampling.LANCZOS).save(OUT_DIR / "rollplay-icon.png", optimize=True)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bricolage = static_font("bricolage-grotesque-latin.woff2", "Bricolage-800.ttf", {"opsz": 96, "wght": 800})
    dm = static_font("dm-sans-latin.woff2", "DMSans-500.ttf", {"opsz": 9, "wght": 500})
    serif = static_font("instrument-serif-italic-latin.woff2", "InstrumentSerif-Italic.ttf")

    # The 1920x620 collage hero has its own generator (generate-collage-hero.py).
    make_portrait(bricolage, dm, serif)
    make_logo(bricolage, dm)
    make_icon(bricolage)
    for path in sorted(OUT_DIR.glob("*.png")):
        with Image.open(path) as im:
            print(f"{path.name}: {im.size[0]}x{im.size[1]} {path.stat().st_size // 1024} KiB")


if __name__ == "__main__":
    main()
