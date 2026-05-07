extends Node3D

const GlbStaticLoader = preload("res://scripts/glb_static_loader.gd")

const MODEL_ROOT := "res://assets/Generated/JapaneseStreet3D"
const SKY_PANORAMA_PATHS := [
	"res://assets/Taxi/Exterior/sky_panorama.png",
	"res://assets/Taxi/Exterior/sky_afternoon.png",
	"res://assets/Taxi/Exterior/sky_night.png"
]
const DEFAULT_MAP_ID := "downtown_grid"
const DRIVE_SPEED := 2.6
const ROAD_WIDTH := 4.8
const SIDEWALK_WIDTH := 1.55
const BLOCK_CLEARANCE := 4.7
const PERIMETER_CLEARANCE := 4.9
const BUILDING_CENTER_DEPTH := 1.35
const PROP_OFFSET := 2.9
const BLOCK_HOUSE_SPACING := 5.65
const PERIMETER_HOUSE_SPACING := 5.95
const BLOCK_CORNER_MARGIN := 2.8
const PERIMETER_CORNER_MARGIN := 3.2
const BLOCK_INNER_MARGIN := 6.4
const BLOCK_INNER_SPACING := 6.35
const HOUSE_FOOTPRINT_RADIUS := 2.5
const INNER_HOUSE_FOOTPRINT_RADIUS := 2.65
const PERIMETER_FOOTPRINT_RADIUS := 2.65
const SIGN_FOOTPRINT_RADIUS := 1.15
const FOOTPRINT_PADDING := 0.35
const PERIMETER_BACK_ROW_OFFSET := 5.9
const PERIMETER_BACK_ROW_STAGGER := 0.5
const PROP_SPACING := 6.0
const GROUND_MARGIN := 42.0
const GROUND_TILE_SIZE := 16.0
const LOOK_AHEAD_DISTANCE := 14.0
const CAMERA_HEIGHT := 1.45
const CAMERA_TARGET_HEIGHT := 1.60
const SKY_TRANSITION_INTERVAL := 180.0
const SKY_TRANSITION_DURATION := 18.0
const SKY_DOME_RADIUS := 420.0
const SIDE_LOOK_OFFSET := 0.0
const TURN_RADIUS := 3.15
const TURN_LENGTH_MULTIPLIER := 2.35
const TURN_ACCEL_START := 0.45
const TURN_EXIT_SPEED_MULTIPLIER := 1.35
const TURN_CHANCE := 0.72
const DRIVE_MODE_STRAIGHT := 0
const DRIVE_MODE_TURN := 1
const MAP_LAYOUTS := {
	"countdown_grid": {
		"street_x": [-58.0, -30.0, 2.0, 37.0, 75.0],
		"street_z": [36.0, 8.0, -23.0, -57.0, -94.0, -134.0],
		"start": [0, 2],
		"target": [0, 1]
	},
	"downtown_grid": {
		"street_x": [-130.0, -92.0, -52.0, -10.0, 33.0, 78.0, 124.0],
		"street_z": [92.0, 54.0, 15.0, -27.0, -70.0, -114.0, -159.0, -205.0],
		"start": [0, 2],
		"target": [0, 1]
	}
}
const HOUSE_MODELS := [
	"AE_House_01.glb",
	"AE_House_02.glb",
	"AE_House_03.glb",
	"AE_House_04.glb",
	"AE_House_05.glb",
	"AE_House_06.glb",
	"AE_House_07.glb",
	"AE_House_08.glb",
	"AE_House_09.glb",
	"AE_House_10.glb",
	"AE_House_11.glb",
	"AE_House_12.glb"
]
const STREET_PROPS := [
	"AE_Electric_Post_01.glb",
	"AE_Electric_Post_02.glb",
	"AE_Electric_Post_03.glb",
	"AE_Traffic_Light_01.glb",
	"AE_Traffic_Light_02.glb",
	"AE_Signboards_01.glb",
	"AE_Signboards_02.glb",
	"AE_Signboards_03.glb",
	"AE_Street_Fence_01.glb",
	"AE_Fence_01.glb",
	"AE_Vending_Machine_01.glb",
	"AE_Vending_Machine_02.glb",
	"AE_Bicycle_01.glb",
	"AE_Scooter_01.glb",
	"AE_Flower_Pot_01.glb",
	"AE_Mailbox_01.glb"
]

var loader := GlbStaticLoader.new()
var camera: Camera3D
var rng := RandomNumberGenerator.new()
var active_map_id := DEFAULT_MAP_ID
var active_map := {}
var road_nodes := {}
var road_links := {}
var current_node_key := ""
var previous_node_key := ""
var target_node_key := ""
var segment_start := Vector2.ZERO
var segment_end := Vector2.ZERO
var segment_length := 1.0
var segment_progress := 0.0
var vehicle_position := Vector2.ZERO
var vehicle_direction := Vector2(0.0, -1.0)
var drive_mode := DRIVE_MODE_STRAIGHT
var turn_next_node_key := ""
var turn_entry := Vector2.ZERO
var turn_corner := Vector2.ZERO
var turn_exit := Vector2.ZERO
var turn_progress := 0.0
var turn_length := 1.0
var building_footprints := []
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment
var sky_textures := []
var sky_domes := []
var sky_materials := []
var sky_phase_index := 0
var sky_next_phase_index := 1
var sky_cycle_elapsed := 0.0
var sky_transition_elapsed := 0.0
var sky_transition_active := false


func _ready() -> void:
	rng.randomize()
	_load_active_map(active_map_id)
	_prepare_route()
	_build_world()


func _process(delta: float) -> void:
	_update_sky_cycle(delta)
	_advance_vehicle(delta)
	_update_camera()


