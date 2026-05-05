extends Node

const ASSET_ROOT := "res://assets/Taxi"
const SOURCE_SIZE := Vector2(3600, 2000)
const TARGET_VIEWPORT_SIZE := Vector2(1152, 648)
const EXTERIOR_SKY_PATH := "res://assets/Taxi/Exterior/exterior_sky_night.png"
const EXTERIOR_SIDE_PATH := "res://assets/Taxi/Exterior/exterior_side_loop.png"
const EXTERIOR_ROAD_PATH := "res://assets/Taxi/Exterior/exterior_rear_road.png"
const SIDE_TILE_WIDTH := 1600.0

const LAYERS := [
	{"name": "Sky", "path": "", "z": -100, "amp": Vector2.ZERO, "phase": 0.0},
	{"name": "RoadStreaks", "path": "", "z": -90, "amp": Vector2.ZERO, "phase": 0.0},
	{"name": "BackSeat", "path": "後景_車後座.png", "z": 0, "amp": Vector2(5.0, 4.0), "phase": 0.0},
	{"name": "FrontSeat", "path": "中景_前座椅.png", "z": 10, "amp": Vector2(8.0, 6.0), "phase": 0.7},
	{"name": "Fox", "path": "前景_狐.png", "z": 20, "amp": Vector2(10.0, 8.0), "phase": 1.2},
	{"name": "FoxAlt", "path": "前景_狐2.png", "z": 21, "amp": Vector2(10.0, 8.0), "phase": 1.2},
	{"name": "FoxBelt", "path": "前景_狐2_belt.png", "z": 22, "amp": Vector2(9.0, 7.0), "phase": 1.0},
	{"name": "CharmRoot", "path": "前景_御守_root.png", "z": 30, "amp": Vector2(7.0, 5.0), "phase": 0.4},
	{"name": "CharmCord", "path": "前景_御守.png", "z": 31, "amp": Vector2(11.0, 7.0), "phase": 1.8},
	{"name": "CharmDown", "path": "前景_御守_down.png", "z": 32, "amp": Vector2(13.0, 9.0), "phase": 2.1},
	{"name": "CarFrame", "path": "車框.png", "z": 40, "amp": Vector2(6.0, 4.5), "phase": 0.2}
]

var root_2d: Node2D
var selected_context := {}
var selected_background_id := ""
var layer_nodes := []
var streak_nodes := []
var exterior_sprite_nodes := []
var side_scenery_nodes := []
var rear_road_mark_nodes := []
var sky_rect: ColorRect
var elapsed := 0.0
var viewport_size := TARGET_VIEWPORT_SIZE
var fit_scale := 1.0
var fit_origin := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var bump_timer := 0.0
var bump_duration := 0.0
var bump_elapsed := 0.0
var bump_strength := 0.0


func setup(world_root: Node2D, context: Dictionary, _content_defs: Array = [], _content_unlocks: Array = [], background_id: String = "") -> void:
	root_2d = world_root
	selected_context = context
	selected_background_id = background_id
	rng.randomize()
	_schedule_next_bump()
	get_viewport().size_changed.connect(fit_to_viewport)
	_build_scene()
	fit_to_viewport()


func set_content_state(_content_defs: Array, _content_unlocks: Array) -> void:
	pass


func set_selected_background(background_id: String) -> void:
	selected_background_id = background_id


func load_selected_background() -> void:
	_apply_context_tint()


func fit_to_viewport() -> void:
	viewport_size = Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = TARGET_VIEWPORT_SIZE
	fit_scale = max(viewport_size.x / SOURCE_SIZE.x, viewport_size.y / SOURCE_SIZE.y) * 1.02
	fit_origin = viewport_size * 0.5
	if sky_rect != null:
		sky_rect.size = viewport_size
	_fit_exterior_nodes()
	for entry in layer_nodes:
		var sprite: Sprite2D = entry.get("node")
		if sprite == null:
			continue
		sprite.scale = Vector2.ONE * fit_scale
		sprite.position = fit_origin
	_update_streak_layout()


