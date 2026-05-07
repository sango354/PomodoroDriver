extends Node

signal dialogue_selected(dialogue_id: String)

var localizer
var dismiss_layer: Button
var panel: PanelContainer
var title_label: Label
var empty_label: Label
var grid: GridContainer
var current_dialogues: Array = []
var viewed_ids: Array = []
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


func show_gallery(dialogues: Array, viewed_dialogue_ids: Array) -> void:
	current_dialogues = dialogues
	viewed_ids = viewed_dialogue_ids
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
	panel.offset_left = -330
	panel.offset_top = -236
	panel.offset_right = 330
	panel.offset_bottom = 236
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
	scroll.custom_minimum_size = Vector2(0, 382)
	box.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	empty_label = Label.new()
	empty_label.text = _tr("avg.gallery.empty")
	empty_label.visible = false
	box.add_child(empty_label)


func _rebuild_items() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	empty_label.visible = current_dialogues.is_empty()
	for dialogue in current_dialogues:
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		grid.add_child(_new_dialogue_card(dialogue))


func _new_dialogue_card(dialogue: Dictionary) -> Control:
	var dialogue_id := str(dialogue.get("dialogue_id", ""))
	var viewed := viewed_ids.has(dialogue_id)
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
	button.text = _dialogue_name(dialogue) if viewed else _tr("avg.gallery.locked")
	button.tooltip_text = _dialogue_name(dialogue)
	button.disabled = not viewed
	button.pressed.connect(func(): dialogue_selected.emit(dialogue_id))
	card.add_child(button)
	return card


func _dialogue_name(dialogue: Dictionary) -> String:
	var display_name := str(dialogue.get("display_name", ""))
	if display_name != "":
		return display_name
	var key := str(dialogue.get("display_name_key", ""))
	if key != "":
		return _tr(key)
	return str(dialogue.get("dialogue_id", ""))


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