func trigger_sky_transition() -> void:
	if sky_textures.size() < 2:
		return
	if sky_transition_active:
		return
	_start_sky_transition()


func set_active_map(map_id: String) -> void:
	if not MAP_LAYOUTS.has(map_id):
		return
	active_map_id = map_id
	_load_active_map(active_map_id)
	_prepare_route()
	if is_inside_tree():
		_clear_world()
		_build_world()


func _clear_world() -> void:
	building_footprints.clear()
	for child in get_children():
		remove_child(child)
		child.free()


func _load_active_map(map_id: String) -> void:
	active_map = MAP_LAYOUTS.get(map_id, MAP_LAYOUTS[DEFAULT_MAP_ID])


func _prepare_route() -> void:
	road_nodes.clear()
	road_links.clear()
	var street_x := _street_x_values()
	var street_z := _street_z_values()
	for x_index in range(street_x.size()):
		for z_index in range(street_z.size()):
			var key := _node_key(x_index, z_index)
			road_nodes[key] = Vector2(float(street_x[x_index]), float(street_z[z_index]))
			road_links[key] = []

	for x_index in range(street_x.size()):
		for z_index in range(street_z.size()):
			if x_index < street_x.size() - 1:
				_connect_nodes(_node_key(x_index, z_index), _node_key(x_index + 1, z_index))
			if z_index < street_z.size() - 1:
				_connect_nodes(_node_key(x_index, z_index), _node_key(x_index, z_index + 1))

	var start_cell: Array = active_map.get("start", [0, 0])
	var target_cell: Array = active_map.get("target", [0, 1])
	current_node_key = _node_key(int(start_cell[0]), int(start_cell[1]))
	target_node_key = _node_key(int(target_cell[0]), int(target_cell[1]))
	previous_node_key = ""
	drive_mode = DRIVE_MODE_STRAIGHT
	_begin_segment(current_node_key, target_node_key)


func _connect_nodes(first_key: String, second_key: String) -> void:
	if not road_links.has(first_key) or not road_links.has(second_key):
		return
	(road_links[first_key] as Array).append(second_key)
	(road_links[second_key] as Array).append(first_key)


func _street_x_values() -> Array:
	return active_map.get("street_x", [])


func _street_z_values() -> Array:
	return active_map.get("street_z", [])


func _node_key(x_index: int, z_index: int) -> String:
	return "%d:%d" % [x_index, z_index]


func _begin_segment(from_key: String, to_key: String) -> void:
	if not road_nodes.has(from_key) or not road_nodes.has(to_key):
		return
	segment_start = road_nodes[from_key] as Vector2
	segment_end = road_nodes[to_key] as Vector2
	segment_length = max(segment_start.distance_to(segment_end), 0.01)
	segment_progress = 0.0
	vehicle_position = segment_start
	vehicle_direction = (segment_start - segment_end).normalized()


func _advance_vehicle(delta: float) -> void:
	var remaining_move := DRIVE_SPEED * delta
	while remaining_move > 0.0:
		if drive_mode == DRIVE_MODE_TURN:
			remaining_move = _advance_turn(remaining_move)
		else:
			remaining_move = _advance_straight(remaining_move)


func _advance_straight(move_distance: float) -> float:
	var turn_start: float = max(segment_length - _turn_radius_for_segment(), segment_length * 0.55)
	var can_prepare_turn: bool = segment_progress < turn_start and _has_forward_choice(target_node_key, current_node_key)
	var straight_limit: float = turn_start if can_prepare_turn else segment_length
	var segment_remaining: float = straight_limit - segment_progress
	if move_distance < segment_remaining:
		segment_progress += move_distance
		_update_straight_vehicle()
		return 0.0

	segment_progress = straight_limit
	_update_straight_vehicle()
	var remaining_move: float = move_distance - max(segment_remaining, 0.0)
	if can_prepare_turn:
		if _start_turn():
			return remaining_move
		return _advance_straight(remaining_move)

	_arrive_without_turn()
	return remaining_move


func _advance_turn(move_distance: float) -> float:
	var turn_remaining := turn_length - turn_progress
	var speed_factor := _turn_speed_factor()
	var turn_delta := move_distance * speed_factor
	if turn_delta < turn_remaining:
		turn_progress += turn_delta
		_update_turn_vehicle()
		return 0.0

	turn_progress = turn_length
	_update_turn_vehicle()
	_finish_turn()
	var consumed_move: float = turn_remaining / max(speed_factor, 0.001)
	return max(move_distance - consumed_move, 0.0)


func _update_straight_vehicle() -> void:
	var t: float = clamp(segment_progress / segment_length, 0.0, 1.0)
	vehicle_position = segment_start.lerp(segment_end, t)
	vehicle_direction = (segment_start - segment_end).normalized()


func _start_turn() -> bool:
	var incoming_direction := (segment_end - segment_start).normalized()
	turn_next_node_key = _choose_turn_node(target_node_key, current_node_key)
	if turn_next_node_key == "" or not road_nodes.has(turn_next_node_key):
		return false

	var outgoing_direction := ((road_nodes[turn_next_node_key] as Vector2) - segment_end).normalized()
	if incoming_direction.dot(outgoing_direction) < -0.985:
		return false

	var radius := _turn_radius_for_segment()
	turn_entry = segment_end - incoming_direction * radius
	turn_corner = segment_end
	turn_exit = segment_end + outgoing_direction * radius
	turn_length = max(radius * TURN_LENGTH_MULTIPLIER, 0.01)
	turn_progress = 0.0
	drive_mode = DRIVE_MODE_TURN
	_update_turn_vehicle()
	return true


func _update_turn_vehicle() -> void:
	var t: float = clamp(turn_progress / turn_length, 0.0, 1.0)
	vehicle_position = _quadratic_bezier(turn_entry, turn_corner, turn_exit, t)
	vehicle_direction = -_quadratic_bezier_tangent(turn_entry, turn_corner, turn_exit, t)


