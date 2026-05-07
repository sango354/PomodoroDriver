extends Node

const TaxiStreetWorldController = preload("res://scripts/taxi_street_world_controller.gd")

const ASSET_ROOT := "res://assets/Taxi"
const SOURCE_SIZE := Vector2(3600, 2000)
const TARGET_VIEWPORT_SIZE := Vector2(1152, 648)

const LAYERS := [
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
var sky_rect: ColorRect
var street_viewport: SubViewport
var street_world_controller: Node
var street_sprite: Sprite2D
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


func trigger_sky_transition() -> void:
	if street_world_controller != null and street_world_controller.has_method("trigger_sky_transition"):
		street_world_controller.trigger_sky_transition()


func prepare_for_quit() -> void:
	set_process(false)
	if street_sprite != null:
		street_sprite.texture = null
		street_sprite.visible = false
	if street_viewport != null:
		street_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		for child in street_viewport.get_children():
			if child is Node:
				(child as Node).set_process(false)
				(child as Node).set_physics_process(false)
		street_viewport.queue_free()
		street_viewport = null
	street_world_controller = null
	street_sprite = null


func fit_to_viewport() -> void:
	viewport_size = Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = TARGET_VIEWPORT_SIZE
	fit_scale = max(viewport_size.x / SOURCE_SIZE.x, viewport_size.y / SOURCE_SIZE.y) * 1.02
	fit_origin = viewport_size * 0.5
	if sky_rect != null:
		sky_rect.size = viewport_size
	if street_viewport != null:
		street_viewport.size = Vector2i(int(ceil(viewport_size.x)), int(ceil(viewport_size.y)))
	if street_sprite != null:
		street_sprite.position = viewport_size * 0.5
		street_sprite.scale = Vector2.ONE
	for entry in layer_nodes:
		var sprite: Sprite2D = entry.get("node")
		if sprite == null:
			continue
		sprite.scale = Vector2.ONE * fit_scale
		sprite.position = fit_origin


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
	if street_viewport != null:
		street_viewport.queue_free()
		street_viewport = null
	street_world_controller = null
	street_sprite = null
	_build_sky()
	_build_exterior()
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
	street_viewport = SubViewport.new()
	street_viewport.name = "TaxiStreetViewport"
	street_viewport.disable_3d = false
	street_viewport.transparent_bg = false
	street_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	street_viewport.msaa_3d = Viewport.MSAA_4X
	street_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	street_viewport.size = Vector2i(int(TARGET_VIEWPORT_SIZE.x), int(TARGET_VIEWPORT_SIZE.y))
	add_child(street_viewport)

	street_world_controller = TaxiStreetWorldController.new()
	street_world_controller.name = "TaxiStreetWorld"
	street_viewport.add_child(street_world_controller)

	street_sprite = Sprite2D.new()
	street_sprite.name = "ExteriorStreet3D"
	street_sprite.texture = street_viewport.get_texture()
	street_sprite.centered = true
	street_sprite.z_index = -99
	root_2d.add_child(street_sprite)


func _update_exterior(delta: float, road_hum: Vector2, bump: float) -> void:
	if street_sprite == null:
		return
	street_sprite.position = viewport_size * 0.5 + road_hum * 0.35 + Vector2(0.0, bump * 0.25)


func _source_to_screen(source_position: Vector2) -> Vector2:
	return fit_origin + (source_position - SOURCE_SIZE * 0.5) * fit_scale


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
