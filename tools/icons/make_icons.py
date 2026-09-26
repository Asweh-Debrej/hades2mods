"""Generates the 256x256 Thunderstore icons listed in icons.json.

Artwork (Pom of Power, god symbols) comes from the installed game: tools/icons.ps1 extracts it with
deppth2 into .cache/game-textures. Background, frame, the infinity mark and text are drawn here.
Everything is composed at SS x resolution and downscaled once for smooth edges.

Usage: python make_icons.py [--preview out.png]
"""
import colorsys
import json
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
TEXTURES = os.path.join(ROOT, ".cache", "game-textures", "textures")
FONT = os.path.join(HERE, "fonts", "Cinzel.ttf")

SIZE = 256
SS = 4  # supersampling factor
C = SIZE * SS

POM_TEXTURE = "Items/Loot/StackUpgrade.png"
GOD_SYMBOL_TEXTURE = "GUI/Screens/BoonSelectSymbols/{god}.png"

GOLD = [(0.0, (255, 246, 205)), (0.4, (246, 205, 96)), (0.75, (214, 150, 40)), (1.0, (150, 92, 18))]
POM_GLOW = (255, 90, 70)
OUTLINE = (24, 10, 18, 255)


# ---------------------------------------------------------------- helpers

def px(value):
    """Layout units are 256-based; convert to supersampled pixels."""
    return int(round(value * SS))


def lerp(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def gradient_color(stops, t):
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            return lerp(c0, c1, (t - t0) / (t1 - t0) if t1 > t0 else 0)
    return stops[-1][1]


def vertical_gradient(width, height, stops):
    column = Image.new("RGB", (1, height))
    for y in range(height):
        column.putpixel((0, y), gradient_color(stops, y / max(1, height - 1)))
    return column.resize((width, height)).convert("RGBA")


def radial_gradient(size, inner, outer, center, radius):
    """Radial gradient from `inner` at `center` to `outer` at `radius` (computed small, then upscaled)."""
    small = 128
    scale = size / small
    img = Image.new("RGB", (small, small))
    cx, cy, r = center[0] / scale, center[1] / scale, radius / scale
    for y in range(small):
        for x in range(small):
            t = min(1.0, math.hypot(x - cx, y - cy) / r)
            img.putpixel((x, y), lerp(inner, outer, t * t * (3 - 2 * t)))
    return img.resize((size, size), Image.BICUBIC).convert("RGBA")


def trim(img):
    return img.crop(img.getchannel("A").getbbox())


def load_texture(rel):
    path = os.path.join(TEXTURES, rel)
    if not os.path.exists(path):
        sys.exit(f"Missing texture {path}. Run tools/icons.ps1 (it extracts the game textures first).")
    return Image.open(path).convert("RGBA")


def scaled(img, width):
    height = round(img.height * width / img.width)
    return img.resize((width, height), Image.LANCZOS)


def paste_center(canvas, img, center):
    canvas.alpha_composite(img, (int(center[0] - img.width / 2), int(center[1] - img.height / 2)))


def colored(mask, color):
    layer = Image.new("RGBA", mask.size, color[:3] + (255,))
    layer.putalpha(mask)
    return layer


def glow_layer(mask, color, radius, strength=1.0):
    blurred = mask.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        blurred = blurred.point(lambda v: min(255, int(v * strength)))
    return colored(blurred, color)


def outline_mask(mask, width):
    return mask.filter(ImageFilter.MaxFilter(width * 2 + 1))


def gold_from_mask(mask, bbox=None):
    """Gold gradient clipped to mask, with dark outline and inner bevel highlight."""
    x0, y0, x1, y1 = bbox or mask.getbbox()
    grad = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    grad.paste(vertical_gradient(x1 - x0, y1 - y0, GOLD), (x0, y0))
    grad.putalpha(mask)
    return grad


def emboss(canvas, mask, outline_px):
    """Dark outline + soft drop shadow + gold fill for a vector mask."""
    shadow = mask.filter(ImageFilter.GaussianBlur(px(3)))
    canvas.alpha_composite(colored(shadow.point(lambda v: int(v * 0.7)), (0, 0, 0)), (0, px(3)))
    canvas.alpha_composite(colored(outline_mask(mask, outline_px), OUTLINE))
    canvas.alpha_composite(gold_from_mask(mask))
    # thin highlight along the top edge
    highlight = ImageChops.subtract(mask, mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, px(1.2))))
    canvas.alpha_composite(colored(highlight.point(lambda v: int(v * 0.8)), (255, 255, 235)))


