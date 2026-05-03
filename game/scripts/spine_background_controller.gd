extends Node

const ContentUnlockService = preload("res://scripts/content_unlock_service.gd")

const ASSET_ROOT := "res://assets/spine/backgrounds"
const TARGET_VIEWPORT_SIZE := Vector2(1152, 648)
const RELEASE_FALLBACK_SCALE := 0.50
const BACKGROUND_LOFI_AUTO := "lofi_auto"

const ROOM_ANIMATION_RULES := {
	"room_bg_01": {
		"normal_day_clear": "01",
		"normal_sunfall_clear": "02",
		"normal_night_clear": "03",
		"normal_day_rain": "04",
		"good_day_clear": "06",
		"good_night_clear": "07",
		"good_sunfall_clear": "08",
		"troubled_day_clear": "11",
		"troubled_night_clear": "12",
		"troubled_sunfall_clear": "12"
	},
	"room_bg_02": {
		"normal_day_clear": "05",
		"normal_sunfall_clear": "09",
		"normal_night_clear": "10",
		"normal_day_rain": "05",
		"good_day_clear": "13",
		"good_night_clear": "14",
		"good_sunfall_clear": "15",
		"troubled_day_clear": "16",
		"troubled_night_clear": "17",
		"troubled_sunfall_clear": "18"
	}
}

var root_2d: Node2D
var selected_context := {}
var background_defs: Array = []
var unlocked_content: Array = []
var spine_sprite: Node = null
var current_spine_variant := ""
var current_animation := ""
var selected_background_id := BACKGROUND_LOFI_AUTO


func setup(world_root: Node2D, context: Dictionary, content_defs: Array = [], content_unlocks: Array = [], background_id: String = BACKGROUND_LOFI_AUTO) -> void:
	root_2d = world_root
	selected_context = context
	background_defs = content_defs
	unlocked_content = content_unlocks
	selected_background_id = background_id
	get_viewport().size_changed.connect(fit_to_viewport)


func set_content_state(content_defs: Array, content_unlocks: Array) -> void:
	background_defs = content_defs
	unlocked_content = content_unlocks


func set_selected_background(background_id: String) -> void:
	selected_background_id = background_id


func load_selected_background() -> void:
	var target := select_target()
	load_background(str(target.get("variant", "")), str(target.get("animation", "")))


func load_background(variant: String, animation_name: String = "") -> void:
	if current_spine_variant == variant and spine_sprite != null:
		play_animation(spine_sprite, animation_name)
		return
	current_spine_variant = variant
	current_animation = ""

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
	play_animation(spine_sprite, animation_name)
	fit_to_viewport()


func play_animation(sprite: Node, requested_animation: String = "") -> void:
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
	if requested_animation != "":
		for animation in animations:
			if animation.get_name() == requested_animation:
				animation_name = requested_animation
				break
	for animation in animations:
		if animation.get_name() == "Loop":
			animation_name = "Loop"
			break
	var animation_state = sprite.get_animation_state()
	if animation_state == null:
		return
	if current_animation == animation_name:
		return
	current_animation = animation_name
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
	return str(select_target().get("variant", ""))


func select_target() -> Dictionary:
	if selected_background_id != BACKGROUND_LOFI_AUTO:
		var definition := ContentUnlockService.find_by_content_id(background_defs, selected_background_id)
		if not definition.is_empty() and ContentUnlockService.is_unlocked(definition, unlocked_content):
			return {
				"variant": str(definition.get("spine_variant", "Room")),
				"animation": _room_animation_for_context(str(definition.get("room_background_id", selected_background_id)))
			}

	if not background_defs.is_empty():
		return {
			"variant": ContentUnlockService.background_variant_for_context(selected_context, background_defs, unlocked_content),
			"animation": ""
		}

	var mood := str(selected_context.mood)
	var time := str(selected_context.time)
	if mood == "normal":
		if time == "night":
			return {"variant": "LofiBG_01_Nomal_Night", "animation": ""}
		if time == "sunfall":
			return {"variant": "LofiBG_01_Nomal_Sunfall", "animation": ""}
		if selected_context.weather == "rain":
			return {"variant": "LofiBG_01_Nomal_Cloudy", "animation": ""}
		return {"variant": "LofiBG_01_Nomal_Day", "animation": ""}
	if mood == "good":
		if time == "night":
			return {"variant": "LofiBG_01_Good_Night", "animation": ""}
		if time == "sunfall":
			return {"variant": "LofiBG_01_Good_Sunfall", "animation": ""}
		return {"variant": "LofiBG_01_Good_Day", "animation": ""}
	if mood == "troubled":
		if time == "night":
			return {"variant": "LofiBG_01_Troubled_Night", "animation": ""}
		if time == "sunfall":
			return {"variant": "LofiBG_01_Troubled_Sunfall", "animation": ""}
		return {"variant": "LofiBG_01_Troubled_Day", "animation": ""}
	return {"variant": "LofiBG_01_Nomal_Day", "animation": ""}


func _room_animation_for_context(room_background_id: String) -> String:
	var rules: Dictionary = ROOM_ANIMATION_RULES.get(room_background_id, {})
	var key := "%s_%s_%s" % [
		str(selected_context.get("mood", "normal")),
		str(selected_context.get("time", "day")),
		str(selected_context.get("weather", "clear"))
	]
	if rules.has(key):
		return str(rules[key])
	var clear_key := "%s_%s_clear" % [
		str(selected_context.get("mood", "normal")),
		str(selected_context.get("time", "day"))
	]
	return str(rules.get(clear_key, rules.get("normal_day_clear", "01")))
