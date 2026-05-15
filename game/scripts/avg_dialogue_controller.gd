extends Node

signal dialogue_finished(dialogue_id: String)

var localizer
var overlay: Control
var dim_rect: ColorRect
var background_rect: TextureRect
var spine_root: Control
var spine_node: Node = null
var speaker_label: Label
var dialogue_label: Label
var prompt_label: Label
var current_dialogue := {}
var current_line_index := 0
var transition_next_background := false
var transition_duration := 2.0
var current_spine_scene := ""
var current_spine_animation := ""
var background_tween: Tween = null


func setup(parent: Control, localization_service = null) -> void:
	localizer = localization_service
	_build_overlay(parent)
	hide_dialogue()


func set_localizer(localization_service) -> void:
	localizer = localization_service
	_refresh_static_text()
	if overlay != null and overlay.visible:
		_show_current_line()


func show_dialogue(dialogue: Dictionary, transition_background: bool = false, duration: float = 2.0) -> void:
	if dialogue.is_empty() or overlay == null:
		return
	current_dialogue = dialogue
	current_line_index = 0
	transition_next_background = transition_background
	transition_duration = duration
	overlay.visible = true
	_raise_to_front()
	_show_current_line()


func hide_dialogue() -> void:
	if overlay != null:
		overlay.visible = false
	_clear_background()
	_clear_spine()
	current_dialogue = {}
	current_line_index = 0


func is_visible() -> bool:
	return overlay != null and overlay.visible


func _build_overlay(parent: Control) -> void:
	overlay = Control.new()
	overlay.name = "AVGDialogueOverlay"
	overlay.z_index = 320
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_gui_input)
	parent.add_child(overlay)
	get_viewport().size_changed.connect(_fit_spine_to_viewport)

	dim_rect = ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 1.0)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim_rect)

	background_rect = TextureRect.new()
	background_rect.name = "AVGBackground"
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	overlay.add_child(background_rect)

	spine_root = Control.new()
	spine_root.name = "AVGSpineRoot"
	spine_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spine_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(spine_root)

	var box := PanelContainer.new()
	box.name = "AVGTextBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = 0.08
	box.anchor_top = 1.0
	box.anchor_right = 0.92
	box.anchor_bottom = 1.0
	box.offset_top = -190
	box.offset_bottom = -28
	box.add_theme_stylebox_override("panel", _new_panel_style(0.84))
	overlay.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	box.add_child(margin)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 10)
	margin.add_child(text_box)

	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 18)
	text_box.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(0, 62)
	dialogue_label.add_theme_font_size_override("font_size", 22)
	text_box.add_child(dialogue_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	text_box.add_child(bottom_row)

	prompt_label = Label.new()
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9, 0.82))
	bottom_row.add_child(prompt_label)
	_refresh_static_text()


func _show_current_line() -> void:
	var lines: Array = current_dialogue.get("lines", [])
	if lines.is_empty():
		_finish_dialogue()
		return
	var line_value = lines[clamp(current_line_index, 0, lines.size() - 1)]
	if typeof(line_value) != TYPE_DICTIONARY:
		_finish_dialogue()
		return
	var line: Dictionary = line_value
	var speaker_key := str(line.get("speaker_key", ""))
	var text_key := str(line.get("text_key", ""))
	var background_path := str(line.get("background_path", current_dialogue.get("background_path", "")))
	var visual_mode := str(line.get("visual_mode", "")).strip_edges()
	if visual_mode == "":
		visual_mode = "bg" if background_path != "" else "keep"
	_apply_line_visuals(line, visual_mode, background_path)
	speaker_label.text = _tr_or(speaker_key, str(line.get("speaker", "")))
	speaker_label.visible = speaker_label.text != ""
	dialogue_label.text = _tr_or(text_key, str(line.get("text", "")))


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_or_finish()


func advance_or_finish() -> void:
	_advance_line()


func _advance_line() -> void:
	var lines: Array = current_dialogue.get("lines", [])
	if current_line_index >= lines.size() - 1:
		_finish_dialogue()
		return
	current_line_index += 1
	_show_current_line()


func _finish_dialogue() -> void:
	var dialogue_id := str(current_dialogue.get("dialogue_id", ""))
	hide_dialogue()
	if dialogue_id != "":
		dialogue_finished.emit(dialogue_id)


