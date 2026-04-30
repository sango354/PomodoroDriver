extends Node

const ContentUnlockService = preload("res://scripts/content_unlock_service.gd")

const ASSET_ROOT := "res://assets/spine/backgrounds"
const TARGET_VIEWPORT_SIZE := Vector2(1152, 648)
const RELEASE_FALLBACK_SCALE := 0.50

var root_2d: Node2D
var selected_context := {}
var background_defs: Array = []
var unlocked_content: Array = []
var spine_sprite: Node = null
var current_spine_variant := ""


func setup(world_root: Node2D, context: Dictionary, content_defs: Array = [], content_unlocks: Array = []) -> void:
	root_2d = world_root
	selected_context = context
	background_defs = content_defs
	unlocked_content = content_unlocks
	get_viewport().size_changed.connect(fit_to_viewport)


func set_content_state(content_defs: Array, content_unlocks: Array) -> void:
	background_defs = content_defs
	unlocked_content = content_unlocks


func load_selected_background() -> void:
	load_background(select_variant())


func load_background(variant: String) -> void:
	if current_spine_variant == variant and spine_sprite != null:
		return
	current_spine_variant = variant

	if spine_sprite != null:
		spine_sprite.queue_free()
		spine_sprite = null

	if not ClassDB.class_exists("SpineSprite") or not ClassDB.class_exists("SpineSkeletonDataResource"):
		return

	var skeleton_path := "%s/%s/%s.skel" % [ASSET_ROOT, variant, variant]
	var atlas_path := "%s/%s/%s.atlas" % [ASSET_ROOT, variant, variant]
	var skeleton_res := ResourceLoader.load(skeleton_path)
	var atlas_res := ResourceLoader.load(atlas_path)
	if skeleton_res == null or atlas_res == null:
		push_warning("Unable to load Spine background: %s" % variant)
		return

	var data_res := ClassDB.instantiate("SpineSkeletonDataResource") as Resource
	if data_res == null:
		push_warning("Unable to instantiate Spine skeleton data resource.")
		return
	data_res.set("skeleton_file_res", skeleton_res)
	data_res.set("atlas_res", atlas_res)

	spine_sprite = ClassDB.instantiate("SpineSprite") as Node
	if spine_sprite == null:
		push_warning("Unable to instantiate Spine sprite.")
		return
	spine_sprite.name = "SpineBackground"
	spine_sprite.set("skeleton_data_res", data_res)
	root_2d.add_child(spine_sprite)
	play_loop(spine_sprite)
	fit_to_viewport()


func play_loop(sprite: Node) -> void:
	if not sprite.has_method("get_skeleton") or not sprite.has_method("get_animation_state"):
		return
	var skeleton = sprite.get_skeleton()
	if skeleton == null:
		return
	var skeleton_data = skeleton.get_data()
	if skeleton_data == null:
		return
	var animations: Array = skeleton_data.get_animations()
	if animations.is_empty():
		return
	var animation_name: String = animations[0].get_name()
	for animation in animations:
		if animation.get_name() == "Loop":
			animation_name = "Loop"
			break
	var animation_state = sprite.get_animation_state()
	if animation_state == null:
		return
	animation_state.set_animation(animation_name, true, 0)


func fit_to_viewport() -> void:
	if spine_sprite == null:
		return
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = TARGET_VIEWPORT_SIZE

	if not spine_sprite.has_method("_edit_get_rect"):
		_fit_with_release_fallback(viewport_size)
		return

	var skeleton = spine_sprite.get_skeleton()
	if skeleton == null:
		_fit_with_release_fallback(viewport_size)
		return
	skeleton.update_world_transform()
	var bounds: Rect2 = spine_sprite.call("_edit_get_rect")
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return

	var scale_factor: float = max(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y) * 1.02
	spine_sprite.scale = Vector2.ONE * scale_factor
	spine_sprite.position = viewport_size * 0.5 - (bounds.position + bounds.size * 0.5) * scale_factor


func _fit_with_release_fallback(viewport_size: Vector2) -> void:
	var scale_factor: float = RELEASE_FALLBACK_SCALE * max(
		viewport_size.x / TARGET_VIEWPORT_SIZE.x,
		viewport_size.y / TARGET_VIEWPORT_SIZE.y
	)
	spine_sprite.scale = Vector2.ONE * scale_factor
	spine_sprite.position = viewport_size * 0.5


func select_variant() -> String:
	if not background_defs.is_empty():
		return ContentUnlockService.background_variant_for_context(selected_context, background_defs, unlocked_content)

	var mood := str(selected_context.mood)
	var time := str(selected_context.time)
	if mood == "normal":
		if time == "night":
			return "LofiBG_01_Nomal_Night"
		if time == "sunfall":
			return "LofiBG_01_Nomal_Sunfall"
		if selected_context.weather == "rain":
			return "LofiBG_01_Nomal_Cloudy"
		return "LofiBG_01_Nomal_Day"
	if mood == "good":
		if time == "night":
			return "LofiBG_01_Good_Night"
		if time == "sunfall":
			return "LofiBG_01_Good_Sunfall"
		return "LofiBG_01_Good_Day"
	if mood == "troubled":
		if time == "night":
			return "LofiBG_01_Troubled_Night"
		if time == "sunfall":
			return "LofiBG_01_Troubled_Sunfall"
		return "LofiBG_01_Troubled_Day"
	return "LofiBG_01_Nomal_Day"
