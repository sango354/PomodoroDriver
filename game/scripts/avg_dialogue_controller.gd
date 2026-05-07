extends Node

signal dialogue_finished(dialogue_id: String)

var localizer
var overlay: Control
var dim_rect: ColorRect
var background_rect: TextureRect
var speaker_label: Label
var dialogue_label: Label
var prompt_label: Label
var current_dialogue := {}
var current_line_index := 0
var transition_next_background := false
var transition_duration := 2.0


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
	var line = lines[clamp(current_line_index, 0, lines.size() - 1)]
	if typeof(line) != TYPE_DICTIONARY:
		_finish_dialogue()
		return
	var speaker_key := str(line.get("speaker_key", ""))
	var text_key := str(line.get("text_key", ""))
	var background_path := str(line.get("background_path", current_dialogue.get("background_path", "")))
	_apply_overlay_backdrop(background_path)
	speaker_label.text = _tr(speaker_key) if speaker_key != "" else str(line.get("speaker", ""))
	dialogue_label.text = _tr(text_key) if text_key != "" else str(line.get("text", ""))
	_set_background(background_path)


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


func _set_background(path: String) -> void:
	var texture := _load_texture(path)
	if transition_next_background:
		transition_next_background = false
		var half_duration: float = max(transition_duration * 0.5, 0.01)
		background_rect.visible = true
		var tween := create_tween()
		tween.tween_property(background_rect, "modulate:a", 0.0, half_duration)
		tween.tween_callback(func():
			background_rect.texture = texture
			background_rect.visible = texture != null
		)
		tween.tween_property(background_rect, "modulate:a", 1.0, half_duration)
		return
	transition_next_background = false
	background_rect.texture = texture
	background_rect.visible = texture != null
	background_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _apply_overlay_backdrop(background_path: String) -> void:
	if dim_rect == null:
		return
	if bool(current_dialogue.get("transparent_overlay", false)) or background_path == "":
		dim_rect.color = Color(0, 0, 0, 0.0)
	else:
		dim_rect.color = Color(0, 0, 0, 1.0)


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
