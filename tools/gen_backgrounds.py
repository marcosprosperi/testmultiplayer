# Pixel-art parallax layers for the level backgrounds (480x270 screen)
import random, sys
from PIL import Image

OUT = sys.argv[1]
SKY = Image.open(sys.argv[2]).convert("RGBA")   # resources/sky_.png: 4 gradient columns of 16x112
W, H = 480, 270

def sky(column, name, skip_top=0, height=H):
    """Sky gradient from one column of sky_.png (flipped: dark on top, light at
    the horizon), doubled in height and tiled sideways"""
    strip = SKY.crop((column * 16, 0, column * 16 + 16, 112)).transpose(Image.FLIP_TOP_BOTTOM)
    # skip_top drops the darkest band (rows from the top of the flipped strip)
    strip = strip.crop((0, skip_top, 16, 112))
    strip = strip.resize((16, strip.height * 2), Image.NEAREST)
    img = Image.new("RGBA", (W, height), strip.getpixel((0, 0)))
    for x in range(0, W, 16):
        img.paste(strip, (x, height - strip.height))
    img.save(f"{OUT}/{name}.png")

def ridge(width, base, amplitude, roughness, seed, smooth=1):
    """Heights (from the top) of a jagged ridge that wraps around horizontally"""
    rnd = random.Random(seed)
    points = 8
    keys = [base - rnd.uniform(0, amplitude) for _ in range(points)]
    heights = []
    for x in range(width):
        t = x / width * points
        i = int(t)
        f = t - i
        a, b = keys[i % points], keys[(i + 1) % points]
        if smooth:
            f = f * f * (3 - 2 * f)
        h = a + (b - a) * f + rnd.uniform(-roughness, roughness)
        heights.append(int(h))
    return heights

def mountains(name, color, shade, snow, seed, height=150):
    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    tops = ridge(W, base=height - 20, amplitude=height - 40, roughness=0.4, seed=seed, smooth=0)
    for x, top in enumerate(tops):
        # Slopes going down to the right are in shadow
        downhill = tops[(x + 5) % W] > tops[(x - 5) % W] + 4
        for y in range(top, height):
            c = shade if downhill and y < top + 40 else color
            if snow and y < top + 6 and top < height - 70:
                c = snow
            img.putpixel((x, y), c)
    img.save(f"{OUT}/{name}.png")

def hills(name, color, dark, tree, trunk, seed, height=210, crest=70):
    """Rolling hills whose crest is `crest` px from the top; the body fills
    down to the bottom so nothing shows under them when the camera moves"""
    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    tops = ridge(W, base=crest, amplitude=40, roughness=0, seed=seed)
    for x, top in enumerate(tops):
        for y in range(top, height):
            # Lighter rim on top, sparse darker dither below
            c = dark if (y - top) >= 3 and (x * 7 + y * 13) % 23 == 0 else color
            img.putpixel((x, y), c)
    rnd = random.Random(seed + 1)
    x = rnd.randint(0, 30)
    while x < W - 12:
        top = tops[x]
        h = rnd.randint(10, 18)
        # Trunk
        for y in range(top - 4, top + 1):
            img.putpixel((x + 4, y), trunk)
        # Round crown
        for dy in range(-h, -2):
            half = int((1 - abs((dy + h / 2 + 1) / (h / 2))) * 5) + 1
            for dx in range(-half, half + 1):
                if 0 <= x + 4 + dx < W:
                    img.putpixel((x + 4 + dx, top + dy - 2), tree if dx < half - 1 else dark)
        x += rnd.randint(18, 60)
    img.save(f"{OUT}/{name}.png")

def gradient(name, top, bottom, height=H, bands=8):
    """Vertical gradient in a few flat bands (pixel-art style, no smooth blend)"""
    img = Image.new("RGBA", (W, height))
    for y in range(height):
        band = min(bands - 1, y * bands // height)
        t = band / (bands - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(W):
            img.putpixel((x, y), c)
    img.save(f"{OUT}/{name}.png")

def stars(name, seed, count, height=200, bright=False):
    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    rnd = random.Random(seed)
    for _ in range(count):
        x, y = rnd.randrange(W), rnd.randrange(height)
        c = rnd.choice([(255, 255, 255, 255), (255, 244, 200, 255), (200, 220, 255, 255)])
        img.putpixel((x, y), c)
        if bright and rnd.random() < 0.5:
            # Little cross for the brighter stars
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + dx < W and 0 <= y + dy < height:
                    img.putpixel((x + dx, y + dy), c[:3] + (150,))
    img.save(f"{OUT}/{name}.png")

def moon(name, size=26):
    img = Image.new("RGBA", (size + 8, size + 8), (0, 0, 0, 0))
    r = size / 2
    c = size / 2 + 4
    for y in range(size + 8):
        for x in range(size + 8):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= r:
                color = (240, 236, 210, 255)
                # A few craters
                for cx, cy, cr in ((c - 5, c - 4, 3), (c + 4, c + 3, 4), (c - 2, c + 6, 2)):
                    if (x - cx) ** 2 + (y - cy) ** 2 <= cr * cr:
                        color = (212, 206, 180, 255)
                img.putpixel((x, y), color)
            elif d <= r + 3:
                img.putpixel((x, y), (240, 236, 210, int(60 * (r + 3 - d) / 3)))
    img.save(f"{OUT}/{name}.png")

def rock_wall(name, base, dark, light, seed, height=H):
    """Cave wall: blocky stones with darker cracks, tiles sideways"""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, height), base)
    y = 0
    while y < height:
        row_h = rnd.randint(10, 18)
        x = rnd.randint(-20, 0)
        while x < W:
            stone_w = rnd.randint(16, 40)
            shade = rnd.choice([base, base, dark, light])
            for yy in range(y + 1, min(height, y + row_h)):
                for xx in range(x + 1, x + stone_w):
                    img.putpixel((xx % W, yy), shade)
            x += stone_w
        y += row_h
    # Darker towards the top and bottom (the light is in the middle)
    for yy in range(height):
        k = abs(yy - height * 0.55) / (height * 0.55)
        if k > 0.6:
            for xx in range(W):
                r, g, b, a = img.getpixel((xx, yy))
                f = 1 - (k - 0.6) * 0.8
                img.putpixel((xx, yy), (int(r * f), int(g * f), int(b * f), a))
    img.save(f"{OUT}/{name}.png")

