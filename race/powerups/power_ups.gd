class_name PowerUps extends RefCounted

## The power-ups you get from item boxes: names, how likely each one is
## depending on your place in the race (the further back, the better), and
## how their icons are drawn.

const PEEL = "peel"
const SHIELD = "shield"
const TURBO = "turbo"
const STAR = "star"
const LIGHTNING = "lightning"
const PORTAL = "portal"
const WINGS = "wings"
const ROCKET = "rocket"
const INK = "ink"

const NAMES = {
	PEEL: "Cáscara", SHIELD: "Escudo", TURBO: "Turbo",
	STAR: "Estrella", LIGHTNING: "Rayo", PORTAL: "Portal",
	WINGS: "Alas", ROCKET: "Cohete", INK: "Tinta",
}
const HINTS = {
	PEEL: "la dejás atrás y el que la pisa resbala",
	SHIELD: "te salva de una trampa o un enemigo",
	TURBO: "corrés mucho más rápido un rato",
	STAR: "nada te lastima y corrés más rápido",
	LIGHTNING: "frena a todos los que van adelante tuyo",
	PORTAL: "te lleva a la próxima bandera",
	WINGS: "podés saltar otra vez en el aire",
	ROCKET: "marea al que va justo adelante tuyo",
	INK: "les mancha la pantalla a los que van adelante",
}
## Chances [when you're first, when you're last]; in between they blend
const WEIGHTS = {
	PEEL: [40.0, 0.0],
	SHIELD: [35.0, 5.0],
	TURBO: [20.0, 30.0],
	STAR: [5.0, 25.0],
	LIGHTNING: [0.0, 20.0],
	PORTAL: [0.0, 20.0],
	WINGS: [15.0, 10.0],
	ROCKET: [5.0, 20.0],
	INK: [5.0, 15.0],
}

## Effects (seconds) and how much faster or slower they make you
const TURBO_TIME = 2.5
const TURBO_SPEED = 1.6
const STAR_TIME = 5.0
const STAR_SPEED = 1.25
const LIGHTNING_TIME = 3.0
const LIGHTNING_SPEED = 0.65
const STUN_TIME = 1.2
const WINGS_TIME = 8.0
const INK_TIME = 4.0

## place: 0 = first, 1 = last
static func pick(place: float, rng: RandomNumberGenerator = null) -> String:
	var total := 0.0
	var weights = {}
	for item in WEIGHTS:
		var w = lerpf(WEIGHTS[item][0], WEIGHTS[item][1], clampf(place, 0.0, 1.0))
		weights[item] = w
		total += w
	var roll = (rng.randf() if rng else randf()) * total
	for item in weights:
		roll -= weights[item]
		if roll <= 0.0:
			return item
	return TURBO

