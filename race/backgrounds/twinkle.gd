extends Parallax2D

## Makes a layer (like the stars) fade in and out slowly

@export var speed := 1.5
@export var phase := 0.0
@export var min_alpha := 0.35

func _process(_delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0 * speed + phase
	modulate.a = lerpf(min_alpha, 1.0, 0.5 + 0.5 * sin(t))