def stalactites(name, color, shade, seed, height=90, from_top=True, crystals=None):
    """Spikes hanging from the ceiling (or growing from the floor)"""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    # Solid rock band where they come from
    band = 10
    for x in range(W):
        for y in range(band + rnd.randint(0, 3)):
            yy = y if from_top else height - 1 - y
            img.putpixel((x, yy), color)
    x = rnd.randint(0, 10)
    while x < W - 4:
        width = rnd.randint(12, 26)
        length = rnd.randint(16, int((height - 10) * 0.75))
        for d in range(length):
            half = max(0, int(width / 2 * (1 - d / length)))
            for dx in range(-half, half + 1):
                px = (x + dx) % W
                py = band + d if from_top else height - 1 - band - d
                img.putpixel((px, py), shade if dx > half // 2 else color)
        if crystals and rnd.random() < 0.35:
            # Glowing crystal at the tip
            tip = band + length if from_top else height - 1 - band - length
            for dy in range(-3, 4):
                for dx in range(-2, 3):
                    if abs(dx) + abs(dy) <= 3 and 0 <= tip + dy < height:
                        img.putpixel(((x + dx) % W, tip + dy), crystals if abs(dx) + abs(dy) < 3 else crystals[:3] + (120,))
        x += width + rnd.randint(4, 30)
    img.save(f"{OUT}/{name}.png")

def clouds(name, color, shade, seed, height=90, count=5, size=(28, 60)):
    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    rnd = random.Random(seed)
    for i in range(count):
        cx = int((i + rnd.uniform(0.1, 0.9)) * W / count)
        cy = rnd.randint(18, height - 18)
        width = rnd.randint(*size)
        for bump in range(5):
            bx = cx + int((bump - 2) * width / 6)
            r = rnd.randint(width // 6, width // 4) if bump in (1, 2, 3) else width // 7
            for y in range(-r, r + 1):
                for x in range(-r, r + 1):
                    if x * x + y * y <= r * r and cy + y <= cy + width // 8:
                        px, py = (bx + x) % W, cy + y
                        if 0 <= py < height:
                            img.putpixel((px, py), shade if y > r // 3 else color)
    img.save(f"{OUT}/{name}.png")

sky(0, "sky_day", skip_top=28)
sky(1, "sky_sunset")
# Taller sky for the climbing level: it scrolls down slowly as you go up
sky(0, "sky_climb", skip_top=28, height=500)
mountains("mountains_day", (126, 152, 190, 255), (102, 124, 163, 255), (236, 242, 250, 255), seed=3)
hills("hills_day", (86, 160, 92, 255), (64, 128, 74, 255), (52, 120, 66, 255), (90, 64, 44, 255), seed=5)
clouds("clouds_day", (255, 255, 255, 235), (214, 230, 245, 235), seed=7)
mountains("mountains_sunset", (122, 76, 120, 255), (96, 56, 100, 255), None, seed=11, height=160)
hills("hills_sunset", (78, 62, 96, 255), (58, 46, 76, 255), (48, 40, 66, 255), (40, 30, 48, 255), seed=13)
clouds("clouds_sunset", (255, 196, 150, 220), (232, 150, 120, 220), seed=17, count=4)
# Climbing level: clouds all over (tile vertically too), far and near
clouds("clouds_far", (255, 255, 255, 170), (220, 234, 248, 170), seed=21, height=300, count=6, size=(24, 44))
clouds("clouds_near", (255, 255, 255, 230), (210, 226, 244, 230), seed=23, height=300, count=3, size=(60, 100))
# Night
gradient("sky_night", (12, 14, 38), (44, 52, 96))
stars("stars_a", seed=31, count=90)
stars("stars_b", seed=37, count=40, bright=True)
moon("moon")
mountains("mountains_night", (40, 48, 82, 255), (30, 36, 64, 255), (120, 130, 170, 255), seed=41)
hills("hills_night", (26, 40, 52, 255), (20, 30, 40, 255), (18, 30, 36, 255), (16, 20, 24, 255), seed=43)
# Cave
rock_wall("cave_wall", (58, 50, 52, 255), (46, 40, 42, 255), (70, 62, 62, 255), seed=51)
stalactites("cave_ceiling", (40, 34, 36, 255), (30, 25, 27, 255), seed=53, crystals=(120, 220, 255, 255))
stalactites("cave_floor", (34, 29, 31, 255), (26, 22, 24, 255), seed=57, height=110, from_top=False, crystals=(190, 120, 255, 255))
print("ok")
