"""アプリアイコンを生成する。python tools/make_icon.py"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SCALE = 4
SIZE = 1024 * SCALE
BACKGROUND = (11, 13, 16)
TRACK = (35, 39, 46)
ACCENT = (198, 244, 50)
OUTPUT = Path(__file__).resolve().parent.parent / "GigaMeter/Assets.xcassets/AppIcon.appiconset/icon-1024.png"


def arc_layer(start, end, color, width, box):
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.arc(box, start, end, fill=color, width=width)
    return layer


def cap_layer(angle_points, color, width):
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x, y in angle_points:
        draw.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=color)
    return layer


def main():
    import math

    margin = 196 * SCALE
    width = 112 * SCALE
    box = (margin, margin, SIZE - margin, SIZE - margin)
    radius = (SIZE - 2 * margin - width) / 2
    center = SIZE / 2

    def point(degrees):
        rad = math.radians(degrees)
        return center + radius * math.cos(rad), center + radius * math.sin(rad)

    start, end = -90, 150
    used_color = (*ACCENT, 255)

    image = Image.new("RGBA", (SIZE, SIZE), (*BACKGROUND, 255))
    image.alpha_composite(arc_layer(0, 360, (*TRACK, 255), width, box))

    used = arc_layer(start, end, used_color, width, box)
    used.alpha_composite(cap_layer([point(start), point(end)], used_color, width))

    glow = used.filter(ImageFilter.GaussianBlur(48 * SCALE))
    alpha = glow.getchannel("A").point(lambda value: int(value * 0.55))
    glow.putalpha(alpha)
    image.alpha_composite(glow)
    image.alpha_composite(used)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
