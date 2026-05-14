extends Node

signal dialogue_selected(dialogue_id: String)
signal unlock_requested(dialogue_id: String)

var localizer
var dismiss_layer: Button
var panel: PanelContainer
var title_label: Label
var empty_label: Label
var content_box: VBoxContainer
var current_dialogues: Array = []
var viewed_ids: Array = []
var next_unlockable_ids: Array = []
var unlock_costs := {}
var current_focus_points := 0
var passenger_defs: Array = []
var locked_thumbnail_material: ShaderMaterial


func setup(parent: Control, localization_service = null) -> void:
	localizer = localization_service
	_build_dismiss_layer(parent)
	_build_panel(parent)
	hide_gallery()


func set_localizer(localization_service) -> void:
	localizer = localization_service
	refresh_text()
	if panel != null and panel.visible:
		_rebuild_items()


func show_gallery(dialogues: Array, viewed_dialogue_ids: Array, unlockable_dialogue_ids: Array = [], costs: Dictionary = {}, focus_points: int = 0, passengers: Array = []) -> void:
	current_dialogues = dialogues
	viewed_ids = viewed_dialogue_ids
	next_unlockable_ids = unlockable_dialogue_ids
	unlock_costs = costs
	current_focus_points = focus_points
	passenger_defs = passengers
	_rebuild_items()
	panel.visible = true
	dismiss_layer.visible = true
	_raise_to_front()


func hide_gallery() -> void:
	if panel != null:
		panel.visible = false
	if dismiss_layer != null:
		dismiss_layer.visible = false


func is_gallery_visible() -> bool:
	return panel != null and panel.visible


func contains_global_point(point: Vector2) -> bool:
	return panel != null and panel.visible and panel.get_global_rect().has_point(point)


func refresh_text() -> void:
	if title_label != null:
		title_label.text = _tr("avg.gallery.title")
	if empty_label != null:
		empty_label.text = _tr("avg.gallery.empty")


func _build_dismiss_layer(parent: Control) -> void:
	dismiss_layer = Button.new()
	dismiss_layer.name = "AVGGalleryDismissLayer"
	dismiss_layer.flat = true
	dismiss_layer.visible = false
	dismiss_layer.text = ""
	dismiss_layer.focus_mode = Control.FOCUS_NONE
	dismiss_layer.z_index = 260
	dismiss_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dismiss_layer.pressed.connect(hide_gallery)
	parent.add_child(dismiss_layer)


func _build_panel(parent: Control) -> void:
	panel = PanelContainer.new()
	panel.name = "AVGGalleryPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470
	panel.offset_top = -304
	panel.offset_right = 470
	panel.offset_bottom = 304
	panel.z_index = 280
	panel.add_theme_stylebox_override("panel", _new_panel_style(0.88))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	title_label = Label.new()
	title_label.text = _tr("avg.gallery.title")
	title_label.add_theme_font_size_override("font_size", 22)
	box.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 510)
	box.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 14)
	scroll.add_child(content_box)

	empty_label = Label.new()
	empty_label.text = _tr("avg.gallery.empty")
	empty_label.visible = false
	box.add_child(empty_label)


func _rebuild_items() -> void:
	if content_box == null:
		return
	for child in content_box.get_children():
		child.queue_free()
	empty_label.visible = current_dialogues.is_empty()
	if not passenger_defs.is_empty():
		_rebuild_passenger_rows()
		return
	for dialogue in current_dialogues:
		if typeof(dialogue) == TYPE_DICTIONARY:
			content_box.add_child(_new_dialogue_card(dialogue))


func _rebuild_passenger_rows() -> void:
	var dialogues_by_id := _dialogues_by_id()
	for passenger in passenger_defs:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 7)
		content_box.add_child(section)

		var passenger_title := Label.new()
		passenger_title.text = _passenger_name(passenger)
		passenger_title.add_theme_font_size_override("font_size", 18)
		passenger_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
		section.add_child(passenger_title)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		section.add_child(row)

		for event in passenger.get("gallery_sequence", []):
			if typeof(event) != TYPE_DICTIONARY:
				continue
			var dialogue_id := str(event.get("dialogue_id", ""))
			if not dialogues_by_id.has(dialogue_id):
				continue
			row.add_child(_new_dialogue_card(dialogues_by_id[dialogue_id]))


func _dialogues_by_id() -> Dictionary:
	var result := {}
	for dialogue in current_dialogues:
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		var dialogue_id := str(dialogue.get("dialogue_id", ""))
		if dialogue_id != "":
			result[dialogue_id] = dialogue
	return result


func _new_dialogue_card(dialogue: Dictionary) -> Control:
	var dialogue_id := str(dialogue.get("dialogue_id", ""))
	var viewed := viewed_ids.has(dialogue_id)
	var can_direct_unlock := not viewed and next_unlockable_ids.has(dialogue_id)
	var unlock_cost := int(unlock_costs.get(dialogue_id, 0))
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(190, 148)
	card.add_theme_constant_override("separation", 6)

	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(190, 92)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumbnail.texture = _load_texture(str(dialogue.get("thumbnail_path", "")))
	if not viewed:
		thumbnail.material = _locked_material()
	card.add_child(thumbnail)

	var button := Button.new()
	button.custom_minimum_size = Vector2(190, 34)
	if viewed:
		button.text = _dialogue_name(dialogue)
	elif can_direct_unlock:
		button.text = "Unlock %d FP" % unlock_cost
	else:
		button.text = _tr("avg.gallery.locked")
	button.tooltip_text = _dialogue_name(dialogue)
	button.disabled = not viewed and (not can_direct_unlock or current_focus_points < unlock_cost)
	button.pressed.connect(func():
		if viewed:
			dialogue_selected.emit(dialogue_id)
		else:
			unlock_requested.emit(dialogue_id)
	)
	_add_hover_effect(button)
	card.add_child(button)
	return card


func _dialogue_name(dialogue: Dictionary) -> String:
	var key := str(dialogue.get("display_name_key", ""))
	if key != "":
		return _tr_or(key, str(dialogue.get("display_name", "")))
	var display_name := str(dialogue.get("display_name", ""))
	if display_name != "":
		return display_name
	return str(dialogue.get("dialogue_id", ""))


func _passenger_name(passenger: Dictionary) -> String:
	var fallback := str(passenger.get("display_name", passenger.get("passenger_id", "")))
	return _tr_or(str(passenger.get("display_name_key", "")), fallback)


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


func _locked_material() -> ShaderMaterial:
	if locked_thumbnail_material != null:
		return locked_thumbnail_material
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 source = texture(TEXTURE, UV) * COLOR;\n\tfloat gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(vec3(gray * 0.48), source.a);\n}\n"
	locked_thumbnail_material = ShaderMaterial.new()
	locked_thumbnail_material.shader = shader
	return locked_thumbnail_material


func _add_hover_effect(control: Control) -> void:
	control.mouse_entered.connect(_on_hover_scale.bind(control, true))
	control.mouse_exited.connect(_on_hover_scale.bind(control, false))


func _on_hover_scale(control: Control, hovered: bool) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * (1.1 if hovered else 1.0)


func _raise_to_front() -> void:
	for node in [dismiss_layer, panel]:
		if node == null:
			continue
		var parent: Node = node.get_parent()
		if parent != null:
			parent.move_child(node, parent.get_child_count() - 1)


func _new_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.068, alpha)
	style.border_color = Color(1, 1, 1, 0.14)
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