static func draw_icon(canvas: CanvasItem, item: String, center: Vector2, size: float) -> void:
	var s = size / 16.0
	var outline = Color(0.17, 0.11, 0.23)
	match item:
		PEEL:
			# A banana: thick yellow curve with brown tips
			var c = center + Vector2(0, -3) * s
			canvas.draw_arc(c, 5.5 * s, PI * 0.12, PI * 0.88, 10, outline, 5.0 * s)
			canvas.draw_arc(c, 5.5 * s, PI * 0.15, PI * 0.85, 10, Color("#ffe14a"), 3.2 * s)
			canvas.draw_circle(c + Vector2(cos(PI * 0.12), sin(PI * 0.12)) * 5.5 * s, 1.3 * s, Color("#6b4a1f"))
			canvas.draw_circle(c + Vector2(cos(PI * 0.88), sin(PI * 0.88)) * 5.5 * s, 1.3 * s, Color("#6b4a1f"))
		SHIELD:
			canvas.draw_circle(center, 7 * s, Color(0.45, 0.8, 1.0, 0.45))
			canvas.draw_arc(center, 7 * s, 0, TAU, 20, Color("#7fd8ff"), 2.0)
			canvas.draw_arc(center, 4.5 * s, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.9), 1.5)
		TURBO:
			var body = PackedVector2Array([center + Vector2(-6, 2) * s, center + Vector2(3, -6) * s,
				center + Vector2(6, -3) * s, center + Vector2(-3, 5) * s])
			canvas.draw_colored_polygon(body, Color("#e0e6f0"))
			canvas.draw_polyline(body + PackedVector2Array([body[0]]), outline, 1.0)
			canvas.draw_circle(center + Vector2(4.5, -4.5) * s, 2 * s, Color("#ff5e5b"))
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 3) * s, center + Vector2(-8, 7) * s,
				center + Vector2(-3, 4.5) * s]), Color("#ff9f1c"))
		STAR:
			var points = PackedVector2Array()
			for i in 10:
				var r = (7.5 if i % 2 == 0 else 3.2) * s
				var a = -PI / 2.0 + i * PI / 5.0
				points.append(center + Vector2(cos(a), sin(a)) * r)
			canvas.draw_colored_polygon(points, Color("#ffd23f"))
			canvas.draw_polyline(points + PackedVector2Array([points[0]]), outline, 1.0)
			canvas.draw_rect(Rect2(center + Vector2(-2, -1) * s, Vector2(1, 2) * s), outline)
			canvas.draw_rect(Rect2(center + Vector2(1, -1) * s, Vector2(1, 2) * s), outline)
		LIGHTNING:
			var bolt = PackedVector2Array([center + Vector2(1, -8) * s, center + Vector2(-5, 1) * s,
				center + Vector2(-1, 1) * s, center + Vector2(-3, 8) * s, center + Vector2(5, -2) * s,
				center + Vector2(1, -2) * s])
			canvas.draw_colored_polygon(bolt, Color("#fff36b"))
			canvas.draw_polyline(bolt + PackedVector2Array([bolt[0]]), outline, 1.0)
		PORTAL:
			canvas.draw_circle(center, 7 * s, Color("#a86cf5"))
			canvas.draw_circle(center, 5 * s, Color("#3bceac"))
			canvas.draw_circle(center, 3 * s, Color("#1d1530"))
			canvas.draw_arc(center, 7 * s, 0, TAU, 20, outline, 1.0)
		WINGS:
			# Two feathered wings and a little body between them
			for side in [-1.0, 1.0]:
				var wing = PackedVector2Array([center + Vector2(side * 1, 1) * s, center + Vector2(side * 4, -6) * s,
					center + Vector2(side * 8, -4) * s, center + Vector2(side * 7, 0) * s, center + Vector2(side * 5, 4) * s])
				canvas.draw_colored_polygon(wing, Color("#f4f7ff"))
				canvas.draw_polyline(wing + PackedVector2Array([wing[0]]), outline, 1.0)
				canvas.draw_line(center + Vector2(side * 3, -1) * s, center + Vector2(side * 6, -3) * s, Color("#a9c4f5"), 1.0)
			canvas.draw_circle(center + Vector2(0, 1) * s, 2.2 * s, Color("#ffd23f"))
		ROCKET:
			# A red rocket pointing forward, with a flame
			var hull = PackedVector2Array([center + Vector2(-5, -3) * s, center + Vector2(3, -3) * s, center + Vector2(8, 0) * s,
				center + Vector2(3, 3) * s, center + Vector2(-5, 3) * s])
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -1.5) * s, center + Vector2(-9, 0) * s,
				center + Vector2(-5, 1.5) * s]), Color("#ff9f1c"))
			canvas.draw_colored_polygon(hull, Color("#ff5e5b"))
			canvas.draw_polyline(hull + PackedVector2Array([hull[0]]), outline, 1.0)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -3) * s, center + Vector2(-7, -6) * s,
				center + Vector2(-2, -3) * s]), outline)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 3) * s, center + Vector2(-7, 6) * s,
				center + Vector2(-2, 3) * s]), outline)
			canvas.draw_circle(center + Vector2(2, 0) * s, 1.6 * s, Color("#e8fbff"))
		INK:
			# A splat of ink with a shine (and a light edge, to stand out on dark)
			for pass_color in [Color("#b9a7ff"), outline]:
				var grow = 0.9 * s if pass_color != outline else 0.0
				canvas.draw_circle(center, 5 * s + grow, pass_color)
				for k in 6:
					var a = k * TAU / 6.0 + 0.3
					canvas.draw_circle(center + Vector2(cos(a), sin(a)) * 6 * s, (1.6 if k % 2 == 0 else 2.4) * s + grow, pass_color)
			canvas.draw_circle(center + Vector2(-2, -2) * s, 1.4 * s, Color("#6c5ce7"))