func _apply_line_visuals(line: Dictionary, visual_mode: String, background_path: String) -> void:
	_apply_overlay_backdrop(background_path, visual_mode)
	if visual_mode == "black":
		background_rect.texture = null
		background_rect.visible = false
		_clear_spine()
		return
	if visual_mode == "clear_spine":
		_clear_spine()
		if background_path != "":
			_set_background(background_path)
		return
	if visual_mode == "bg" or visual_mode == "bg_spine":
		_set_background(background_path)
	if visual_mode == "spine" or visual_mode == "bg_spine":
		_set_spine(
			str(line.get("spine_scene", "")),
			str(line.get("spine_skin", "")),
			str(line.get("spine_animation", ""))
		)


func _set_background(path: String) -> void:
	var texture := _load_texture(path)
	if transition_next_background:
		transition_next_background = false
		var half_duration: float = max(transition_duration * 0.5, 0.01)
		background_rect.visible = true
		_stop_background_tween()
		background_tween = create_tween()
		background_tween.tween_property(background_rect, "modulate:a", 0.0, half_duration)
		background_tween.tween_callback(func():
			background_rect.texture = texture
			background_rect.visible = texture != null
		)
		background_tween.tween_property(background_rect, "modulate:a", 1.0, half_duration)
		return
	transition_next_background = false
	_stop_background_tween()
	background_rect.texture = texture
	background_rect.visible = texture != null
	background_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _clear_background() -> void:
	_stop_background_tween()
	transition_next_background = false
	if background_rect != null:
		background_rect.texture = null
		background_rect.visible = false
		background_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if dim_rect != null:
		dim_rect.color = Color(0, 0, 0, 0.0)
	if speaker_label != null:
		speaker_label.text = ""
	if dialogue_label != null:
		dialogue_label.text = ""


func _stop_background_tween() -> void:
	if background_tween != null and background_tween.is_valid():
		background_tween.kill()
	background_tween = null


func _apply_overlay_backdrop(background_path: String, visual_mode: String = "") -> void:
	if dim_rect == null:
		return
	if visual_mode == "black" or bool(current_dialogue.get("black_overlay", false)):
		dim_rect.color = Color(0, 0, 0, 1.0)
	elif bool(current_dialogue.get("transparent_overlay", false)) or background_path == "":
		dim_rect.color = Color(0, 0, 0, 0.0)
	else:
		dim_rect.color = Color(0, 0, 0, 1.0)


func _set_spine(scene_path: String, skin_name: String, animation_name: String) -> void:
	if scene_path != "" and scene_path != current_spine_scene:
		_clear_spine()
		current_spine_scene = scene_path
		spine_node = _instantiate_spine(scene_path)
		if spine_node == null:
			current_spine_scene = ""
			return
		spine_node.name = "AVGSpine"
		spine_root.add_child(spine_node)
	elif spine_node == null and scene_path != "":
		current_spine_scene = ""
		_set_spine(scene_path, skin_name, animation_name)
		return
	if spine_node == null:
		return
	_apply_spine_skin(spine_node, skin_name)
	_play_spine_animation(spine_node, animation_name)
	_fit_spine_to_viewport()


func _instantiate_spine(scene_path: String) -> Node:
	if ResourceLoader.exists(scene_path):
		var resource: Resource = ResourceLoader.load(scene_path)
		var scene: PackedScene = resource as PackedScene
		if scene != null:
			return scene.instantiate()

	if not ClassDB.class_exists("SpineSprite") or not ClassDB.class_exists("SpineSkeletonDataResource"):
		push_warning("Spine runtime is unavailable for AVG dialogue.")
		return null

	var skeleton_path := scene_path
	var atlas_path := scene_path.get_basename() + ".atlas"
	if skeleton_path == "" or not ResourceLoader.exists(skeleton_path) or not ResourceLoader.exists(atlas_path):
		push_warning("Unable to load AVG Spine asset: %s" % scene_path)
		return null

	var skeleton_res: Resource = ResourceLoader.load(skeleton_path)
	var atlas_res: Resource = ResourceLoader.load(atlas_path)
	if skeleton_res == null or atlas_res == null:
		push_warning("Unable to load AVG Spine resources: %s" % scene_path)
		return null

	var data_res: Resource = ClassDB.instantiate("SpineSkeletonDataResource") as Resource
	if data_res == null:
		push_warning("Unable to instantiate AVG Spine skeleton data resource.")
		return null
	data_res.set("skeleton_file_res", skeleton_res)
	data_res.set("atlas_res", atlas_res)

	var sprite: Node = ClassDB.instantiate("SpineSprite") as Node
	if sprite == null:
		push_warning("Unable to instantiate AVG Spine sprite.")
		return null
	sprite.set("skeleton_data_res", data_res)
	return sprite


