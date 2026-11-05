"""Generate a crop-safe Steam library hero from installed game headers.

Dev-only helper. Downloads header art once into steam-art/collage/, builds a
five-by-three mosaic, darkens the left side, and places the RollPlay wordmark
in the safe centre band. The result is 1920x620, sized for Steam's library
hero and its much wider in-client crop.

    python scripts/generate-collage-hero.py
"""

from __future__ import annotations

import math
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "steam-art"
COVER_DIR = OUT_DIR / "collage"
FONT_DIR = ROOT / ".userdata" / "artfonts"

INK = (10, 11, 10, 255)
CREAM = (242, 234, 215, 255)
LIME = (216, 255, 78, 255)
MUTED = (154, 161, 148, 255)
S = 2

# A spread of genres and palettes from the local library. Headers only.
GAMES = [
    ("Balatro", 2379780),
    ("The Witcher 3", 292030),
    ("Cairn", 1588550),
    ("Slay the Spire", 646570),
    ("Rain World", 312520),
    ("Tainted Grail", 1466060),
    ("The Talos Principle", 257510),
    ("Return of the Obra Dinn", 653530),
    ("What Remains of Edith Finch", 501300),
    ("Detroit: Become Human", 1222140),
    ("Age of Empires II", 813780),
    ("Battle Brothers", 365360),
    ("Amber Isle", 1663040),
    ("The Stanley Parable", 1703340),
    ("Dota 2", 570),
]


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size * S)


def tracked_text(draw, x: float, y: float, text: str, fnt, fill, tracking: float = 0, stroke: int = 0):
    if not tracking:
        draw.text(
            (x * S, y * S),
            text,
            font=fnt,
            fill=fill,
            anchor="ls",
            stroke_width=stroke * S,
            stroke_fill=(0, 0, 0, 175),
        )
        return
    start = x * S
    for char in text:
        draw.text(
            (start, y * S),
            char,
            font=fnt,
            fill=fill,
            anchor="ls",
            stroke_width=stroke * S,
            stroke_fill=(0, 0, 0, 175),
        )
        start += draw.textlength(char, font=fnt) + tracking * S


def text_width(draw, text: str, fnt, tracking: float = 0) -> float:
    if not tracking:
        return draw.textlength(text, font=fnt) / S
    return (
        sum(draw.textlength(char, font=fnt) for char in text)
        + tracking * S * (len(text) - 1)
    ) / S


def d20(draw, cx: float, cy: float, radius: float, color, width: float = 4.5):
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


def fetch_headers() -> None:
    COVER_DIR.mkdir(parents=True, exist_ok=True)
    for name, appid in GAMES:
        target = COVER_DIR / f"{appid}.jpg"
        if target.exists() and target.stat().st_size > 5000:
            continue
        url = f"https://cdn.akamai.steamstatic.com/steam/apps/{appid}/header.jpg"
        print(f"fetching {name}...")
        request = urllib.request.Request(url, headers={"User-Agent": "RollPlay-art/0.1"})
        with urllib.request.urlopen(request, timeout=30) as response:
            target.write_bytes(response.read())


def cover_crop(image: Image.Image, width: int, height: int) -> Image.Image:
    image = image.convert("RGB")
    scale = max(width / image.width, height / image.height)
    image = image.resize(
        (max(width, round(image.width * scale)), max(height, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = (image.width - width) // 2
    top = (image.height - height) // 2
    return image.crop((left, top, left + width, top + height))


def make_gradient(width: int, height: int) -> Image.Image:
    layer = Image.new("RGBA", (width * S, height * S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    for x in range(width):
        # Enough shade at the wordmark for contrast, but keep the covers legible.
        t = min(1.0, x / 1420)
        eased = t * t * (3 - 2 * t)
        alpha = round(205 - 175 * eased)
        draw.line([(x * S, 0), (x * S, height * S)], fill=(7, 9, 7, alpha))
    # Kiss the top and bottom edges with a little extra shade.
    for y in range(height):
        edge = min(y, height - 1 - y)
        if edge < 70:
            alpha = round(55 * (1 - edge / 70))
            draw.line([(0, y * S), (width * S, y * S)], fill=(0, 0, 0, alpha))
    return layer


def build() -> None:
    fetch_headers()
    width, height = 1920, 620
    canvas = Image.new("RGBA", (width * S, height * S), INK)

    tile_w, tile_h, gap = 380, 212, 8
    for index, (name, appid) in enumerate(GAMES[:15]):
        column, row = index % 5, index // 5
        image = Image.open(COVER_DIR / f"{appid}.jpg")
        tile = cover_crop(image, tile_w * S, tile_h * S)
        x = column * (tile_w + gap)
        y = -12 + row * (tile_h + gap)
        canvas.alpha_composite(tile.convert("RGBA"), (x * S, y * S))

    canvas = Image.alpha_composite(canvas, make_gradient(width, height))

    # A soft charcoal cloud behind the wordmark keeps cream type readable over
    # the collage without turning the left side into a flat black panel.
    scrim = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    scrim_draw = ImageDraw.Draw(scrim, "RGBA")
    scrim_draw.rounded_rectangle(
        [48 * S, 218 * S, 1240 * S, 488 * S],
        radius=48 * S,
        fill=(5, 7, 5, 142),
    )
    scrim = scrim.filter(ImageFilter.GaussianBlur(64 * S))
    canvas = Image.alpha_composite(canvas, scrim)
    draw = ImageDraw.Draw(canvas, "RGBA")

    # A restrained foreground label, well inside Steam's ultra-wide crop.
    kicker = font("DMSans-500.ttf", 14)
    tracked_text(draw, 105, 208, "STEAM LIBRARY ROULETTE   /   01", kicker, MUTED, 2.6, 1)

    word = "ROLLPLAY"
    tracking = 2.0
    word_size = 195
    while word_size > 110:
        word_font = font("Bricolage-800.ttf", word_size)
        if text_width(draw, word, word_font, tracking) <= 970:
            break
        word_size -= 5
    word_w = text_width(draw, word, word_font, tracking)

    star_radius = 37
    star_gap = 34
    start_x = 103
    d20(draw, start_x + star_radius, 320, star_radius, LIME, 4.5)
    title_x = start_x + star_radius * 2 + star_gap
    tracked_text(draw, title_x + 4, 384, word, word_font, (0, 0, 0, 165), tracking, 2)
    tracked_text(draw, title_x, 380, word, word_font, CREAM, tracking, 2)

    tagline = font("DMSans-500.ttf", 25)
    tracked_text(draw, 112, 441, "YOUR LIBRARY.  ONE ROLL.", tagline, (0, 0, 0, 150), 4.2, 1)
    tracked_text(draw, 108, 437, "YOUR LIBRARY.  ONE ROLL.", tagline, LIME, 4.2, 1)

    canvas.resize((width, height), Image.Resampling.LANCZOS).convert("RGB").save(
        OUT_DIR / "rollplay-hero.png", optimize=True
    )

    # A local preview of the client's 1490x323 hero crop.
    preview = canvas.convert("RGB")
    scale = 1490 / width
    preview = preview.resize((1490, round(height * scale)), Image.Resampling.LANCZOS)
    top = max(0, (preview.height - 323) // 2)
    preview.crop((0, top, 1490, top + 323)).save(
        ROOT / ".userdata" / "hero-preview.png", optimize=True
    )

    print(f"hero: {width}x{height}")
    print(f"wordmark size: {word_size}px, width: {word_w:.0f}px")
    print("preview: .userdata/hero-preview.png")


if __name__ == "__main__":
    build()
