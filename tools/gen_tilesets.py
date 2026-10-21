# Recolors the nature tileset into snow and volcano versions (same layout, so
# the same tiles and collisions work). Usage: gen_tilesets.py <resources dir>
import colorsys, sys
from PIL import Image

RES = sys.argv[1]
src = Image.open(f"{RES}/nature-paltformer-tileset-16x16.png").convert("RGBA")


def recolor(fn):
    out = src.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            nr, ng, nb = fn(h * 360, s, v)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def is_green(h, s):
    return 70 <= h <= 170 and s > 0.25


def snow(h, s, v):
    if is_green(h, s):
        # Grass becomes snow: white with a blue shade in the darker parts
        return colorsys.hsv_to_rgb(205 / 360, 0.25 * (1 - v) + 0.05, min(1.0, 0.55 + v * 0.5))
    if 0 <= h <= 50 and s > 0.2:
        # Earth turns colder and darker (frozen ground)
        return colorsys.hsv_to_rgb(215 / 360, s * 0.45, v * 0.85)
    return colorsys.hsv_to_rgb(h / 360, s, v)


def volcano(h, s, v):
    if is_green(h, s):
        # Grass becomes glowing embers on dark rock
        if v > 0.55:
            return colorsys.hsv_to_rgb(28 / 360, 0.9, min(1.0, v + 0.2))
        return colorsys.hsv_to_rgb(12 / 360, 0.85, v * 0.9)
    if 0 <= h <= 50 and s > 0.2:
        # Earth becomes dark basalt
        return colorsys.hsv_to_rgb(350 / 360, 0.25, v * 0.55)
    return colorsys.hsv_to_rgb(h / 360, s, v * 0.8)


recolor(snow).save(f"{RES}/nature_snow.png")
recolor(volcano).save(f"{RES}/nature_volcano.png")
print("ok")