func _clear_spine() -> void:
	if spine_node != null:
		spine_node.queue_free()
		spine_node = null
	current_spine_scene = ""
	current_spine_animation = ""


func _apply_spine_skin(target: Node, skin_name: String) -> void:
	if skin_name == "" or not target.has_method("get_skeleton"):
		return
	var skeleton: Object = target.call("get_skeleton")
	if skeleton == null:
		return
	if skeleton.has_method("set_skin_by_name"):
		skeleton.call("set_skin_by_name", skin_name)
	elif skeleton.has_method("set_skin"):
		skeleton.call("set_skin", skin_name)
	if skeleton.has_method("set_slots_to_setup_pose"):
		skeleton.call("set_slots_to_setup_pose")


func _play_spine_animation(target: Node, requested_animation: String = "") -> void:
	if not target.has_method("get_skeleton") or not target.has_method("get_animation_state"):
		return
	var skeleton: Object = target.call("get_skeleton")
	if skeleton == null:
		return
	var skeleton_data: Object = skeleton.call("get_data") if skeleton.has_method("get_data") else null
	if skeleton_data == null or not skeleton_data.has_method("get_animations"):
		return
	var animations: Array = skeleton_data.call("get_animations")
	if animations.is_empty():
		return
	var animation_name := _select_spine_animation_name(animations, requested_animation)
	var animation_state: Object = target.call("get_animation_state")
	if animation_state == null or not animation_state.has_method("set_animation"):
		return
	if current_spine_animation == animation_name:
		return
	current_spine_animation = animation_name
	animation_state.call("set_animation", animation_name, true, 0)


func _select_spine_animation_name(animations: Array, requested_animation: String) -> String:
	var animation_name := ""
	for animation in animations:
		if animation_name == "" and animation.has_method("get_name"):
			animation_name = str(animation.call("get_name"))
		if requested_animation != "" and animation.has_method("get_name") and str(animation.call("get_name")) == requested_animation:
			return requested_animation
	for animation in animations:
		if animation.has_method("get_name") and str(animation.call("get_name")) == "Loop":
			return "Loop"
	return animation_name


func _fit_spine_to_viewport() -> void:
	if spine_node == null:
		return
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	if not spine_node.has_method("_edit_get_rect") or not spine_node.has_method("get_skeleton"):
		_fit_spine_with_fallback(viewport_size)
		return

	var skeleton: Object = spine_node.call("get_skeleton")
	if skeleton == null:
		_fit_spine_with_fallback(viewport_size)
		return
	if skeleton.has_method("update_world_transform"):
		skeleton.call("update_world_transform")
	var bounds: Rect2 = spine_node.call("_edit_get_rect")
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		_fit_spine_with_fallback(viewport_size)
		return
	var scale_factor: float = max(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y) * 1.02
	spine_node.set("scale", Vector2.ONE * scale_factor)
	spine_node.set("position", viewport_size * 0.5 - (bounds.position + bounds.size * 0.5) * scale_factor)


func _fit_spine_with_fallback(viewport_size: Vector2) -> void:
	if spine_node == null:
		return
	spine_node.set("scale", Vector2.ONE)
	spine_node.set("position", viewport_size * 0.5)


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _refresh_static_text() -> void:
	if prompt_label != null:
		prompt_label.text = "Click to Continue"


func _raise_to_front() -> void:
	var parent: Node = overlay.get_parent()
	if parent != null:
		parent.move_child(overlay, parent.get_child_count() - 1)


func _new_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.068, alpha)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _tr(key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key


func _tr_or(key: String, fallback: String) -> String:
	if key == "":
		return fallback
	if localizer != null and localizer.has_method("translate_or_fallback"):
		return str(localizer.translate_or_fallback(key, fallback))
	var translated: String = _tr(key)
	return fallback if translated == key and fallback != "" else translated
