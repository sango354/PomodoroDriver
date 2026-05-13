extends Node

signal tasks_changed
signal task_renamed
signal task_completed(task_id: String)

const TaskService = preload("res://scripts/task_service.gd")

const TASK_PANEL_WIDTH := 390
const TASK_ITEM_WIDTH := 258
const TASK_PANEL_TOP := 54
const ICON_MISSION_PLUS_PATH := "res://assets/Arts/UI/Icon_missionplus.png"

var tasks: Array = []
var task_panel: Control
var task_list: VBoxContainer
var tasks_title_label: Label
var add_task_button: BaseButton
var localizer
var active_task_edit: LineEdit = null


func setup(parent: Control, task_data: Array, localization_service = null) -> void:
	tasks = task_data
	localizer = localization_service
	_build_task_panel(parent)


func set_localizer(localization_service) -> void:
	localizer = localization_service
	refresh_text()
	refresh_tasks()


func refresh_text() -> void:
	if tasks_title_label != null:
		tasks_title_label.text = _tr("tasks.title")
	if add_task_button != null:
		add_task_button.tooltip_text = _tr("tasks.add")


func refresh_tasks() -> void:
	if task_list == null:
		return
	for child in task_list.get_children():
		child.queue_free()

	var shown := 0
	for task in tasks:
		if task.status == "archived":
			continue
		if shown >= 5:
			break
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(TASK_ITEM_WIDTH + 64, 0)
		row.size_flags_horizontal = Control.SIZE_SHRINK_END
		task_list.add_child(row)

		var checkbox := CheckBox.new()
		checkbox.button_pressed = task.status == "done"
		checkbox.disabled = task.status == "done"
		checkbox.toggled.connect(_on_task_checkbox_toggled.bind(task.task_id))
		_add_hover_effect(checkbox)
		row.add_child(checkbox)

		var title_panel := PanelContainer.new()
		title_panel.custom_minimum_size = Vector2(TASK_ITEM_WIDTH, 0)
		title_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		title_panel.add_theme_stylebox_override("panel", _new_panel_style(0.72))
		row.add_child(title_panel)

		var title_margin := MarginContainer.new()
		title_margin.add_theme_constant_override("margin_left", 10)
		title_margin.add_theme_constant_override("margin_right", 10)
		title_margin.add_theme_constant_override("margin_top", 4)
		title_margin.add_theme_constant_override("margin_bottom", 4)
		title_panel.add_child(title_margin)

		var title_edit := LineEdit.new()
		var full_title := str(task.get("title", "Untitled"))
		title_edit.text = full_title
		title_edit.tooltip_text = full_title
		title_edit.custom_minimum_size = Vector2(TASK_ITEM_WIDTH - 22, 30)
		title_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		title_edit.expand_to_text_length = false
		title_edit.add_theme_stylebox_override("normal", _new_task_edit_style(false))
		title_edit.add_theme_stylebox_override("focus", _new_task_edit_style(true))
		title_edit.focus_entered.connect(_prepare_task_edit.bind(title_edit, task.task_id))
		title_edit.text_submitted.connect(_rename_task_submitted.bind(title_edit, task.task_id))
		title_edit.focus_exited.connect(_rename_task_from_edit.bind(title_edit, task.task_id))
		title_margin.add_child(title_edit)

		var archive := Button.new()
		archive.text = "x"
		archive.tooltip_text = _tr("tasks.archive")
		archive.custom_minimum_size = Vector2(32, 30)
		archive.pressed.connect(archive_task.bind(task.task_id))
		_add_hover_effect(archive)
		row.add_child(archive)


func set_panel_visible(is_visible: bool) -> void:
	if task_panel != null:
		task_panel.visible = is_visible


func create_task(title: String) -> void:
	var task := TaskService.create_task(tasks, title)
	if task.is_empty():
		return
	tasks.append(task)
	tasks_changed.emit()


func selected_task_id() -> String:
	return TaskService.selected_task_id(tasks)


func set_task_status(task_id: String, status: String) -> bool:
	return TaskService.set_task_status(tasks, task_id, status)


func task_title(task_id: String) -> String:
	return TaskService.task_title(tasks, task_id)


func task_status(task_id: String) -> String:
	return TaskService.task_status(tasks, task_id)


func archive_task(task_id: String) -> void:
	if set_task_status(task_id, "archived"):
		tasks_changed.emit()


func complete_task(task_id: String) -> void:
	if set_task_status(task_id, "done"):
		task_completed.emit(task_id)
		tasks_changed.emit()


func _build_task_panel(parent: Control) -> void:
	var box := VBoxContainer.new()
	task_panel = box
	box.anchor_left = 1.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 0.0
	box.offset_left = -TASK_PANEL_WIDTH
	box.offset_top = TASK_PANEL_TOP
	box.offset_right = 0
	box.offset_bottom = TASK_PANEL_TOP + 284
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	tasks_title_label = _new_title(_tr("tasks.title"))
	tasks_title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tasks_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	tasks_title_label.add_theme_constant_override("shadow_offset_x", 2)
	tasks_title_label.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(tasks_title_label)

	add_task_button = _new_icon_asset_button(ICON_MISSION_PLUS_PATH, _tr("tasks.add"), Vector2(34, 32))
	add_task_button.tooltip_text = _tr("tasks.add")
	add_task_button.pressed.connect(func(): create_task(_tr("tasks.default_title")))
	header.add_child(add_task_button)

	task_list = VBoxContainer.new()
	task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_list.add_theme_constant_override("separation", 6)
	box.add_child(task_list)


func _on_task_checkbox_toggled(pressed: bool, task_id: String) -> void:
	if pressed:
		complete_task(task_id)


func _rename_task_from_edit(edit: LineEdit, task_id: String) -> void:
	var saved_title := _rename_task(edit.text, task_id)
	edit.text = saved_title
	edit.tooltip_text = saved_title
	if active_task_edit == edit:
		active_task_edit = null


func _rename_task_submitted(new_title: String, edit: LineEdit, task_id: String) -> void:
	var saved_title := _rename_task(new_title, task_id)
	edit.text = saved_title
	edit.tooltip_text = saved_title
	edit.release_focus()


func _prepare_task_edit(edit: LineEdit, task_id: String) -> void:
	active_task_edit = edit
	var full_title := task_title(task_id)
	edit.text = full_title
	edit.tooltip_text = full_title
	edit.caret_column = edit.text.length()


func _input(event: InputEvent) -> void:
	if active_task_edit == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if active_task_edit.get_global_rect().has_point(event.position):
			return
		active_task_edit.release_focus()


func _rename_task(new_title: String, task_id: String) -> String:
	var saved_title: String = TaskService.rename_task(tasks, new_title, task_id, _tr("tasks.default_title"))
	task_renamed.emit()
	return saved_title


func _new_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label


func _new_icon_asset_button(icon_path: String, tip: String, size: Vector2) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _load_texture(icon_path)
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.texture_disabled = button.texture_normal
	button.tooltip_text = tip
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_add_hover_effect(button)
	return button


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _add_hover_effect(control: Control) -> void:
	control.mouse_entered.connect(_on_hover_scale.bind(control, true))
	control.mouse_exited.connect(_on_hover_scale.bind(control, false))


func _on_hover_scale(control: Control, hovered: bool) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * (1.1 if hovered else 1.0)


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


func _new_task_edit_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.068, 0.72)
	style.border_color = Color(1, 1, 1, 0.78) if focused else Color(1, 1, 1, 0.0)
	style.set_border_width_all(2 if focused else 0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _tr(key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key
