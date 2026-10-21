# Section-based generator for long race levels that go up and down.
# A cursor walks to the right; each section adds floor, nodes and points of
# the route ("Course" Path2D, used for the race progress and by the test bot).
import base64, random, re, struct, zlib

T = 16
NATURE = 4      # nature tileset source in level_tileset.tres
# Recolored copies of the nature tiles (tools/gen_tilesets.py), same layout
GRASSY = {"grass": 4, "snow": 5, "volcano": 6}
SUMMER = 0      # summer_.png source (grey stone blocks)
CEILING_GAP = 9 # rows between floor and ceiling in cave levels
FLAG_EVERY = 1800  # px of route between checkpoint flags (at most, about)


class LevelBuilder:
    def __init__(self, name, background, style="grass", uid=None, seed=1, start_row=40):
        self.name = name
        self.background = background
        self.style = style          # "grass", "snow", "volcano" or "stone" (stone has a ceiling)
        self.grassy = style in GRASSY
        self.src = GRASSY.get(style, NATURE)
        self.uid = uid
        self.rnd = random.Random(seed)
        self.x = 0                  # cursor column
        self.row = start_row        # cursor floor row (surface)
        self.surface = {}           # column -> floor row
        self.platforms = []         # (x0, x1, row) one-tile floating platforms
        self.ceiling_open = set()   # columns with no ceiling (balloon shafts)
        self.extra_tiles = {}       # (x, y) -> (source, ax, ay) decorations
        self.decor_nodes = []       # torches, banners (see decorate_stone)
        self.nodes = []
        self.course = []
        self.counters = {}
        self.kill_zones = []        # (x_px, y_px, w_px)
        self.last_jump_hazard = -999  # column of the last thing you must jump over
        self.root_extra = ""
        self.wide_spacing = False   # see enemies_run
        self.last_flag = 0.0        # route length at the last checkpoint flag
        self.stone_row = 7          # summer_.png stone band: 7 grey (dungeon), 12 light (castle)
        self.margin = 1.0           # scales the flat runs between hazards (extreme levels: less)
        self.flag_every = FLAG_EVERY

    # --- helpers -------------------------------------------------------------
    def uname(self, prefix):
        self.counters[prefix] = self.counters.get(prefix, 0) + 1
        return f"{prefix}{self.counters[prefix]}"

    def px(self, col):
        return col * T

    def point(self, col, row, dy=-8):
        p = (col * T + 8, row * T + dy)
        if not self.course or self.course[-1] != p:
            self.course.append(p)

    def floor(self, x0, x1, row):
        for x in range(x0, x1 + 1):
            self.surface[x] = row

    def node(self, prefix, scene, x, y, parent="Hazards", name=None, **props):
        name = name or self.uname(prefix)
        lines = [f'[node name="{name}" parent="{parent}" instance=ExtResource("{scene}")]', f"position = Vector2({x}, {y})"]
        lines += [f"{k} = {v}" for k, v in props.items()]
        self.nodes.append("\n".join(lines))
        return name

    def coin(self, x, y):
        self.node("Coin", "coin", x, y, parent="Coins")

    def coins_row(self, col0, col1, row, step=2, lift=10):
        for c in range(col0, col1 + 1, step):
            self.coin(c * T + 8, row * T - lift)

    def kill_under(self, col0, col1, row):
        self.kill_zones.append(((col0 + col1 + 1) * T / 2, (row + 12) * T, (col1 - col0 + 3) * T))

    def mark_jump(self, col):
        self.last_jump_hazard = max(self.last_jump_hazard, col)

    def decor(self, col):
        kind = self.rnd.choice([(6, 6), (5, 6), (4, 6), (3, 6)])
        if self.grassy:
            self.extra_tiles[(col, self.surface[col] - 1)] = (self.src, *kind)

    # --- sections ------------------------------------------------------------
    def run(self, n, coins=False, decor=True):
        x0 = self.x
        self.floor(x0, x0 + n - 1, self.row)
        if decor and n > 6:
            for _ in range(n // 12):
                self.decor(self.rnd.randint(x0 + 1, x0 + n - 2))
        if coins and n >= 8:
            self.coins_row(x0 + 2, x0 + min(n - 2, 8), self.row, step=2, lift=24)
        self.x += n
        self.point(self.x - 1, self.row)

    def route_length(self):
        return sum(((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5 for (ax, ay), (bx, by) in zip(self.course, self.course[1:]))

    def flag(self):
        """Checkpoint flag on the floor here (losing brings you back to it)"""
        self.run(2, decor=False)
        self.node("Checkpoint", "checkpoint", self.px(self.x - 1), self.row * T)
        self.last_flag = self.route_length()

    def safe_margin(self, n=12):
        """Flat run so nothing that makes you jump is right before what comes
        next. It's also where flags go when it's been a while since the last"""
        if self.course and self.route_length() - self.last_flag > self.flag_every:
            self.flag()
        n = int(n * self.margin)
        if self.x - self.last_jump_hazard < n:
            self.run(n - (self.x - self.last_jump_hazard))

    def checkpoint(self):
        """Flag (unless there's one just behind) plus a row of power-up boxes"""
        if self.route_length() - self.last_flag > FLAG_EVERY / 3:
            self.flag()
        self.item_boxes()

    def item_boxes(self):
        """A row of power-up boxes at head height: you get one running through"""
        self.run(3, decor=False)
        for i in range(3):
            self.node("ItemBox", "item_box", self.px(self.x + i * 2) + 8, self.row * T - 12)
        self.run(7, decor=False)
        # Someone may drop a peel here: room before the next thing to jump
        self.mark_jump(self.x)

    def spikes_run(self, groups=2, length=3, space=14):
        # 16+ tiles between groups: a full jump over one never lands on the next
        for _ in range(groups):
            self.run(space)
            self.node("Spikes", "spikes", self.px(self.x), self.row * T, tiles=length)
            if self.rnd.random() < 0.6:
                self.coin(self.px(self.x) + length * 8, self.row * T - 34)
            self.mark_jump(self.x + length)
            self.run(length + 1, decor=False)
        self.run(6)

    def retractable_run(self, auto=True, name=None):
        self.safe_margin(16)
        self.run(8)
        name = self.node("PopSpikes", "retractable", self.px(self.x), self.row * T, name=name, tiles=3,
                         **({"auto_period": round(self.rnd.uniform(2.4, 3.2), 1), "active_time": 1.0} if auto else {}))
        self.mark_jump(self.x + 3)
        self.run(16)
        return name

    def gap(self, width=5, kind="jump", name=None):
        self.safe_margin()
        self.run(3, decor=False)
        x0 = self.x
        x1 = x0 + width - 1
        row = self.row
        self.kill_under(x0, x1, row)
        if self.style == "volcano":
            self.node("Lava", "lava", self.px(x0), row * T + 6, tiles=width, depth=64.0)
        if kind == "falling":
            # A falling platform in the middle
            length = min(8, width - 6)
            self.node("Falling", "falling", self.px(x0 + 3), (row - 1) * T, tiles=length)
            self.point(x0 + 3 + length // 2, row - 1)
            self.coins_row(x0 + 4, x0 + 2 + length, row - 1, step=2)
        elif kind == "mover":
            self.node("Mover", "moving", self.px(x0 + 1), (row - 1) * T, tiles=4,
                      travel=f"Vector2({(width - 6) * T}, 0)", period=round(width / 4.0, 1),
                      phase=round(self.rnd.random(), 2))
            self.point(x0 + width // 2, row - 1)
        elif kind == "trapdoor":
            name = self.node("TrapDoor", "trap_door", self.px(x0), row * T, name=name, tiles=width, active_time=2.0)
            self.point(x0 + width // 2, row)
            self.x = x1 + 1
            self.run(3, decor=False)
            return name
        elif kind == "saw":
            self.node("Saw", "saw", self.px(x0) + width * 8, row * T - 70, travel="Vector2(0, 90)",
                      period=round(self.rnd.uniform(1.6, 2.2), 1), radius=11.0)
        self.x = x1 + 1
        self.run(3, decor=False)
        self.mark_jump(self.x)
        return None

    def step(self, rise):
        """Change floor height by `rise` rows (positive = up, at most 4)"""
        self.safe_margin(8)
        self.row -= rise
        self.run(6)

    def stairs(self, steps, rise=2, width=4, up=True):
        self.safe_margin(8)
        for _ in range(steps):
            self.row += -rise if up else rise
            self.run(width, decor=False)
        self.run(4)

    def climb(self, levels=4, elevator=False):
        """Go up `levels` * 4 rows: a diagonal staircase of floating platforms
        (none right above another) or an elevator. Falling just takes you
        back to the bottom"""
        self.safe_margin(8)
        self.run(4)
        x0 = self.x
        bottom = self.row
        if elevator:
            # A shaft: the elevator comes down flush with the floor; falling
            # into the shaft while it's up loses. The way out is 2 tiles from it
            width = 10
            height = levels * 4
            self.floor(x0, x0 + 3, bottom)
            self.kill_under(x0 + 4, x0 + 9, bottom)
            self.node("Elevator", "moving", self.px(x0 + 4), bottom * T, tiles=4,
                      travel=f"Vector2(0, {-height * T})", period=round(height * 0.32, 1))
            self.point(x0 + 6, bottom)
            self.point(x0 + 6, bottom - height)
            top = bottom - height
        else:
            # The way out starts one tile after the last platform
            width = 6 * levels + 1
            self.floor(x0, x0 + width - 1, bottom)
            for k in range(1, levels + 1):
                row = bottom - 4 * k
                px0 = x0 + 2 + 6 * (k - 1)
                self.platforms.append((px0, px0 + 3, row))
                self.point(px0 + 2, row)
                if self.rnd.random() < 0.4:
                    self.coin((px0 + 2) * T, row * T - 10)
            top = bottom - 4 * levels
        self.x = x0 + width
        self.row = top
        self.run(6)

    def drop(self, rows=8):
        """The floor ends and you fall `rows` rows down to the next part"""
        self.safe_margin(8)
        self.run(2, decor=False)
        # The route goes over the edge and straight down
        self.row += rows
        self.point(self.x + 1, self.row)
        self.run(8)

    def crusher_hall(self, count=3, spacing=10, name=None, period=3.6, active=0.8, offset=1.2):
        self.safe_margin(8)
        self.run(6)
        chain = 16.0 if self.style == "stone" else 120.0
        for i in range(count):
            self.run(spacing - 1, decor=False)
            self.node("Crusher", "crusher", self.px(self.x) + 8, self.row * T, height=80.0, chain_length=chain,
                      auto_period=period, auto_offset=round(i * offset, 1), active_time=active)
            self.coin(self.px(self.x) + 8, self.row * T - 12)
            self.run(1, decor=False)
        self.run(8)

    def enemies_run(self, kinds, length=40):
        """Enemies patrolling a flat stretch, each in its own 18-tile slot so a
        jump over one never lands on the next"""
        self.safe_margin(8)
        x0 = self.x
        slot = 18
        # wide_spacing: the next enemy starts 17 tiles after where this one's
        # patrol ends (not just 18 after where it starts)
        if not self.wide_spacing:
            length = max(length, 14 + slot * len(kinds) + 2)
            self.run(length)
        cx = x0 + 14
        for i, kind in enumerate(kinds):
            if not self.wide_spacing:
                cx = x0 + 14 + i * slot
            patrol = self.rnd.randint(3, 6) * T
            if kind == "bat":
                # High enough to run under; jumping under it is what hurts
                self.node("Bat", "bat", self.px(cx), (self.row - 3) * T - 4, travel=f"Vector2({patrol}, 0)",
                          speed=50.0, phase=round(self.rnd.random(), 2), bob=8.0)
            elif kind == "bee":
                # Flies in a circle that comes down to the floor: pass when it's up
                radius = self.rnd.randint(20, 28)
                self.node("Bee", "bee", self.px(cx) + 8, self.row * T - 24, travel=f"Vector2({radius}, 0)",
                          speed=round(self.rnd.uniform(70, 90)), phase=round(self.rnd.random(), 2))
                patrol = radius
            elif kind == "ghost":
                # Floats at head height; goes see-through every few seconds
                self.node("Ghost", "ghost", self.px(cx), self.row * T - 2, travel=f"Vector2({patrol}, 0)",
                          speed=22.0, phase=round(self.rnd.random(), 2), bob=4.0)
            elif kind == "frog":
                patrol = self.rnd.randint(2, 4) * 32
                self.node("Frog", "frog", self.px(cx), self.row * T, travel=f"Vector2({patrol}, 0)",
                          phase=round(self.rnd.random(), 2))
            elif kind == "penguin":
                patrol = self.rnd.randint(6, 9) * T
                self.node("Penguin", "penguin", self.px(cx), self.row * T, travel=f"Vector2({patrol}, 0)",
                          speed=round(self.rnd.uniform(85, 100)), phase=round(self.rnd.random(), 2))
            else:
                scene = "slime" if kind == "slime" else "spiky"
                self.node(kind.capitalize(), scene, self.px(cx), self.row * T, travel=f"Vector2({patrol}, 0)",
                          speed=35.0 if kind == "slime" else 45.0, phase=round(self.rnd.random(), 2))
            self.mark_jump(cx + patrol // T)
            if self.wide_spacing:
                cx += max(slot, patrol // T + 17)
        if self.wide_spacing:
            self.run(max(length, cx - x0))
        self.run(6)

    def saw_run(self, length=24):
        self.safe_margin(8)
        x0 = self.x
        self.run(length)
        self.node("FloorSaw", "saw", self.px(x0 + 4), self.row * T - 10,
                  travel=f"Vector2({(length - 8) * T}, 0)", period=round(length / 8.0, 1))
        # Safe high route over it
        self.platforms.append((x0 + 5, x0 + length - 6, self.row - 5))
        self.coins_row(x0 + 6, x0 + length - 7, self.row - 5, step=2)
        self.mark_jump(x0 + length)
        self.run(6)

    def fan_run(self, name=None, auto=False):
        self.safe_margin(8)
        self.run(6)
        self.node("Spikes", "spikes", self.px(self.x + 2), self.row * T, tiles=3)
        self.run(14, decor=False)
        extra = {"auto_period": 6.0, "auto_offset": round(self.rnd.uniform(0, 3), 1)} if auto else {}
        name = self.node("Fan", "fan", self.px(self.x), self.row * T - 24, name=name, direction=-1, reach=176.0,
                         strength=200.0, active_time=2.5 if auto else 3.0, **extra)
        self.mark_jump(self.x)
        self.run(8)
        return name

    def cannon_run(self):
        self.safe_margin(10)
        self.run(26)
        self.node("Cannon", "cannon", self.px(self.x - 1), self.row * T, parent=".",
                  cannon_look_to='"Left"', fire_rate=1.8, ball_speed=200.0)
        self.mark_jump(self.x)
        self.run(14)

    def button(self, targets):
        """Plate that fires `targets` (traps further ahead) from here"""
        self.run(4, decor=False)
        paths = ", ".join(f'NodePath("../{t}")' for t in targets)
        self.node("Button", "button", self.px(self.x - 2) + 8, self.row * T, targets=f"Array[NodePath]([{paths}])")
        self.mark_jump(self.x)
        self.run(6)

    def balloon_shaft(self, height_rows=60, width=30):
        """Wide shaft with rising balloons; the way out is a ledge at the top right"""
        self.safe_margin(8)
        self.run(4)
        x0 = self.x
        bottom = self.row
        top = bottom - height_rows
        self.floor(x0, x0 + width - 1, bottom)
        for c in range(x0, x0 + width):
            self.ceiling_open.add(c)
        colors = ["Color(0.906, 0.298, 0.235, 1)", "Color(0.204, 0.596, 0.859, 1)", "Color(0.945, 0.769, 0.059, 1)",
                  "Color(0.180, 0.800, 0.443, 1)", "Color(0.608, 0.349, 0.714, 1)"]
        spacing_cols = (width - 4) // 5
        for i in range(5):
            cx = x0 + 3 + i * spacing_cols
            name = self.uname("Balloons")
            self.nodes.append(f'''[node name="{name}" type="Node2D" parent="Hazards"]
position = Vector2({cx * T}, {bottom * T - 8})
script = ExtResource("column")
top_height = {height_rows * T + 120}.0
spacing = 150.0
speed = {self.rnd.choice([40, 46, 52, 58, 62])}.0
phase = {self.rnd.randint(0, 140)}.0
color = {colors[i]}''')
        for k in range(1, 6):
            self.coin((x0 + self.rnd.randint(4, width - 5)) * T, (bottom - k * height_rows // 6) * T)
        self.point(x0 + width // 2, bottom)
        self.point(x0 + width - 4, top)
        self.x = x0 + width
        self.row = top
        self.run(8)

    def ice_run(self, length=30, enemies=()):
        """Slippery ice over a flat stretch, maybe with penguins sliding on it"""
        self.safe_margin(8)
        self.run(4)
        x0 = self.x
        # Each penguin in its own 20-tile slot (a jump over one never lands
        # where the next one slides)
        length = max(length, 8 + 20 * len(enemies))
        self.run(length, decor=False)
        self.node("Ice", "ice", self.px(x0), self.row * T, tiles=length)
        for i, kind in enumerate(enemies):
            cx = x0 + 8 + i * 20
            self.node("Penguin", "penguin", self.px(cx), self.row * T, travel=f"Vector2({6 * T}, 0)",
                      speed=round(self.rnd.uniform(80, 95)), phase=round(self.rnd.random(), 2))
        self.mark_jump(self.x)
        # Room to stop sliding before whatever comes next
        self.run(8)

    def lava_gap(self, width=5, fireball=True):
        """A pit of lava to jump over; a fireball may jump out of it"""
        self.safe_margin()
        self.run(3, decor=False)
        x0 = self.x
        row = self.row
        self.kill_under(x0, x0 + width - 1, row)
        self.node("Lava", "lava", self.px(x0), row * T + 6, tiles=width, depth=64.0)
        if fireball:
            self.node("Fireball", "fireball", self.px(x0) + width * 8, row * T + 8, travel="Vector2(0, -88)",
                      period=round(self.rnd.uniform(2.2, 3.0), 1), phase=round(self.rnd.random(), 2))
        self.x = x0 + width
        self.run(3, decor=False)
        self.mark_jump(self.x)

    def pillars(self, count=5, width=2, gaps=(4, 6), rises=(-2, -1, 0, 1, 2), lava=False):
        """Narrow islands over a pit (or lava), each at its own height: one
        exact jump after another"""
        self.safe_margin(8)
        self.run(3, decor=False)
        start = self.row
        for _ in range(count):
            gap = self.rnd.randint(*gaps)
            x0 = self.x
            before = self.row
            # Never far from where the section started
            self.row = min(max(self.row - self.rnd.choice(rises), start - 4), start + 4)
            low = max(before, self.row)
            self.kill_under(x0, x0 + gap - 1, low)
            if lava or self.style == "volcano":
                self.node("Lava", "lava", self.px(x0), low * T + 6, tiles=gap, depth=64.0)
            self.x += gap
            self.run(width, decor=False)
        self.mark_jump(self.x)
        self.run(3, decor=False)

    def lava_run(self, pits=3):
        for i in range(pits):
            self.lava_gap(self.rnd.choice([4, 5, 6]), fireball=i % 2 == 0)
            self.run(12)

    def finish(self):
        self.safe_margin(10)
        self.run(14)
        self.finish_col = self.x - 6
        self.point(self.finish_col, self.row)
        self.run(6, decor=False)

    # --- output --------------------------------------------------------------
    def render_tiles(self):
        tiles = {}
        self.depth = {}             # (x, y) -> rows below the surface (ground only)
        cols = sorted(self.surface)
        first, last = cols[0], cols[-1]
        def solid(src, ax, ay):
            return (src, ax, ay)
        for x in cols:
            r = self.surface[x]
            # Fill down far enough to make a wall where the neighbour is lower
            neighbours = [self.surface.get(x - 1, r), self.surface.get(x + 1, r)]
            depth = max(4, max(n - r for n in neighbours) + 4)
            left_open = self.surface.get(x - 1) is None or self.surface.get(x - 1) > r
            right_open = self.surface.get(x + 1) is None or self.surface.get(x + 1) > r
            for d in range(depth + 1):
                y = r + d
                top = d == 0
                bottom = d == depth
                self.depth[(x, y)] = d
                if self.grassy:
                    col = 0 if left_open else (2 if right_open else 1)
                    tiles[(x, y)] = (self.src, col, 0 if top else (2 if bottom else 1))
                else:
                    col = 6 if left_open else (8 if right_open else 7)
                    sr = self.stone_row
                    tiles[(x, y)] = (SUMMER, col, sr if top else (sr + 2 if bottom else sr + 1))
        # Floating platforms
        for x0, x1, row in self.platforms:
            for x in range(x0, x1 + 1):
                if self.grassy:
                    tiles[(x, row)] = (self.src, 3 if x == x0 else (5 if x == x1 else 4), 0)
                else:
                    tiles[(x, row)] = (SUMMER, 6 if x == x0 else (8 if x == x1 else 7), self.stone_row - 2)
        # Ceiling for stone levels: lowest floor around minus CEILING_GAP, with
        # side walls where its height changes
        self.ceiling = {}
        if self.style == "stone":
            ceiling = {}
            for x in range(first - 2, last + 3):
                window = [self.surface[c] for c in range(x - 6, x + 7) if c in self.surface]
                if not window:
                    continue
                climb_tops = [row for (x0, x1, row) in self.platforms if x0 - 6 <= x <= x1 + 6]
                ceiling[x] = min(window + climb_tops) - CEILING_GAP
            for x, c in ceiling.items():
                if x in self.ceiling_open:
                    continue
                top = min(ceiling.get(x - 1, c), ceiling.get(x + 1, c), c) - 4
                self.ceiling[x] = c
                for y in range(top, c + 1):
                    tiles[(x, y)] = (SUMMER, 7, self.stone_row + (2 if y == c else 1))
        # Walls at both ends: just taller than anyone can jump (or up to the
        # ceiling in stone levels)
        r0 = self.surface[first]
        r1 = self.surface[last]
        wall = (self.src, 6, 1) if self.grassy else (SUMMER, 7, self.stone_row + 1)
        for (cols, r) in (((first - 1, first - 2), r0), ((last + 1, last + 2), r1)):
            height = 7 if self.grassy else 20
            for y in range(r - height, r + 5):
                for x in cols:
                    tiles[(x, y)] = wall
        tiles.update({k: v for k, v in self.extra_tiles.items() if k not in tiles})
        if self.grassy:
            self.decorate(tiles)
        else:
            self.decorate_stone()
        return tiles

    def decorate_stone(self):
        """Torches on the back wall and, in the castle, banners hanging from
        the ceiling (nodes, not tiles, so they flicker and sway)"""
        rnd = random.Random(zlib.crc32(self.name.encode()) + 1)
        busy = set()
        for n in self.nodes:
            if 'parent="Hazards"' in n:
                for x_px in [float(v) for v in re.findall(r"position = Vector2\(([-\d.]+),", n)]:
                    busy.update(range(int(x_px // T) - 1, int(x_px // T) + 4))
        colors = ["Color(0.66, 0.2, 0.29, 1)", "Color(0.24, 0.35, 0.68, 1)", "Color(0.45, 0.25, 0.6, 1)"]
        x = min(self.surface) + 6
        while x < max(self.surface) - 6:
            r = self.surface.get(x)
            if r is None or x in busy or self.surface.get(x + 1) != r:
                x += 1
                continue
            self.decor_nodes.append(f'''[node name="Torch{x}" parent="Decor" instance=ExtResource("torch")]
position = Vector2({x * T + 8}, {(r - 3) * T})''')
            c = self.ceiling.get(x + 4)
            if self.stone_row == 12 and c is not None and r - c > 6:
                self.decor_nodes.append(f'''[node name="Banner{x}" parent="Decor" instance=ExtResource("banner")]
position = Vector2({(x + 4) * T + 8}, {(c + 1) * T})
color = {rnd.choice(colors)}''')
            x += rnd.randint(10, 16)

    def decorate(self, tiles):
        """Trees, bushes, flowers, rocks, stumps and vines on the flat floor,
        away from hazards, platforms and the route's important spots. Uses its
        own random numbers so the level itself stays the same"""
        rnd = random.Random(zlib.crc32(self.name.encode()))
        busy = set()
        for n in self.nodes:
            if 'parent="Hazards"' not in n:
                continue
            for x_px in [float(v) for v in re.findall(r"position = Vector2\(([-\d.]+),", n)]:
                c = int(x_px // T)
                busy.update(range(c - 1, c + 4))
        platform_cols = {}
        for x0, x1, row in self.platforms:
            for c in range(x0 - 1, x1 + 2):
                platform_cols[c] = max(platform_cols.get(c, -999), row)
        src = self.src
        x = min(self.surface) + 4
        last = max(self.surface) - 4
        while x < last:
            r = self.surface.get(x)
            flat = r is not None and all(self.surface.get(c) == r for c in (x - 1, x, x + 1))
            # Row of the nearest platform above (far away if none)
            room = platform_cols.get(x, -999)
            free = flat and x not in busy and (x, r - 1) not in tiles
            if not free:
                x += 1
                continue
            roll = rnd.random()
            if roll < 0.14 and r - room > 5 and all((x, r - k) not in tiles for k in (1, 2, 3)):
                # Tall tree: trunk, then two of leaves
                tiles[(x, r - 1)] = (src, 2, 5)
                tiles[(x, r - 2)] = (src, 2, 4)
                tiles[(x, r - 3)] = (src, 2, 3)
                x += rnd.randint(4, 9)
            elif roll < 0.24 and r - room > 2:
                tiles[(x, r - 1)] = (src, 3, 5)  # small tree
                x += rnd.randint(3, 6)
            elif roll < 0.55:
                tiles[(x, r - 1)] = (src, rnd.choice([3, 3, 6, 6, 4, 5]), 6)  # flowers, bush, pebble, rock
                x += rnd.randint(2, 5)
            elif roll < 0.61:
                tiles[(x, r - 1)] = (src, 4, 5)  # stump
                x += rnd.randint(3, 6)
            else:
                x += 1
        # Vines hanging under floating platforms now and then
        for x0, x1, row in self.platforms:
            if rnd.random() < 0.35:
                vx = rnd.randint(x0, x1)
                if (vx, row + 1) not in tiles and (vx, row + 2) not in tiles:
                    tiles[(vx, row + 1)] = (src, 1, 3)
                    tiles[(vx, row + 2)] = (src, 1, 5)

    def write(self, path):
        tiles = self.render_tiles()
        # The ground gets darker the deeper it goes: deeper rows go in their
        # own (tinted) layers
        layers = {"TileMapLayer": {}, "Deep": {}, "Deeper": {}}
        for pos, tile in tiles.items():
            d = self.depth.get(pos, 0)
            layers["TileMapLayer" if d < 2 else ("Deep" if d < 5 else "Deeper")][pos] = tile
        def encode(layer_tiles):
            data = bytearray(struct.pack("<H", 0))
            for (x, y), (src, ax, ay) in sorted(layer_tiles.items()):
                data += struct.pack("<hhHHHH", x, y, src, ax, ay, 0)
            return base64.b64encode(bytes(data)).decode()
        uid = f' uid="{self.uid}"' if self.uid else ""
        scenes = {
            "background": f"res://race/backgrounds/{self.background}.tscn",
            "race_finish": "res://race/finish_line.tscn",
            "checkpoint": "res://race/checkpoint.tscn",
            "spikes": "res://race/hazards/spikes.tscn",
            "saw": "res://race/hazards/saw.tscn",
            "falling": "res://race/hazards/falling_platform.tscn",
            "moving": "res://race/hazards/moving_platform.tscn",
            "retractable": "res://race/hazards/retractable_spikes.tscn",
            "trap_door": "res://race/hazards/trap_door.tscn",
            "crusher": "res://race/hazards/crusher.tscn",
            "fan": "res://race/hazards/fan.tscn",
            "button": "res://race/hazards/trap_button.tscn",
            "slime": "res://race/enemies/slime.tscn",
            "spiky": "res://race/enemies/spiky.tscn",
            "bat": "res://race/enemies/bat.tscn",
            "frog": "res://race/enemies/frog.tscn",
            "ghost": "res://race/enemies/ghost.tscn",
            "bee": "res://race/enemies/bee.tscn",
            "fireball": "res://race/enemies/fireball.tscn",
            "penguin": "res://race/enemies/penguin.tscn",
            "ice": "res://race/hazards/ice_zone.tscn",
            "item_box": "res://race/powerups/item_box.tscn",
            "torch": "res://race/decor/torch.tscn",
            "banner": "res://race/decor/banner.tscn",
            "lava": "res://race/hazards/lava.tscn",
        }
        tile_textures = {"snow": "nature_snow.png", "volcano": "nature_volcano.png"}
        # The ground takes the light of its sky (night is bluish, sunset warm...)
        tints = {"night": "Color(0.62, 0.68, 0.95, 1)", "sunset": "Color(1, 0.86, 0.8, 1)",
                 "cave": "Color(0.8, 0.76, 0.82, 1)", "castle": "Color(0.78, 0.72, 0.92, 1)",
                 "volcano": "Color(1, 0.9, 0.86, 1)"}
        root_extra = self.root_extra + (f"ground_tint = {tints[self.background]}\n" if self.background in tints else "")
        ext = [
            '[ext_resource type="Script" path="res://race/level.gd" id="race_level"]',
        ] + ([f'[ext_resource type="Texture2D" path="res://resources/{tile_textures[self.style]}" id="platform_tex"]']
             if self.style in tile_textures else []) + [
            '[ext_resource type="Script" path="res://race/kill_zone.gd" id="race_kill"]',
            '[ext_resource type="Script" path="res://race/hazards/balloon_column.gd" id="column"]',
            '[ext_resource type="TileSet" path="res://resources/level_tileset.tres" id="level_tileset"]',
            '[ext_resource type="PackedScene" uid="uid://bfsx5wh40fsn8" path="res://Enemies/Cannon/cannon.tscn" id="cannon"]',
            '[ext_resource type="PackedScene" uid="uid://d2l5myn53o5qe" path="res://collectables/coin.tscn" id="coin"]',
        ] + [f'[ext_resource type="PackedScene" path="{p}" id="{i}"]' for i, p in scenes.items()
             if i in ("background", "race_finish") or f'ExtResource("{i}")' in "".join(self.nodes + self.decor_nodes)]
        # Kill zones: one under each gap, plus a big one under everything
        lowest = max(self.surface.values())
        cols = sorted(self.surface)
        width = (cols[-1] - cols[0] + 40) * T
        kills = self.kill_zones + [((cols[0] + cols[-1]) * T / 2, (lowest + 25) * T, width)]
        subs = [f'''[sub_resource type="RectangleShape2D" id="Kill{i}"]
size = Vector2({w}, 32)''' for i, (_, _, w) in enumerate(kills)]
        kill_nodes = [f'''[node name="Kill{i}" type="Area2D" parent="KillZones"]
position = Vector2({x}, {y})
collision_layer = 0
script = ExtResource("race_kill")
pit = true

[node name="CollisionShape2D" type="CollisionShape2D" parent="KillZones/Kill{i}"]
shape = SubResource("Kill{i}")''' for i, (x, y, _) in enumerate(kills)]
        points = []
        for (x, y) in self.course:
            points += ["0", "0", "0", "0", str(x), str(y)]
        hazards = [n for n in self.nodes if 'parent="Hazards"' in n]
        coins = [n for n in self.nodes if 'parent="Coins"' in n]
        others = [n for n in self.nodes if n not in hazards and n not in coins]
        spawn = (40, self.surface[0] * T - 2)
        finish = (self.finish_col * T, self.surface[self.finish_col] * T)
        out = f'''[gd_scene format=4{uid}]

{chr(10).join(ext)}

{chr(10).join(subs)}

[sub_resource type="Curve2D" id="Curve2D_course"]
_data = {{
"points": PackedVector2Array({", ".join(points)})
}}
point_count = {len(self.course)}

[node name="{self.name}" type="Node2D"]
script = ExtResource("race_level")
{root_extra}{'platform_texture = ExtResource("platform_tex")' + chr(10) if self.style in tile_textures else ''}
[node name="Background" parent="." instance=ExtResource("background")]

[node name="Spawn" type="Marker2D" parent="." groups=["spawn"]]
position = Vector2({spawn[0]}, {spawn[1]})

[node name="Course" type="Path2D" parent="."]
visible = false
curve = SubResource("Curve2D_course")

[node name="Deeper" type="TileMapLayer" parent="."]
modulate = Color(0.62, 0.6, 0.68, 1)
tile_map_data = PackedByteArray("{encode(layers["Deeper"])}")
tile_set = ExtResource("level_tileset")

[node name="Deep" type="TileMapLayer" parent="."]
modulate = Color(0.8, 0.78, 0.84, 1)
tile_map_data = PackedByteArray("{encode(layers["Deep"])}")
tile_set = ExtResource("level_tileset")

[node name="TileMapLayer" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray("{encode(layers["TileMapLayer"])}")
tile_set = ExtResource("level_tileset")

[node name="Hazards" type="Node2D" parent="."]

[node name="Coins" type="Node2D" parent="."]

[node name="KillZones" type="Node2D" parent="."]

[node name="Decor" type="Node2D" parent="."]

{chr(10).join(n + chr(10) for n in hazards + coins + others + self.decor_nodes)}
{chr(10).join(k + chr(10) for k in kill_nodes)}
[node name="FinishLine" parent="." instance=ExtResource("race_finish")]
position = Vector2({finish[0]}, {finish[1]})
'''
        open(path, "w").write(out)
        print(path, "columns", len(self.surface), "tiles", len(tiles), "course points", len(self.course))
