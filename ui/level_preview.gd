class_name LevelPreview extends TextureRect

## Tiny map of a whole level (its ups and downs) for the level picker. Built
## from the level's tiles without creating the level, and cached.

## Pixels of the map per tile, in tiles (3 = one pixel every 3x3 tiles)
const SCALE = 3
# Ground color by tile source (see level_tileset.tres)
const GROUND = {0: Color("#9b948c"), 4: Color("#5aa54a"), 5: Color("#eef4ff"), 6: Color("#5a3438")}
const SURFACE = {0: Color("#c9c2b6"), 4: Color("#8be06a"), 5: Color("#ffffff"), 6: Color("#ff8a2e")}

# Sky color by background theme (else the level's background_color)
const SKIES = {"day": Color("#7ec0ee"), "sunset": Color("#e98a6a"), "sky": Color("#7dbfe6"),
	"night": Color("#1d2147"), "cave": Color("#2a2224"), "forest": Color("#73aed9"),
	"snow": Color("#bcd6ef"), "volcano": Color("#5a1c16"), "castle": Color("#2c1a40")}

static var _cache = {}

func show_level(scene: PackedScene) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	if not _cache.has(scene.resource_path):
		_cache[scene.resource_path] = _build(scene)
	texture = _cache[scene.resource_path]

static func _build(scene: PackedScene) -> Texture2D:
	var state = scene.get_state()
	var sky = Color(0.3, 0.3, 0.3)
	var data := PackedByteArray()
	for node in state.get_node_count():
		var instance = state.get_node_instance(node)
		if instance and state.get_node_name(node) == "Background":
			sky = SKIES.get(instance.resource_path.get_file().get_basename(), sky)
		for i in state.get_node_property_count(node):
			var property = state.get_node_property_name(node, i)
			if node == 0 and property == "background_color" and sky == Color(0.3, 0.3, 0.3):
				sky = state.get_node_property_value(node, i)
			elif property == "tile_map_data":
				# All the tile layers (ground, deeper ground...), header skipped
				var layer: PackedByteArray = state.get_node_property_value(node, i)
				data.append_array(layer.slice(2) if not data.is_empty() else layer)
	# tile_map_data: 2 bytes of header, then 12 bytes per cell:
	# x, y (int16), source, atlas x, atlas y, alternative (uint16)
	var cells = {}
	var sources = {}
	var rect = Rect2i()
	for offset in range(2, data.size() - 11, 12):
		var cell = Vector2i(data.decode_s16(offset), data.decode_s16(offset + 2))
		var source = data.decode_u16(offset + 4)
		var block = cell / SCALE
		cells[block] = source
		sources[source] = sources.get(source, 0) + 1
		rect = Rect2i(block, Vector2i.ONE) if rect.size == Vector2i.ZERO else rect.expand(block).expand(block + Vector2i.ONE)
	if cells.is_empty():
		var empty = Image.create(4, 2, false, Image.FORMAT_RGBA8)
		empty.fill(sky)
		return ImageTexture.create_from_image(empty)
	var main_source = sources.keys().reduce(func(a, b): return a if sources[a] >= sources[b] else b)
	var ground = GROUND.get(main_source, Color.GRAY)
	var surface = SURFACE.get(main_source, Color.WHITE)
	var image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	image.fill(sky.lerp(Color.WHITE, 0.15))
	for block in cells:
		var p = block - rect.position
		var top = not cells.has(block + Vector2i.UP)
		image.set_pixelv(p, surface if top else ground)
	return ImageTexture.create_from_image(image)