func _process(delta: float) -> void:
	elapsed += delta
	var bump := _update_road_bump(delta)
	var road_hum := Vector2(
		(sin(elapsed * 1.7) * 0.27 + sin(elapsed * 2.9) * 0.12) * fit_scale,
		(sin(elapsed * 1.35) * 0.21 + sin(elapsed * 2.2) * 0.09) * fit_scale
	)
	for entry in layer_nodes:
		var sprite: Sprite2D = entry.get("node")
		if sprite == null:
			continue
		var breath: float = _get_breath_amount() if bool(entry.get("breathing", false)) else 0.0
		sprite.scale = Vector2(
			fit_scale * (1.0 + breath * 0.28),
			fit_scale * (1.0 + breath)
		)
		if bool(entry.get("fixed", false)):
			sprite.position = fit_origin
			sprite.rotation = 0.0
			continue
		var amp: Vector2 = entry.get("amp", Vector2.ZERO) * fit_scale
		var phase := float(entry.get("phase", 0.0))
		sprite.position = fit_origin + Vector2(
			amp.x * 0.08 * sin(elapsed * 1.8 + phase) + road_hum.x,
			amp.y * 0.06 * sin(elapsed * 2.1 + phase) + road_hum.y + bump
		)
		sprite.rotation = deg_to_rad(0.035 * sin(elapsed * 1.6 + phase) + bump * 0.012)
		if str(entry.get("name", "")) == "CharmCord" or str(entry.get("name", "")) == "CharmDown":
			sprite.rotation += deg_to_rad(0.8 * sin(elapsed * 2.4 + phase) + bump * 0.08)
	_update_exterior(delta, road_hum, bump)
	_update_streaks(delta)


func _schedule_next_bump() -> void:
	bump_timer = rng.randf_range(20.0, 40.0)
	bump_duration = rng.randf_range(0.16, 0.28)
	bump_elapsed = 0.0
	bump_strength = rng.randf_range(2.5, 5.5)


func _get_breath_amount() -> float:
	var cycle: float = sin(elapsed * 1.45 - PI * 0.5) * 0.5 + 0.5
	var eased: float = cycle * cycle * (3.0 - 2.0 * cycle)
	return eased * 0.009


func _update_road_bump(delta: float) -> float:
	if bump_elapsed > 0.0:
		bump_elapsed += delta
		var t: float = clamp(bump_elapsed / bump_duration, 0.0, 1.0)
		if t >= 1.0:
			bump_elapsed = 0.0
			_schedule_next_bump()
			return 0.0
		var impact: float = sin(t * PI) * sin(t * PI * 2.0)
		return impact * bump_strength * fit_scale

	bump_timer -= delta
	if bump_timer <= 0.0:
		bump_elapsed = delta
	return 0.0


func _build_scene() -> void:
	for child in root_2d.get_children():
		child.queue_free()
	layer_nodes.clear()
	streak_nodes.clear()
	exterior_sprite_nodes.clear()
	side_scenery_nodes.clear()
	rear_road_mark_nodes.clear()
	_build_sky()
	_build_exterior()
	_build_streaks()
	for definition in LAYERS:
		var path := str(definition.get("path", ""))
		if path == "":
			continue
		var sprite := Sprite2D.new()
		sprite.name = str(definition.get("name", "TaxiLayer"))
		sprite.texture = _load_texture("%s/%s" % [ASSET_ROOT, path])
		sprite.centered = true
		sprite.z_index = int(definition.get("z", 0))
		if sprite.name == "FoxAlt":
			sprite.visible = false
		root_2d.add_child(sprite)
		layer_nodes.append({
			"node": sprite,
			"name": sprite.name,
			"amp": definition.get("amp", Vector2.ZERO),
			"phase": definition.get("phase", 0.0),
			"fixed": sprite.name == "FrontSeat",
			"breathing": sprite.name == "Fox" or sprite.name == "FoxAlt"
		})


