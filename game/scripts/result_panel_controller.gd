extends Node

signal mark_task_done_pressed
signal break_pressed

var result_dismiss_layer: Button
var result_panel: PanelContainer
var result_title: Label
var result_rewards: Label
var mark_task_done_button: Button
var break_button: Button
var localizer
var result_dismissed := true
var current_status := ""


func setup(parent: Control, localization_service = null) -> void:
	localizer = localization_service
	_build_result_dismiss_layer(parent)
	_build_result_panel(parent)
	hide_result()


func set_localizer(localization_service) -> void:
	localizer = localization_service
	refresh_text()


func refresh_text() -> void:
	if mark_task_done_button != null:
		mark_task_done_button.text = _tr("result.mark_task_done")
	if break_button != null:
		break_button.text = _tr("result.start_break")
	if result_title != null:
		result_title.text = _status_title(current_status) if current_status != "" else _tr("result.title")


func show_result(status: String, rewards_text: String, can_mark_task_done: bool, can_start_break: bool) -> void:
	current_status = status
	result_dismissed = false
	result_title.text = _status_title(status)
	result_rewards.text = rewards_text
	result_panel.visible = true
	result_dismiss_layer.visible = true
	mark_task_done_button.disabled = not can_mark_task_done
	break_button.disabled = not can_start_break


func hide_result() -> void:
	result_dismissed = true
	if result_panel != null:
		result_panel.visible = false
	if result_dismiss_layer != null:
		result_dismiss_layer.visible = false


func refresh_controls(app_state: String, active_task_id: String, active_task_done: bool) -> void:
	var show_result := current_status != "" and not result_dismissed
	if result_panel != null:
		result_panel.visible = show_result
	if result_dismiss_layer != null:
		result_dismiss_layer.visible = show_result
	if mark_task_done_button != null:
		mark_task_done_button.disabled = active_task_id == "" or active_task_done
	if break_button != null:
		break_button.disabled = app_state == "running" or current_status == "abandoned"


func is_result_visible() -> bool:
	return result_panel != null and result_panel.visible


func append_reward_line(text: String) -> void:
	if result_rewards != null:
		result_rewards.text += "\n%s" % text


func _build_result_panel(parent: Control) -> void:
	result_panel = _new_panel()
	result_panel.anchor_left = 0.0
	result_panel.anchor_top = 1.0
	result_panel.anchor_right = 0.0
	result_panel.anchor_bottom = 1.0
	result_panel.offset_left = 0
	result_panel.offset_top = -300
	result_panel.offset_right = 430
	result_panel.offset_bottom = -82
	parent.add_child(result_panel)
	var box := _panel_box(result_panel)
	result_title = _new_title(_tr("result.title"))
	box.add_child(result_title)
	result_rewards = _new_muted_label("")
	box.add_child(result_rewards)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	mark_task_done_button = Button.new()
	mark_task_done_button.text = _tr("result.mark_task_done")
	mark_task_done_button.custom_minimum_size = Vector2(126, 30)
	mark_task_done_button.pressed.connect(func(): mark_task_done_pressed.emit())
	_add_hover_effect(mark_task_done_button)
	buttons.add_child(mark_task_done_button)

	break_button = Button.new()
	break_button.text = _tr("result.start_break")
	break_button.custom_minimum_size = Vector2(104, 30)
	break_button.pressed.connect(func(): break_pressed.emit())
	_add_hover_effect(break_button)
	buttons.add_child(break_button)


func _build_result_dismiss_layer(parent: Control) -> void:
	result_dismiss_layer = Button.new()
	result_dismiss_layer.name = "ResultDismissLayer"
	result_dismiss_layer.flat = true
	result_dismiss_layer.visible = false
	result_dismiss_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dismiss_layer.text = ""
	result_dismiss_layer.focus_mode = Control.FOCUS_NONE
	result_dismiss_layer.pressed.connect(hide_result)
	parent.add_child(result_dismiss_layer)


func _new_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _new_panel_style(0.62))
	return panel


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


func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box


func _new_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label


func _new_muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9, 0.92))
	return label


func _status_title(status: String) -> String:
	return _tr("timer.state_%s" % status)


func _add_hover_effect(control: Control) -> void:
	control.mouse_entered.connect(_on_hover_scale.bind(control, true))
	control.mouse_exited.connect(_on_hover_scale.bind(control, false))


func _on_hover_scale(control: Control, hovered: bool) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * (1.1 if hovered else 1.0)


func _tr(key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key