# ---------------------------------------------------------------- vector marks

def infinity_mask(center, width, thickness):
    """Lemniscate of Bernoulli as a thick stroke, stamped with discs (no gaps between segments)."""
    mask = Image.new("L", (C, C), 0)
    draw = ImageDraw.Draw(mask)
    a = width / 2
    r = thickness / 2
    steps = 2400
    for i in range(steps):
        t = 2 * math.pi * i / steps
        d = 1 + math.sin(t) ** 2
        x = center[0] + a * math.cos(t) / d
        y = center[1] + a * 1.15 * math.sin(t) * math.cos(t) / d
        draw.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return mask


def text_mask(text, center, size, spacing=0):
    font = ImageFont.truetype(FONT, size)
    try:
        font.set_variation_by_name("Bold")
    except (OSError, AttributeError, ValueError):
        pass
    mask = Image.new("L", (C, C), 0)
    draw = ImageDraw.Draw(mask)
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = center[0] - total / 2
    for ch, w in zip(text, widths):
        draw.text((x, center[1]), ch, font=font, fill=255, anchor="lm")
        x += w + spacing
    return mask


# ---------------------------------------------------------------- scene pieces

def symbol_theme(symbol):
    """Hue of the symbol's glow (semi-transparent pixels), normalised to a rich, saturated tint."""
    data = symbol.resize((128, 128)).tobytes()
    total = [0, 0, 0]
    weight = 0
    for i in range(0, len(data), 4):
        r, g, b, a = data[i:i + 4]
        if 8 < a < 200:
            total[0] += r * a
            total[1] += g * a
            total[2] += b * a
            weight += a
    if weight == 0:
        return (150, 60, 170)
    hue, _, _ = colorsys.rgb_to_hsv(*(v / weight / 255 for v in total))
    return tuple(int(v * 255) for v in colorsys.hsv_to_rgb(hue, 0.85, 0.9))


def background(theme):
    inner = lerp((0, 0, 0), theme, 0.42)
    outer = lerp((6, 3, 10), theme, 0.06)
    canvas = radial_gradient(C, inner, outer, (C / 2, C * 0.42), C * 0.78)
    # faint rays behind the centre piece
    rays = Image.new("L", (C, C), 0)
    draw = ImageDraw.Draw(rays)
    cx, cy = C / 2, C * 0.42
    for i in range(16):
        angle = math.radians(i * 22.5 + 11.25)
        spread = math.radians(4)
        far = C
        draw.polygon([(cx, cy),
                      (cx + far * math.cos(angle - spread), cy + far * math.sin(angle - spread)),
                      (cx + far * math.cos(angle + spread), cy + far * math.sin(angle + spread))], fill=38)
    rays = rays.filter(ImageFilter.GaussianBlur(px(4)))
    canvas.alpha_composite(colored(rays, lerp(theme, (255, 255, 255), 0.35)))
    return canvas


def frame(canvas, theme):
    """Double gold border with rounded corners (Hades UI style)."""
    outer = Image.new("L", (C, C), 0)
    d = ImageDraw.Draw(outer)
    d.rounded_rectangle([px(5), px(5), C - px(5), C - px(5)], radius=px(22), outline=255, width=px(4))
    inner = Image.new("L", (C, C), 0)
    d = ImageDraw.Draw(inner)
    d.rounded_rectangle([px(12), px(12), C - px(12), C - px(12)], radius=px(16), outline=255, width=px(1.5))
    canvas.alpha_composite(colored(outline_mask(outer, px(1.2)), OUTLINE))
    canvas.alpha_composite(gold_from_mask(outer, (0, 0, C, C)))
    canvas.alpha_composite(colored(inner.point(lambda v: int(v * 0.55)), lerp(theme, (255, 220, 150), 0.6)))
    # darken the corners outside the frame so the icon reads as a tile
    corner = Image.new("L", (C, C), 255)
    ImageDraw.Draw(corner).rounded_rectangle([px(5), px(5), C - px(5), C - px(5)], radius=px(22), fill=0)
    canvas.alpha_composite(colored(corner, (8, 4, 10)))