func _build_sky() -> void:
	sky_rect = ColorRect.new()
	sky_rect.name = "TaxiSky"
	sky_rect.color = Color(0.64, 0.55, 0.5, 1.0)
	sky_rect.z_index = -100
	root_2d.add_child(sky_rect)


func _build_exterior() -> void:
	_add_exterior_sprite("ExteriorSky", EXTERIOR_SKY_PATH, -99, SOURCE_SIZE * 0.5)
	_add_exterior_sprite("ExteriorRearRoad", EXTERIOR_ROAD_PATH, -97, SOURCE_SIZE * 0.5)
	for side in [-1.0, 1.0]:
		var base_x := 520.0 if side < 0.0 else 3080.0
		for i in range(3):
			var sprite := _add_exterior_sprite(
				"ExteriorSide%d_%d" % [int(side), i],
				EXTERIOR_SIDE_PATH,
				-98,
				Vector2(base_x + (float(i) - 1.0) * SIDE_TILE_WIDTH, 770.0)
			)
			side_scenery_nodes.append({
				"node": sprite,
				"side": side,
				"x": base_x + (float(i) - 1.0) * SIDE_TILE_WIDTH,
				"base_x": base_x,
				"base_y": 770.0,
				"phase": float(i) * 0.8
			})
	for i in range(18):
		var line := Line2D.new()
		line.name = "ExteriorRoadMark%d" % i
		line.z_index = -96
		line.width = 3.0
		line.default_color = Color(1.0, 0.92, 0.58, 0.52)
		root_2d.add_child(line)
		rear_road_mark_nodes.append({
			"node": line,
			"progress": float(i) / 18.0
		})