func _finish_turn() -> void:
	previous_node_key = current_node_key
	current_node_key = target_node_key
	target_node_key = turn_next_node_key
	_begin_segment(current_node_key, target_node_key)
	segment_progress = min(_turn_radius_for_segment(), segment_length)
	drive_mode = DRIVE_MODE_STRAIGHT
	_update_straight_vehicle()


func _arrive_without_turn() -> void:
	previous_node_key = current_node_key
	current_node_key = target_node_key
	target_node_key = _choose_straight_node(current_node_key, previous_node_key)
	_begin_segment(current_node_key, target_node_key)


func _turn_radius_for_segment() -> float:
	return min(TURN_RADIUS, max(segment_length * 0.35, 0.5))


func _turn_speed_factor() -> float:
	var t: float = clamp(turn_progress / turn_length, 0.0, 1.0)
	var accel_t: float = clamp((t - TURN_ACCEL_START) / (1.0 - TURN_ACCEL_START), 0.0, 1.0)
	var eased: float = accel_t * accel_t * (3.0 - 2.0 * accel_t)
	return lerp(1.0, TURN_EXIT_SPEED_MULTIPLIER, eased)


func _has_forward_choice(node_key: String, last_node_key: String) -> bool:
	var links: Array = road_links.get(node_key, [])
	if links.is_empty():
		return false
	if links.size() == 1 and links.has(last_node_key):
		return false
	return true


func _choose_next_node(node_key: String, last_node_key: String) -> String:
	var links: Array = road_links.get(node_key, [])
	if links.is_empty():
		return last_node_key
	var choices := links.duplicate()
	if last_node_key != "" and choices.size() > 1:
		choices.erase(last_node_key)
	if choices.is_empty():
		return last_node_key
	var turn_choices := _turn_choices(node_key, last_node_key, choices)
	if not turn_choices.is_empty() and rng.randf() < TURN_CHANCE:
		return turn_choices[rng.randi_range(0, turn_choices.size() - 1)]
	return choices[rng.randi_range(0, choices.size() - 1)]


func _choose_turn_node(node_key: String, last_node_key: String) -> String:
	var links: Array = road_links.get(node_key, [])
	if links.is_empty():
		return ""
	var choices := links.duplicate()
	if last_node_key != "" and choices.size() > 1:
		choices.erase(last_node_key)
	var turn_choices := _turn_choices(node_key, last_node_key, choices)
	if turn_choices.is_empty():
		return ""
	var straight_choices := _straight_choices(node_key, last_node_key, choices)
	if straight_choices.is_empty():
		return turn_choices[rng.randi_range(0, turn_choices.size() - 1)]
	if rng.randf() >= TURN_CHANCE:
		return ""
	return turn_choices[rng.randi_range(0, turn_choices.size() - 1)]


func _choose_straight_node(node_key: String, last_node_key: String) -> String:
	var links: Array = road_links.get(node_key, [])
	if links.is_empty():
		return last_node_key
	var choices := links.duplicate()
	if last_node_key != "" and choices.size() > 1:
		choices.erase(last_node_key)
	if choices.is_empty():
		return last_node_key
	if last_node_key == "" or not road_nodes.has(node_key) or not road_nodes.has(last_node_key):
		return choices[rng.randi_range(0, choices.size() - 1)]

	var straight_choices := _straight_choices(node_key, last_node_key, choices)
	if not straight_choices.is_empty():
		return straight_choices[rng.randi_range(0, straight_choices.size() - 1)]
	return _choose_next_node(node_key, last_node_key)


func _straight_choices(node_key: String, last_node_key: String, choices: Array) -> Array:
	if last_node_key == "" or not road_nodes.has(node_key) or not road_nodes.has(last_node_key):
		return choices
	var node_position := road_nodes[node_key] as Vector2
	var incoming_direction := (node_position - (road_nodes[last_node_key] as Vector2)).normalized()
	var straight_choices := []
	for choice in choices:
		if not road_nodes.has(choice):
			continue
		var outgoing_direction := ((road_nodes[choice] as Vector2) - node_position).normalized()
		if incoming_direction.dot(outgoing_direction) > 0.985:
			straight_choices.append(choice)
	return straight_choices


func _turn_choices(node_key: String, last_node_key: String, choices: Array) -> Array:
	if last_node_key == "" or not road_nodes.has(node_key) or not road_nodes.has(last_node_key):
		return choices
	var node_position := road_nodes[node_key] as Vector2
	var incoming_direction := (node_position - (road_nodes[last_node_key] as Vector2)).normalized()
	var result := []
	for choice in choices:
		if not road_nodes.has(choice):
			continue
		var outgoing_direction := ((road_nodes[choice] as Vector2) - node_position).normalized()
		if incoming_direction.dot(outgoing_direction) < 0.985:
			result.append(choice)
	return result


