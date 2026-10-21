class_name Hud extends CanvasLayer

@onready var race_track: RaceTrack = $RaceTrack
@onready var position_label: Label = $PositionLabel
@onready var toast: Label = $Toast

const TOAST_TIME = 2.5
var _toast_left := 0.0

var _flash: ColorRect
var _badge: PlaceBadge
var _flags_level: Node

func _ready() -> void:
	RaceManager.trap_triggered.connect(_on_trap_triggered)
	RaceManager.item_used.connect(_on_item_used)
	toast.text = ""
	toast.add_theme_stylebox_override("normal", pill())
	toast.add_theme_color_override("font_outline_color", Color(0.17, 0.11, 0.23))
	add_child(ItemSlot.new())
	add_child(RaceBanner.new())
	_badge = PlaceBadge.new()
	_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_badge.position = Vector2(10, get_viewport().get_visible_rect().size.y - 58)
	_badge.size = Vector2(200, 50)
	add_child(_badge)
	position_label.visible = false
	# White flash when someone's lightning hits you
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 0.85, 0)
	add_child(_flash)

func _on_item_used(id: int, item: String) -> void:
	var me = multiplayer.get_unique_id()
	var sounds = {PowerUps.TURBO: "turbo", PowerUps.STAR: "star", PowerUps.SHIELD: "item_box",
		PowerUps.LIGHTNING: "zap", PowerUps.PORTAL: "portal", PowerUps.PEEL: "click"}
	if item == PowerUps.LIGHTNING:
		# Everyone hears the thunder; the ones it hit see the flash
		Sfx.play(sounds[item])
		if RaceManager.has_effect(me, "slow"):
			_flash.color.a = 0.7
			create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	elif id == me:
		Sfx.play(sounds[item])
	# Only the big ones are announced to everybody
	if id == me or item in [PowerUps.LIGHTNING, PowerUps.STAR, PowerUps.PORTAL]:
		var who = "¡Usaste" if id == me else "¡%s usó" % PlayersManager.name_of(id)
		toast.text = "%s %s! (%s)" % [who, PowerUps.NAMES[item], PowerUps.HINTS[item]]
		toast.add_theme_color_override("font_color", PlayersManager.color_of(id))
		_toast_left = TOAST_TIME

func _on_trap_triggered(id: int) -> void:
	var who = "Activaste" if id == multiplayer.get_unique_id() else "%s activó" % PlayersManager.name_of(id)
	toast.text = "⚠ %s una trampa más adelante" % who
	toast.add_theme_color_override("font_color", PlayersManager.color_of(id))
	_toast_left = TOAST_TIME

func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		toast.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)
	toast.visible = _toast_left > 0.0 and toast.text != ""
	fit_centered(toast)
	# Only shown while the local player is racing (not in the lobby)
	visible = is_connected_to_game(multiplayer) and not Standings.showing \
		and get_tree().get_nodes_in_group("player").any(func(p): return p.is_local())
	if !visible:
		return
	var ranking = get_ranking()
	_update_track_flags()
	race_track.entries = _track_entries()
	_update_position_label(ranking)

## Dark rounded tag behind on-screen messages, so they read on any background
static func pill() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.06, 0.15, 0.75)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	return style

## A label only as wide as its text, centered on the screen
static func fit_centered(label: Label) -> void:
	label.size.x = 0
	label.reset_size()
	label.position.x = (label.get_viewport_rect().size.x - label.size.x) / 2.0

static func is_connected_to_game(api: MultiplayerAPI) -> bool:
	return api.has_multiplayer_peer() \
		and api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

static func color_for(id: int) -> Color:
	return PlayersManager.color_of(id)

static func name_for(id: int) -> String:
	return PlayersManager.name_of(id)

## Players that finished keep their arrival order, the rest go by progress
func get_ranking() -> Array:
	var players = get_tree().get_nodes_in_group("player")
	players.sort_custom(func(a, b):
		var a_id = a.name.to_int()
		var b_id = b.name.to_int()
		var a_done = RaceManager.has_finished(a_id)
		var b_done = RaceManager.has_finished(b_id)
		if a_done and b_done:
			return RaceManager.finish_order.find(a_id) < RaceManager.finish_order.find(b_id)
		if a_done != b_done:
			return a_done
		return RaceManager.get_progress(a) > RaceManager.get_progress(b))
	return players

func _track_entries() -> Array:
	var entries = []
	for player in get_tree().get_nodes_in_group("player"):
		var id = player.name.to_int()
		entries.append({
			"progress": 1.0 if RaceManager.has_finished(id) else RaceManager.get_progress(player),
			"color": color_for(id),
			"is_local": player.is_local(),
		})
	# Draw the local player last so it stays on top
	entries.sort_custom(func(a, b): return !a.is_local and b.is_local)
	return entries

func _update_position_label(ranking: Array) -> void:
	var local_index = ranking.find_custom(func(p): return p.is_local())
	if local_index == -1:
		_badge.show_state(0, 0, 0, -1, 0, false)
		return
	var local_id = ranking[local_index].name.to_int()
	var coins = RaceManager.coins_of(local_id) if PlayersManager.coins_enabled() else -1
	# Only what the coins weigh (not turbos or lightning)
	var slowdown = roundi(minf(maxi(coins, 0) * RaceManager.COIN_SLOWDOWN, RaceManager.MAX_SLOWDOWN) * 100)
	_badge.position.y = get_viewport().get_visible_rect().size.y - 58
	_badge.show_state(local_index + 1, ranking.size(), PlayersManager.points_of(local_id), coins, slowdown,
		RaceManager.has_finished(local_id))

# Where the flags are along the course, worked out once per level
func _update_track_flags() -> void:
	var level = RaceManager.current_level
	if level == _flags_level:
		return
	_flags_level = level
	var flags = []
	if is_instance_valid(level) and PlayersManager.checkpoints_enabled():
		for flag in level.find_children("*", "Checkpoint", true, false):
			flags.append(RaceManager.get_progress(flag))
	race_track.flags = flags