func _add_exterior_sprite(node_name: String, texture_path: String, z_index: int, source_position: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = _load_texture(texture_path)
	sprite.centered = true
	sprite.z_index = z_index
	root_2d.add_child(sprite)
	exterior_sprite_nodes.append({
		"node": sprite,
		"source_position": source_position
	})
	return sprite


func _fit_exterior_nodes() -> void:
	for entry in exterior_sprite_nodes:
		var sprite: Sprite2D = entry.get("node")
		if sprite == null:
			continue
		sprite.scale = Vector2.ONE * fit_scale
		sprite.position = _source_to_screen(entry.get("source_position", SOURCE_SIZE * 0.5))
	for entry in rear_road_mark_nodes:
		_set_rear_road_mark_points(entry)


func _update_exterior(delta: float, road_hum: Vector2, bump: float) -> void:
	for entry in exterior_sprite_nodes:
		var sprite: Sprite2D = entry.get("node")
		if sprite == null:
			continue
		var source_position: Vector2 = entry.get("source_position", SOURCE_SIZE * 0.5)
		sprite.position = _source_to_screen(source_position) + road_hum * 0.35 + Vector2(0.0, bump * 0.35)
		sprite.scale = Vector2.ONE * fit_scale
	for entry in side_scenery_nodes:
		var side := float(entry.get("side", 1.0))
		var x := float(entry.get("x", 0.0)) + side * 260.0 * delta
		var base_x := float(entry.get("base_x", 0.0))
		var limit := SIDE_TILE_WIDTH * 1.5
		if side < 0.0 and x < base_x - limit:
			x += SIDE_TILE_WIDTH * 3.0
		elif side > 0.0 and x > base_x + limit:
			x -= SIDE_TILE_WIDTH * 3.0
		entry.x = x
		var source_position := Vector2(
			x,
			float(entry.get("base_y", 770.0)) + sin(elapsed * 0.9 + float(entry.get("phase", 0.0))) * 6.0
		)
		entry.source_position = source_position
		var sprite: Sprite2D = entry.get("node")
		if sprite != null:
			sprite.position = _source_to_screen(source_position) + road_hum * 0.25
			sprite.scale = Vector2.ONE * fit_scale
	for entry in rear_road_mark_nodes:
		entry.progress = fposmod(float(entry.get("progress", 0.0)) + delta * 0.34, 1.0)
		_set_rear_road_mark_points(entry)


func _set_rear_road_mark_points(entry: Dictionary) -> void:
	var line: Line2D = entry.get("node")
	if line == null:
		return
	var progress := float(entry.get("progress", 0.0))
	var t0: float = progress
	var t1: float = min(progress + 0.08, 1.0)
	var start := _road_center_point(t0)
	var finish := _road_center_point(t1)
	line.width = lerp(2.0, 10.0, t0) * fit_scale
	line.default_color = Color(1.0, 0.92, 0.58, lerp(0.18, 0.68, t0))
	line.points = PackedVector2Array([
		_source_to_screen(start),
		_source_to_screen(finish)
	])


func _road_center_point(t: float) -> Vector2:
	var eased := t * t
	return Vector2(
		1800.0 + sin(t * PI * 2.0 + elapsed * 0.6) * lerp(8.0, 64.0, eased),
		lerp(650.0, 1980.0, eased)
	)


func _source_to_screen(source_position: Vector2) -> Vector2:
	return fit_origin + (source_position - SOURCE_SIZE * 0.5) * fit_scale


func _build_streaks() -> void:
	for i in range(16):
		var line := Line2D.new()
		line.name = "TaxiRoadStreak%d" % i
		line.z_index = -90
		line.width = 1.6 + float(i % 3) * 0.6
		line.default_color = Color(1.0, 0.88, 0.48, 0.14 + 0.05 * float(i % 2))
		root_2d.add_child(line)
		streak_nodes.append({
			"node": line,
			"side": -1.0 if i % 2 == 0 else 1.0,
			"speed": 0.42 + 0.035 * float(i % 6),
			"progress": 0.0,
			"lane": float(i / 2),
			"length": 110.0 + 20.0 * float(i % 4)
		})


func _update_streak_layout() -> void:
	for i in range(streak_nodes.size()):
		var entry = streak_nodes[i]
		entry.progress = fposmod(float(i) * 0.13, 1.0)
		_set_streak_points(entry)


func _update_streaks(delta: float) -> void:
	for entry in streak_nodes:
		entry.progress = float(entry.progress) + float(entry.speed) * delta
		if float(entry.progress) > 1.0:
			entry.progress = 0.0
		_set_streak_points(entry)


func _set_streak_points(entry: Dictionary) -> void:
	var line: Line2D = entry.get("node")
	if line == null:
		return
	var side := float(entry.get("side", 1.0))
	var progress := float(entry.get("progress", 0.0))
	var lane := float(entry.get("lane", 0.0))
	var length: float = float(entry.get("length", 120.0)) * fit_scale
	var eased: float = progress * progress
	var start_x: float = viewport_size.x * (0.47 + side * (0.08 + 0.015 * fmod(lane, 4.0)))
	var end_x: float = viewport_size.x * (0.08 if side < 0.0 else 0.92)
	var start_y: float = viewport_size.y * (0.34 + 0.018 * fmod(lane, 5.0))
	var end_y: float = viewport_size.y * (0.72 + 0.025 * fmod(lane, 4.0))
	var x: float = lerp(start_x, end_x, eased)
	var y: float = lerp(start_y, end_y, eased) + sin(elapsed * 5.0 + lane) * 1.5 * fit_scale
	var tail := Vector2(side * length * (0.75 + progress), length * 0.22)
	line.points = PackedVector2Array([
		Vector2(x, y),
		Vector2(x + tail.x, y + tail.y)
	])


func _apply_context_tint() -> void:
	if sky_rect == null:
		return
	var time := str(selected_context.get("time", "day"))
	var weather := str(selected_context.get("weather", "clear"))
	if weather == "rain":
		sky_rect.color = Color(0.32, 0.34, 0.39, 1.0)
	elif time == "night":
		sky_rect.color = Color(0.07, 0.09, 0.16, 1.0)
	elif time == "sunfall":
		sky_rect.color = Color(0.58, 0.36, 0.32, 1.0)
	else:
		sky_rect.color = Color(0.64, 0.55, 0.5, 1.0)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null