func _build_world() -> void:
	_build_lighting()
	_build_camera()
	_build_sky()
	_build_city_blocks()
	_update_camera()


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SoftDaylight"
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	add_child(sun)
	sun_light = sun

	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _sky_background_color(0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _sky_ambient_color(0)
	env.ambient_light_energy = _sky_ambient_energy(0)
	env.fog_enabled = false
	env.fog_light_color = _sky_fog_color(0)
	env.fog_light_energy = _sky_fog_energy(0)
	env.fog_density = 0.0
	env.fog_sky_affect = 0.0
	ambient.environment = env
	add_child(ambient)
	world_environment = ambient


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PassengerViewCamera"
	camera.fov = 96.0
	camera.near = 0.08
	camera.far = 900.0
	camera.current = true
	add_child(camera)


func _build_sky() -> void:
	sky_textures.clear()
	sky_domes.clear()
	sky_materials.clear()
	for path in SKY_PANORAMA_PATHS:
		var texture := _load_sky_panorama(path)
		if texture != null:
			sky_textures.append(texture)
	if sky_textures.is_empty():
		return
	_add_sky_dome("SkyCurrent", sky_textures[0], 1.0, SKY_DOME_RADIUS)
	var next_texture: Texture2D = sky_textures[1 % sky_textures.size()]
	_add_sky_dome("SkyNext", next_texture, 0.0, SKY_DOME_RADIUS * 0.995)
	_apply_sky_lighting(0, 0, 0.0)


func _add_sky_dome(node_name: String, texture: Texture2D, alpha: float, radius: float) -> void:
	var dome := MeshInstance3D.new()
	dome.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 96
	mesh.rings = 48
	dome.mesh = mesh
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	_disable_material_fog(material)
	dome.material_override = material
	add_child(dome)
	sky_domes.append(dome)
	sky_materials.append(material)


func _disable_material_fog(material: StandardMaterial3D) -> void:
	for property in material.get_property_list():
		if str(property.get("name", "")) == "disable_fog":
			material.set("disable_fog", true)
			return


func _load_sky_panorama(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _update_sky_cycle(delta: float) -> void:
	if sky_textures.size() < 2 or sky_materials.size() < 2:
		return
	if sky_transition_active:
		sky_transition_elapsed += delta
		var t: float = clamp(sky_transition_elapsed / SKY_TRANSITION_DURATION, 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		_set_sky_blend(eased)
		_apply_sky_lighting(sky_phase_index, sky_next_phase_index, eased)
		if t >= 1.0:
			_finish_sky_transition()
		return

	sky_cycle_elapsed += delta
	if sky_cycle_elapsed >= SKY_TRANSITION_INTERVAL:
		_start_sky_transition()


func _start_sky_transition() -> void:
	if sky_textures.size() < 2 or sky_materials.size() < 2:
		return
	sky_cycle_elapsed = 0.0
	sky_transition_elapsed = 0.0
	sky_next_phase_index = (sky_phase_index + 1) % sky_textures.size()
	var next_material := sky_materials[1] as StandardMaterial3D
	next_material.albedo_texture = sky_textures[sky_next_phase_index]
	_set_sky_blend(0.0)
	sky_transition_active = true


func _finish_sky_transition() -> void:
	sky_phase_index = sky_next_phase_index
	sky_transition_active = false
	var current_material := sky_materials[0] as StandardMaterial3D
	var next_material := sky_materials[1] as StandardMaterial3D
	current_material.albedo_texture = sky_textures[sky_phase_index]
	current_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	next_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	_apply_sky_lighting(sky_phase_index, sky_phase_index, 0.0)


func _set_sky_blend(t: float) -> void:
	var current_material := sky_materials[0] as StandardMaterial3D
	var next_material := sky_materials[1] as StandardMaterial3D
	current_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	next_material.albedo_color = Color(1.0, 1.0, 1.0, t)


func _apply_sky_lighting(from_index: int, to_index: int, t: float) -> void:
	if sun_light != null:
		sun_light.light_energy = lerp(_sky_sun_energy(from_index), _sky_sun_energy(to_index), t)
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.background_color = _sky_background_color(from_index).lerp(_sky_background_color(to_index), t)
		env.ambient_light_color = _sky_ambient_color(from_index).lerp(_sky_ambient_color(to_index), t)
		env.ambient_light_energy = lerp(_sky_ambient_energy(from_index), _sky_ambient_energy(to_index), t)
		env.fog_light_color = _sky_fog_color(from_index).lerp(_sky_fog_color(to_index), t)
		env.fog_light_energy = lerp(_sky_fog_energy(from_index), _sky_fog_energy(to_index), t)


func _sky_sun_energy(index: int) -> float:
	match index % 3:
		1:
			return 0.9
		2:
			return 0.28
		_:
			return 1.3


func _sky_ambient_energy(index: int) -> float:
	match index % 3:
		1:
			return 0.9
		2:
			return 0.38
		_:
			return 1.04


func _sky_fog_energy(index: int) -> float:
	match index % 3:
		1:
			return 0.14
		2:
			return 0.05
		_:
			return 0.18


func _sky_background_color(index: int) -> Color:
	match index % 3:
		1:
			return Color(0.32, 0.22, 0.48, 1.0)
		2:
			return Color(0.015, 0.025, 0.06, 1.0)
		_:
			return Color(0.58, 0.80, 0.98, 1.0)


func _sky_ambient_color(index: int) -> Color:
	match index % 3:
		1:
			return Color(0.94, 0.68, 0.62, 1.0)
		2:
			return Color(0.24, 0.34, 0.62, 1.0)
		_:
			return Color(0.86, 0.88, 0.90, 1.0)


func _sky_fog_color(index: int) -> Color:
	match index % 3:
		1:
			return Color(0.75, 0.42, 0.48, 1.0)
		2:
			return Color(0.07, 0.10, 0.20, 1.0)
		_:
			return Color(0.72, 0.82, 0.88, 1.0)


func _build_city_blocks() -> void:
	building_footprints.clear()
	_build_ground_plane()
	_build_grid_roads()
	_build_map_building_blocks()
	_build_perimeter_buildings()
	_add_map_props()
	_add_street_lighting()


func _build_ground_plane() -> void:
	var street_x := _street_x_values()
	var street_z := _street_z_values()
	var min_x: float = float(street_x[0]) - GROUND_MARGIN
	var max_x: float = float(street_x[street_x.size() - 1]) + GROUND_MARGIN
	var max_z: float = float(street_z[0]) + GROUND_MARGIN
	var min_z: float = float(street_z[street_z.size() - 1]) - GROUND_MARGIN
	var center_x: float = (min_x + max_x) * 0.5
	var center_z: float = (min_z + max_z) * 0.5
	_add_box(
		"GroundBase",
		Vector3(center_x, -0.085, center_z),
		Vector3(max_x - min_x, 0.04, max_z - min_z),
		0.0,
		Color(0.42, 0.43, 0.42, 1.0),
		0.0
	)
	_add_ground_tile_lines(min_x, max_x, min_z, max_z)


func _add_ground_tile_lines(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	var line_color := Color(0.52, 0.53, 0.52, 1.0)
	var x_count: int = int(floor((max_x - min_x) / GROUND_TILE_SIZE))
	var z_count: int = int(floor((max_z - min_z) / GROUND_TILE_SIZE))
	for x_index in range(x_count + 1):
		var x: float = min_x + float(x_index) * GROUND_TILE_SIZE
		_add_box(
			"GroundTileVertical%02d" % x_index,
			Vector3(x, -0.052, (min_z + max_z) * 0.5),
			Vector3(0.08, 0.012, max_z - min_z),
			0.0,
			line_color,
			0.0
		)
	for z_index in range(z_count + 1):
		var z: float = min_z + float(z_index) * GROUND_TILE_SIZE
		_add_box(
			"GroundTileHorizontal%02d" % z_index,
			Vector3((min_x + max_x) * 0.5, -0.051, z),
			Vector3(max_x - min_x, 0.012, 0.08),
			0.0,
			line_color,
			0.0
		)


func _build_grid_roads() -> void:
	var street_x := _street_x_values()
	var street_z := _street_z_values()
	var min_x := float(street_x[0])
	var max_x := float(street_x[street_x.size() - 1])
	var max_z := float(street_z[0])
	var min_z := float(street_z[street_z.size() - 1])
	var road_color := Color(0.11, 0.12, 0.13, 1.0)
	var sidewalk_color := Color(0.55, 0.53, 0.49, 1.0)

	for x_index in range(street_x.size()):
		var x := float(street_x[x_index])
		var center_z := (min_z + max_z) * 0.5
		var length: float = abs(max_z - min_z) + ROAD_WIDTH
		_add_box("RoadVertical%02d" % x_index, Vector3(x, 0.0, center_z), Vector3(ROAD_WIDTH, 0.08, length), 0.0, road_color, 0.0)
		_add_box("SidewalkVerticalL%02d" % x_index, Vector3(x - ROAD_WIDTH * 0.5 - SIDEWALK_WIDTH * 0.5, 0.02, center_z), Vector3(SIDEWALK_WIDTH, 0.12, length), 0.0, sidewalk_color, 0.0)
		_add_box("SidewalkVerticalR%02d" % x_index, Vector3(x + ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5, 0.02, center_z), Vector3(SIDEWALK_WIDTH, 0.12, length), 0.0, sidewalk_color, 0.0)
		_add_lane_markers(Vector2(x, max_z), Vector2(x, min_z), x_index)

	for z_index in range(street_z.size()):
		var z := float(street_z[z_index])
		var center_x := (min_x + max_x) * 0.5
		var length: float = abs(max_x - min_x) + ROAD_WIDTH
		_add_box("RoadHorizontal%02d" % z_index, Vector3(center_x, 0.005, z), Vector3(length, 0.09, ROAD_WIDTH), 0.0, road_color, 0.0)
		_add_box("SidewalkHorizontalT%02d" % z_index, Vector3(center_x, 0.025, z - ROAD_WIDTH * 0.5 - SIDEWALK_WIDTH * 0.5), Vector3(length, 0.12, SIDEWALK_WIDTH), 0.0, sidewalk_color, 0.0)
		_add_box("SidewalkHorizontalB%02d" % z_index, Vector3(center_x, 0.025, z + ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5), Vector3(length, 0.12, SIDEWALK_WIDTH), 0.0, sidewalk_color, 0.0)
		_add_lane_markers(Vector2(min_x, z), Vector2(max_x, z), z_index + 100)


func _add_lane_markers(start: Vector2, end: Vector2, marker_id: int) -> void:
	var direction := (end - start).normalized()
	var length := start.distance_to(end)
	var yaw := _yaw_for_segment(direction)
	var count := int(floor(length / 6.0))
	for i in range(count):
		var center := start + direction * (3.0 + float(i) * 6.0)
		_add_box(
			"RoadDash_%02d_%02d" % [marker_id, i],
			_v3(center, 0.095),
			Vector3(0.13, 0.024, 2.2),
			yaw,
			Color(0.92, 0.88, 0.68, 1.0),
			0.0
		)


func _build_map_building_blocks() -> void:
	var street_x := _street_x_values()
	var street_z := _street_z_values()
	var padding := BLOCK_CLEARANCE
	for x_index in range(street_x.size() - 1):
		for z_index in range(street_z.size() - 1):
			var min_x := float(street_x[x_index]) + padding
			var max_x := float(street_x[x_index + 1]) - padding
			var min_z := float(street_z[z_index + 1]) + padding
			var max_z := float(street_z[z_index]) - padding
			if min_x >= max_x or min_z >= max_z:
				continue
			_add_building_block(min_x, max_x, min_z, max_z, x_index, z_index)


func _add_building_block(min_x: float, max_x: float, min_z: float, max_z: float, block_x: int, block_z: int) -> void:
	_add_building_side(Vector2(min_x, max_z), Vector2(max_x, max_z), Vector2(0.0, 1.0), block_x, block_z, 0)
	_add_building_side(Vector2(max_x, min_z), Vector2(min_x, min_z), Vector2(0.0, -1.0), block_x, block_z, 3)
	_add_building_side(Vector2(min_x, min_z), Vector2(min_x, max_z), Vector2(-1.0, 0.0), block_x, block_z, 6)
	_add_building_side(Vector2(max_x, max_z), Vector2(max_x, min_z), Vector2(1.0, 0.0), block_x, block_z, 9)
	_add_block_infill(min_x, max_x, min_z, max_z, block_x, block_z)


func _add_block_infill(min_x: float, max_x: float, min_z: float, max_z: float, block_x: int, block_z: int) -> void:
	var inner_min_x: float = min_x + BLOCK_INNER_MARGIN
	var inner_max_x: float = max_x - BLOCK_INNER_MARGIN
	var inner_min_z: float = min_z + BLOCK_INNER_MARGIN
	var inner_max_z: float = max_z - BLOCK_INNER_MARGIN
	var usable_width: float = inner_max_x - inner_min_x
	var usable_depth: float = inner_max_z - inner_min_z
	if usable_width < BLOCK_INNER_SPACING * 0.45 or usable_depth < BLOCK_INNER_SPACING * 0.45:
		return

	var columns: int = max(1, int(floor(usable_width / BLOCK_INNER_SPACING)) + 1)
	var rows: int = max(1, int(floor(usable_depth / BLOCK_INNER_SPACING)) + 1)
	var column_step: float = 0.0 if columns <= 1 else usable_width / float(columns - 1)
	var row_step: float = 0.0 if rows <= 1 else usable_depth / float(rows - 1)
	for row in range(rows):
		for column in range(columns):
			var center := Vector2(
				inner_min_x + column_step * float(column),
				inner_min_z + row_step * float(row)
			)
			center.x = clamp(center.x + _lot_jitter(block_x, block_z, column, row, 0), inner_min_x, inner_max_x)
			center.y = clamp(center.y + _lot_jitter(block_x, block_z, column, row, 1), inner_min_z, inner_max_z)
			if not _can_place_footprint(center, INNER_HOUSE_FOOTPRINT_RADIUS):
				continue
			var facing := Vector2(0.0, 1.0) if center.y >= (min_z + max_z) * 0.5 else Vector2(0.0, -1.0)
			var house_index := (block_x * 11 + block_z * 13 + row * 3 + column * 5) % HOUSE_MODELS.size()
			var house_name: String = HOUSE_MODELS[house_index]
			var house := _add_model(
				house_name,
				_v3(center, -0.08),
				_house_scale(house_name, row + column) * 0.96
			)
			_register_footprint(center, INNER_HOUSE_FOOTPRINT_RADIUS)
			house.scale.y *= 0.96 + float((row + column + block_x + block_z) % 4) * 0.07
			house.rotation.y = _yaw_for_facing(facing) + _house_angle_variation(row + column, facing.x + facing.y, block_x + block_z)


func _build_perimeter_buildings() -> void:
	var street_x := _street_x_values()
	var street_z := _street_z_values()
	var min_x := float(street_x[0]) - PERIMETER_CLEARANCE
	var max_x := float(street_x[street_x.size() - 1]) + PERIMETER_CLEARANCE
	var max_z := float(street_z[0]) + PERIMETER_CLEARANCE
	var min_z := float(street_z[street_z.size() - 1]) - PERIMETER_CLEARANCE
	_add_perimeter_side(Vector2(min_x, max_z), Vector2(max_x, max_z), Vector2(0.0, -1.0), 0)
	_add_perimeter_side(Vector2(max_x, min_z), Vector2(min_x, min_z), Vector2(0.0, 1.0), 1)
	_add_perimeter_side(Vector2(min_x, min_z), Vector2(min_x, max_z), Vector2(1.0, 0.0), 2)
	_add_perimeter_side(Vector2(max_x, max_z), Vector2(max_x, min_z), Vector2(-1.0, 0.0), 3)
	_add_perimeter_corner_cluster(Vector2(min_x, max_z), Vector2(-1.0, 1.0), 0)
	_add_perimeter_corner_cluster(Vector2(max_x, max_z), Vector2(1.0, 1.0), 1)
	_add_perimeter_corner_cluster(Vector2(min_x, min_z), Vector2(-1.0, -1.0), 2)
	_add_perimeter_corner_cluster(Vector2(max_x, min_z), Vector2(1.0, -1.0), 3)


func _add_perimeter_side(start: Vector2, end: Vector2, facing: Vector2, side_id: int) -> void:
	_add_building_side(
		start,
		end,
		facing,
		side_id + 20,
		side_id,
		2,
		PERIMETER_HOUSE_SPACING,
		1.08,
		1.18,
		PERIMETER_CORNER_MARGIN,
		PERIMETER_FOOTPRINT_RADIUS
	)
	_add_building_side(
		start,
		end,
		facing,
		side_id + 40,
		side_id + 2,
		5,
		PERIMETER_HOUSE_SPACING,
		1.0,
		1.08,
		PERIMETER_CORNER_MARGIN,
		PERIMETER_FOOTPRINT_RADIUS,
		PERIMETER_BACK_ROW_OFFSET,
		PERIMETER_BACK_ROW_STAGGER
	)


func _add_building_side(
	start: Vector2,
	end: Vector2,
	facing: Vector2,
	block_x: int,
	block_z: int,
	model_offset: int,
	spacing: float = BLOCK_HOUSE_SPACING,
	scale_multiplier: float = 1.0,
	height_multiplier: float = 1.0,
	corner_margin: float = BLOCK_CORNER_MARGIN,
	footprint_radius: float = HOUSE_FOOTPRINT_RADIUS,
	depth_offset: float = 0.0,
	side_stagger: float = 0.0
) -> void:
	var direction := (end - start).normalized()
	var length := start.distance_to(end)
	if length <= 0.1:
		return
	var usable_length: float = max(length - corner_margin * 2.0, 0.0)
	if usable_length < spacing * 0.55:
		return
	var count: int = max(1, int(floor(usable_length / spacing)))
	var step: float = usable_length / float(count)
	var yaw := _yaw_for_facing(facing)
	for i in range(count):
		var distance_along_side: float = corner_margin + step * (float(i) + 0.5 + side_stagger)
		if distance_along_side > length - corner_margin:
			distance_along_side -= usable_length
		var center := start + direction * distance_along_side
		center -= facing * (_building_depth_offset(i, block_x, block_z) + depth_offset)
		center += direction * _building_side_jitter(i, block_x, block_z)
		if not _can_place_footprint(center, footprint_radius):
			continue
		var house_index := (block_x * 5 + block_z * 7 + model_offset + i * 2) % HOUSE_MODELS.size()
		var house_name: String = HOUSE_MODELS[house_index]
		var house := _add_model(
			house_name,
			_v3(center, -0.08),
			_house_scale(house_name, i) * scale_multiplier
		)
		_register_footprint(center, footprint_radius)
		house.scale.y *= height_multiplier + float((i + block_x + block_z) % 3) * 0.08
		house.rotation.y = yaw + _house_angle_variation(i, facing.x + facing.y, model_offset)
		if (i + model_offset) % 4 == 0:
			var sign_position := center + facing * 0.9
			if not _can_place_footprint(sign_position, SIGN_FOOTPRINT_RADIUS):
				continue
			var sign := _add_model("AE_Signboards_01.glb", _v3(sign_position, 1.55), 0.35)
			sign.rotation.y = yaw
			_register_footprint(sign_position, SIGN_FOOTPRINT_RADIUS)


func _add_perimeter_corner_cluster(corner: Vector2, outside_sign: Vector2, corner_id: int) -> void:
	var spacing := PERIMETER_HOUSE_SPACING
	var offsets := [
		Vector2(0.48, 0.48),
		Vector2(1.42, 0.48),
		Vector2(0.48, 1.42),
		Vector2(1.42, 1.42),
		Vector2(2.36, 0.92),
		Vector2(0.92, 2.36)
	]
	for i in range(offsets.size()):
		var offset: Vector2 = offsets[i]
		var center := corner + Vector2(outside_sign.x * spacing * offset.x, outside_sign.y * spacing * offset.y)
		if not _can_place_footprint(center, PERIMETER_FOOTPRINT_RADIUS):
			continue
		var house_index := (corner_id * 7 + i * 3) % HOUSE_MODELS.size()
		var house_name: String = HOUSE_MODELS[house_index]
		var house := _add_model(
			house_name,
			_v3(center, -0.08),
			_house_scale(house_name, i) * 1.03
		)
		_register_footprint(center, PERIMETER_FOOTPRINT_RADIUS)
		house.scale.y *= 1.02 + float((corner_id + i) % 3) * 0.08
		var facing := Vector2(-outside_sign.x, 0.0) if offset.x > offset.y else Vector2(0.0, -outside_sign.y)
		house.rotation.y = _yaw_for_facing(facing) + _house_angle_variation(i, facing.x + facing.y, corner_id)


func _can_place_footprint(center: Vector2, radius: float) -> bool:
	for footprint in building_footprints:
		var footprint_data: Dictionary = footprint
		var other_center: Vector2 = footprint_data.get("center", Vector2.ZERO)
		var other_radius: float = float(footprint_data.get("radius", 0.0))
		var minimum_distance: float = radius + other_radius + FOOTPRINT_PADDING
		if center.distance_to(other_center) < minimum_distance:
			return false
	return true


func _register_footprint(center: Vector2, radius: float) -> void:
	building_footprints.append({
		"center": center,
		"radius": radius
	})


func _distance_variation(index: int, leg_index: int, model_offset: int) -> float:
	return float(((index * 11 + leg_index * 5 + model_offset) % 5) - 2) * 0.28


func _side_depth_variation(index: int, side: float, model_offset: int) -> float:
	return float(((index * 7 + model_offset + (3 if side > 0.0 else 0)) % 5) - 2) * 0.34


func _house_angle_variation(index: int, side: float, model_offset: int) -> float:
	var amount := deg_to_rad(float(((index + model_offset) % 3) - 1) * 2.6)
	return amount * (-1.0 if side < 0.0 else 1.0)


func _building_depth_offset(index: int, block_x: int, block_z: int) -> float:
	return BUILDING_CENTER_DEPTH + float((index + block_x * 2 + block_z) % 4) * 0.16


func _building_side_jitter(index: int, block_x: int, block_z: int) -> float:
	return float(((index * 3 + block_x + block_z) % 5) - 2) * 0.12


func _lot_jitter(block_x: int, block_z: int, column: int, row: int, axis: int) -> float:
	return float(((block_x * 17 + block_z * 19 + column * 7 + row * 11 + axis * 5) % 5) - 2) * 0.22


func _yaw_for_facing(facing: Vector2) -> float:
	return atan2(-facing.x, -facing.y)


func _yaw_for_segment(direction: Vector2) -> float:
	return atan2(direction.x, direction.y)


func _quadratic_bezier(first: Vector2, control: Vector2, last: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return first * inverse * inverse + control * 2.0 * inverse * t + last * t * t


func _quadratic_bezier_tangent(first: Vector2, control: Vector2, last: Vector2, t: float) -> Vector2:
	var tangent := (control - first) * (2.0 * (1.0 - t)) + (last - control) * (2.0 * t)
	if tangent.length_squared() <= 0.001:
		return vehicle_direction
	return tangent.normalized()


func _add_map_props() -> void:
	var street_x := _street_x_values()
	var street_z := _street_z_values()
	for x_index in range(street_x.size()):
		for z_index in range(street_z.size() - 1):
			var start := Vector2(float(street_x[x_index]), float(street_z[z_index]))
			var end := Vector2(float(street_x[x_index]), float(street_z[z_index + 1]))
			_add_props_along_road(start, end, x_index * 10 + z_index)
	for z_index in range(street_z.size()):
		for x_index in range(street_x.size() - 1):
			var start := Vector2(float(street_x[x_index]), float(street_z[z_index]))
			var end := Vector2(float(street_x[x_index + 1]), float(street_z[z_index]))
			_add_props_along_road(start, end, z_index * 10 + x_index + 100)


func _add_props_along_road(start: Vector2, end: Vector2, road_id: int) -> void:
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var length := start.distance_to(end)
	var count := int(floor(length / PROP_SPACING))
	var yaw := _yaw_for_facing(-normal)
	for i in range(count):
		if i % 2 != 0:
			continue
		var side := -1.0 if (i + road_id) % 2 == 0 else 1.0
		var prop_name := _detail_prop_name(i + road_id, side)
		var position := start + direction * (3.0 + float(i) * PROP_SPACING) + normal * side * PROP_OFFSET
		var prop := _add_model(prop_name, _v3(position), _detail_prop_scale(prop_name))
		prop.rotation.y = yaw if side < 0.0 else yaw + PI


func _add_visible_road_marks() -> void:
	for i in range(16):
		var z: float = -3.8 - float(i) * 6.0
		_add_box(
			"VisibleRoadDash_%02d" % i,
			Vector3(0.0, 0.095, z),
			Vector3(0.13, 0.024, 2.2),
			0.0,
			Color(0.92, 0.88, 0.68, 1.0),
			0.0
		)
		for side in [-1.0, 1.0]:
			_add_box(
				"VisibleCurbLine_%s_%02d" % ["R" if side > 0.0 else "L", i],
				Vector3(side * 2.35, 0.11, z),
				Vector3(0.10, 0.028, 3.6),
				0.0,
				Color(0.82, 0.82, 0.78, 1.0),
				0.0
			)


func _add_street_lighting() -> void:
	var street_x := _street_x_values()
	var street_z := _street_z_values()
	for x_index in range(street_x.size()):
		for z_index in range(street_z.size()):
			if (x_index + z_index) % 2 != 0:
				continue
			var light := OmniLight3D.new()
			light.name = "StreetLampGlow_%02d_%02d" % [x_index, z_index]
			light.position = Vector3(float(street_x[x_index]) + 1.9, 3.15, float(street_z[z_index]) - 1.9)
			light.light_color = Color(1.0, 0.74, 0.48, 1.0)
			light.light_energy = 0.44
			light.omni_range = 7.2
			add_child(light)


func _house_scale(file_name: String, index: int) -> float:
	var scale := 0.36 + 0.018 * float(index % 3)
	if file_name == "AE_House_10.glb" or file_name == "AE_House_12.glb":
		scale *= 0.88
	if file_name == "AE_House_06.glb" or file_name == "AE_House_09.glb":
		scale *= 0.9
	return scale


func _detail_prop_name(index: int, side: float) -> String:
	var props := [
		"AE_Vending_Machine_01.glb",
		"AE_Bicycle_01.glb",
		"AE_Flower_Pot_01.glb",
		"AE_Mailbox_01.glb",
		"AE_Scooter_01.glb",
		"AE_Street_Fence_01.glb"
	]
	var side_offset := 2 if side > 0.0 else 0
	return props[(index + side_offset) % props.size()]


func _detail_prop_scale(file_name: String) -> float:
	if file_name.contains("Bicycle"):
		return 0.38
	if file_name.contains("Scooter"):
		return 0.34
	if file_name.contains("Vending"):
		return 0.46
	if file_name.contains("Fence"):
		return 0.55
	if file_name.contains("Mailbox"):
		return 0.42
	return 0.48


func _update_camera() -> void:
	if camera == null:
		return
	var direction := vehicle_direction
	if direction.length_squared() <= 0.001:
		direction = Vector2(0.0, -1.0)
	var side_sway := sin(Time.get_ticks_msec() * 0.0012) * 0.08
	var normal := Vector2(-direction.y, direction.x)
	var side_focus := normal * (SIDE_LOOK_OFFSET + side_sway)
	var camera_pos := _v3(vehicle_position + normal * side_sway, CAMERA_HEIGHT)
	var target_pos := _v3(vehicle_position + direction * LOOK_AHEAD_DISTANCE + side_focus, CAMERA_TARGET_HEIGHT)
	_update_sky_domes(_v3(vehicle_position, 0.0))
	camera.look_at_from_position(camera_pos, target_pos, Vector3.UP)


func _update_sky_domes(center_position: Vector3) -> void:
	for dome in sky_domes:
		if dome is Node3D:
			(dome as Node3D).position = center_position


func _add_box(node_name: String, position: Vector3, size: Vector3, yaw: float, color: Color, y_offset: float, texture_path: String = "") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position + Vector3(0.0, y_offset, 0.0)
	instance.rotation.y = yaw
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = mat
	add_child(instance)
	return instance


func _add_model(file_name: String, position: Vector3, scale_value: float) -> Node3D:
	var model := loader.load_node("%s/%s" % [MODEL_ROOT, file_name], true)
	model.name = file_name.get_basename()
	model.position = position
	model.scale = Vector3.ONE * scale_value
	add_child(model)
	return model


func _prop_scale(file_name: String) -> float:
	if file_name.contains("Bicycle") or file_name.contains("Scooter"):
		return 0.58
	if file_name.contains("Traffic"):
		return 0.68
	if file_name.contains("Electric"):
		return 0.78
	if file_name.contains("Vending"):
		return 0.66
	if file_name.contains("Fence"):
		return 0.82
	return 0.68


func _v3(point: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(point.x, y, point.y)
