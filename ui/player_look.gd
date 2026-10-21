class_name PlayerLook extends RefCounted

## The knight's animations and coloring, for showing players outside the
## race (start screen, podium) the same way they look in it

const COLORS_SHADER = preload("res://scenes/player_colors.gdshader")

static var _frames: SpriteFrames

## The racers' animations, read from the player scene without creating one
static func frames() -> SpriteFrames:
	if _frames == null:
		var state = (load("res://scenes/player.tscn") as PackedScene).get_state()
		for node in state.get_node_count():
			for i in state.get_node_property_count(node):
				if state.get_node_property_name(node, i) == "sprite_frames":
					_frames = state.get_node_property_value(node, i)
	return _frames

## Paints a knight sprite in a player's color (see player_colors.gdshader)
static func paint(sprite: CanvasItem, color: Color) -> void:
	if not sprite.material is ShaderMaterial:
		sprite.material = ShaderMaterial.new()
		sprite.material.shader = COLORS_SHADER
	sprite.material.set_shader_parameter("main_color", color)
	sprite.material.set_shader_parameter("light_color", color.lightened(0.45))

## A knight in a player's color, ready to add to the scene
static func knight(color: Color, animation := "idle") -> AnimatedSprite2D:
	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames()
	paint(sprite, color)
	sprite.play(animation)
	return sprite