def pom(canvas, center, width, glow=True):
    art = trim(load_texture(POM_TEXTURE))
    art = scaled(art, px(width))
    if glow:
        halo = Image.new("L", (C, C), 0)
        r = px(width) * 0.55
        ImageDraw.Draw(halo).ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=200)
        canvas.alpha_composite(glow_layer(halo, POM_GLOW, px(22), 0.9))
    # dark contour so the pom separates from any background
    contour = Image.new("L", (C, C), 0)
    contour.paste(art.getchannel("A"), (int(center[0] - art.width / 2), int(center[1] - art.height / 2)))
    canvas.alpha_composite(colored(contour.filter(ImageFilter.GaussianBlur(px(2.5))), (0, 0, 0)))
    paste_center(canvas, art, center)


def infinity(canvas, center, width, thickness):
    mask = infinity_mask(center, px(width), px(thickness))
    canvas.alpha_composite(glow_layer(mask, (255, 190, 80), px(9), 0.9))
    emboss(canvas, mask, px(2.2))


def god_medallion(canvas, god, theme, center, radius):
    """Round gold-rimmed badge holding the god's boon-select symbol."""
    symbol = load_texture(GOD_SYMBOL_TEXTURE.format(god=god))
    side = int(symbol.width * 0.27)  # tight around the emblem so it dominates the badge
    off = (symbol.width - side) // 2
    symbol = scaled(symbol.crop((off, off, off + side, off + side)), int(radius * 2.2))
    symbol = ImageEnhance.Brightness(symbol).enhance(1.25)
    # keep only the (nearly opaque) emblem and drop the game's glow, which would otherwise
    # flood the badge for very bright symbols such as Zeus's; a subtle glow is re-added below
    symbol.putalpha(symbol.getchannel("A").point(lambda a: max(0, min(255, (a - 170) * 255 // 60))))

    cx, cy = center
    disc = Image.new("L", (C, C), 0)
    ImageDraw.Draw(disc).ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=255)
    canvas.alpha_composite(glow_layer(disc, theme, px(10), 0.8))
    fill = radial_gradient(C, lerp((0, 0, 0), theme, 0.45), (8, 4, 12), center, radius * 1.1)
    fill.putalpha(disc)
    canvas.alpha_composite(fill)

    inside = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    paste_center(inside, symbol, center)
    inside.putalpha(ImageChops.multiply(inside.getchannel("A"), disc))
    halo = ImageChops.multiply(inside.getchannel("A").filter(ImageFilter.GaussianBlur(px(4))), disc)
    canvas.alpha_composite(colored(halo, lerp(theme, (255, 255, 255), 0.3)))
    canvas.alpha_composite(inside)

    ring = Image.new("L", (C, C), 0)
    ImageDraw.Draw(ring).ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=255, width=px(4))
    emboss(canvas, ring, px(1.5))


def family_scene(theme, pom_center=(128, 94), pom_width=142, inf_center=(128, 199), inf_width=130, inf_thickness=19):
    """Shared Limitless Poms composition: Pom of Power above a gold infinity mark."""
    canvas = background(theme)
    pom(canvas, (px(pom_center[0]), px(pom_center[1])), pom_width)
    infinity(canvas, (px(inf_center[0]), px(inf_center[1])), inf_width, inf_thickness)
    return canvas


# ---------------------------------------------------------------- icon kinds

def render_brand(spec):
    theme = (150, 60, 170)
    gods = spec.get("gods", [])
    if not gods:
        canvas = family_scene(theme)
    else:
        # Pom + infinity shifted left, one small medallion per covered god down the right edge
        canvas = family_scene(theme, pom_center=(104, 96), pom_width=132, inf_center=(104, 196), inf_width=120, inf_thickness=18)
        radius = min(30, 180 / len(gods) / 2 - 3)
        top = 128 - (len(gods) - 1) * (radius * 2 + 6) / 2
        for i, god in enumerate(gods):
            god_theme = symbol_theme(load_texture(GOD_SYMBOL_TEXTURE.format(god=god)))
            god_medallion(canvas, god, god_theme, (px(207), px(top + i * (radius * 2 + 6))), px(radius))
    frame(canvas, theme)
    return canvas


def render_core(spec):
    theme = (70, 110, 150)
    canvas = family_scene(theme, pom_center=(128, 88), pom_width=118, inf_center=(128, 157), inf_width=104, inf_thickness=15)
    caption = text_mask(spec.get("caption", "CORE"), (px(128), px(210)), px(34), spacing=px(4))
    emboss(canvas, caption, px(2))
    frame(canvas, theme)
    return canvas


def render_god(spec):
    god = spec["god"]
    theme = symbol_theme(load_texture(GOD_SYMBOL_TEXTURE.format(god=god)))
    canvas = family_scene(theme, pom_center=(112, 98), pom_width=136)
    god_medallion(canvas, god, theme, (px(197), px(61)), px(42))
    frame(canvas, theme)
    return canvas


RENDERERS = {"brand": render_brand, "core": render_core, "god": render_god}


# ---------------------------------------------------------------- game textures

def required_textures(specs):
    names = {POM_TEXTURE}
    for spec in specs.values():
        for god in ([spec["god"]] if "god" in spec else []) + spec.get("gods", []):
            names.add(GOD_SYMBOL_TEXTURE.format(god=god))
    return names


def ensure_textures(specs):
    """Extracts (only) the GUI.pkg atlases that contain textures we still miss."""
    missing = [rel for rel in required_textures(specs) if not os.path.exists(os.path.join(TEXTURES, rel))]
    if not missing:
        return
    from deppth2.deppth2 import extract, list_contents

    workspace = json.load(open(os.path.join(ROOT, "workspace.json"), encoding="utf-8"))
    package = os.path.join(workspace["gamePath"], "Content", "Packages", "1080p", "GUI.pkg")
    wanted = {rel[:-len(".png")].replace("/", "\\") for rel in missing}
    print(f"Looking up {len(wanted)} texture(s) in {package} ...")
    lines = []
    list_contents(package, logger=lines.append)
    atlases, atlas = set(), None
    for line in lines:
        if not line.startswith(" "):
            atlas = line.strip()
        elif line.strip() in wanted:
            atlases.add(atlas)
    if not atlases:
        sys.exit(f"None of {sorted(wanted)} found in {package}")
    patterns = ["*" + name.split("\\")[-1] for name in sorted(atlases)]
    print(f"Extracting atlases {patterns} ...")
    extract(package, os.path.dirname(TEXTURES), *patterns, subtextures=True)


def main():
    specs = json.load(open(os.path.join(HERE, "icons.json"), encoding="utf-8"))
    ensure_textures(specs)
    rendered = []
    for rel, spec in specs.items():
        icon = RENDERERS[spec["kind"]](spec).resize((SIZE, SIZE), Image.LANCZOS)
        out = os.path.join(ROOT, rel, "icon.png")
        icon.convert("RGB").save(out, optimize=True)
        rendered.append((rel, icon))
        print(f"{rel}/icon.png")

    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        # full size + the ~64px size r2modman lists mods at
        sheet = Image.new("RGB", (len(rendered) * 276 + 20, 380), (30, 30, 34))
        for i, (_, icon) in enumerate(rendered):
            sheet.paste(icon.convert("RGB"), (20 + i * 276, 20))
            sheet.paste(icon.resize((64, 64), Image.LANCZOS).convert("RGB"), (20 + i * 276, 296))
            sheet.paste(icon.resize((32, 32), Image.LANCZOS).convert("RGB"), (100 + i * 276, 328))
        sheet.save(path)
        print("preview:", path)


if __name__ == "__main__":
    main()
