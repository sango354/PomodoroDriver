extends Node

signal answer_selected(answer: Dictionary)
signal answer_response_finished
signal quiz_dismissed

const ANSWER_RESPONSE_SECONDS := 2.0

var dismiss_layer: Button
var question_bubble: PanelContainer
var status_panel: Control
var narration_panel: PanelContainer
var answer_panel: Control
var round_label: Label
var question_label: Label
var narration_label: Label
var emotion_bar: ProgressBar
var alert_bar: ProgressBar
var emotion_value_label: Label
var alert_value_label: Label
var answer_box: VBoxContainer
var answer_response_active := false
var localizer


func setup(parent: Control, localization_service = null) -> void:
	localizer = localization_service
	_build_dismiss_layer(parent)
	_build_panel(parent)
	hide_quiz()


func set_localizer(localization_service) -> void:
	localizer = localization_service


func show_question(_passenger_name: String, question: Dictionary, round_index: int, round_total: int, emotion: int, alert: int) -> void:
	answer_response_active = false
	round_label.text = "Round %d/%d" % [round_index, round_total]
	var passenger_text := _localized_field(question, "question_text")
	question_label.text = passenger_text
	emotion_bar.value = clamp(emotion, 0, 100)
	alert_bar.value = clamp(alert, 0, 100)
	emotion_value_label.text = "Emotion %d / 100" % emotion
	alert_value_label.text = "Alert %d / 100" % alert
	var narration_text := _question_narration_text(question)
	narration_label.text = narration_text
	narration_panel.visible = narration_text != ""
	_rebuild_answers(question.get("answers", []))
	question_bubble.visible = passenger_text != ""
	status_panel.visible = true
	answer_panel.visible = true
	dismiss_layer.visible = true
	_raise_to_front()


func hide_quiz() -> void:
	answer_response_active = false
	if question_bubble != null:
		question_bubble.visible = false
	if status_panel != null:
		status_panel.visible = false
	if narration_panel != null:
		narration_panel.visible = false
	if answer_panel != null:
		answer_panel.visible = false
	if dismiss_layer != null:
		dismiss_layer.visible = false


func is_visible() -> bool:
	return answer_panel != null and answer_panel.visible


func _build_dismiss_layer(parent: Control) -> void:
	dismiss_layer = Button.new()
	dismiss_layer.name = "PassengerQuizDismissLayer"
	dismiss_layer.flat = true
	dismiss_layer.text = ""
	dismiss_layer.focus_mode = Control.FOCUS_NONE
	dismiss_layer.visible = false
	dismiss_layer.z_index = 300
	dismiss_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dismiss_layer)


func _build_panel(parent: Control) -> void:
	_build_question_bubble(parent)
	_build_status_panel(parent)
	_build_narration_panel(parent)
	_build_answer_panel(parent)


func _build_question_bubble(parent: Control) -> void:
	question_bubble = PanelContainer.new()
	question_bubble.name = "PassengerQuizQuestionBubble"
	question_bubble.anchor_left = 0.0
	question_bubble.anchor_top = 0.0
	question_bubble.anchor_right = 0.0
	question_bubble.anchor_bottom = 0.0
	question_bubble.offset_left = 58
	question_bubble.offset_top = 102
	question_bubble.offset_right = 478
	question_bubble.offset_bottom = 182
	question_bubble.z_index = 320
	question_bubble.add_theme_stylebox_override("panel", _new_bubble_style())
	parent.add_child(question_bubble)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	question_bubble.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	question_label = Label.new()
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.custom_minimum_size = Vector2(0, 44)
	question_label.add_theme_font_size_override("font_size", 18)
	box.add_child(question_label)


func _build_status_panel(parent: Control) -> void:
	status_panel = Control.new()
	status_panel.name = "PassengerQuizStatusPanel"
	status_panel.anchor_left = 0.5
	status_panel.anchor_top = 1.0
	status_panel.anchor_right = 0.5
	status_panel.anchor_bottom = 1.0
	status_panel.offset_left = -470
	status_panel.offset_top = -172
	status_panel.offset_right = -300
	status_panel.offset_bottom = -60
	status_panel.z_index = 320
	parent.add_child(status_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	status_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	round_label.add_theme_font_size_override("font_size", 18)
	_apply_status_text_outline(round_label)
	box.add_child(round_label)

	var meters := VBoxContainer.new()
	meters.add_theme_constant_override("separation", 7)
	box.add_child(meters)

	var emotion_meter := _new_meter_stack(Color(0.92, 0.35, 0.62, 1.0))
	emotion_bar = emotion_meter.get("bar") as ProgressBar
	emotion_value_label = emotion_meter.get("label") as Label
	meters.add_child(emotion_meter.get("root") as Control)

	var alert_meter := _new_meter_stack(Color(0.95, 0.76, 0.25, 1.0))
	alert_bar = alert_meter.get("bar") as ProgressBar
	alert_value_label = alert_meter.get("label") as Label
	meters.add_child(alert_meter.get("root") as Control)


func _build_narration_panel(parent: Control) -> void:
	narration_panel = PanelContainer.new()
	narration_panel.name = "PassengerQuizNarrationPanel"
	narration_panel.anchor_left = 0.5
	narration_panel.anchor_top = 1.0
	narration_panel.anchor_right = 0.5
	narration_panel.anchor_bottom = 1.0
	narration_panel.offset_left = -220
	narration_panel.offset_top = -228
	narration_panel.offset_right = 310
	narration_panel.offset_bottom = -182
	narration_panel.z_index = 320
	narration_panel.add_theme_stylebox_override("panel", _new_narration_style())
	parent.add_child(narration_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	narration_panel.add_child(margin)

	narration_label = Label.new()
	narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narration_label.add_theme_font_size_override("font_size", 15)
	margin.add_child(narration_label)


func _build_answer_panel(parent: Control) -> void:
	answer_panel = Control.new()
	answer_panel.name = "PassengerQuizAnswerPanel"
	answer_panel.anchor_left = 0.5
	answer_panel.anchor_top = 1.0
	answer_panel.anchor_right = 0.5
	answer_panel.anchor_bottom = 1.0
	answer_panel.offset_left = -220
	answer_panel.offset_top = -172
	answer_panel.offset_right = 310
	answer_panel.offset_bottom = -2
	answer_panel.z_index = 320
	parent.add_child(answer_panel)

	answer_box = VBoxContainer.new()
	answer_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	answer_box.add_theme_constant_override("separation", 8)
	answer_panel.add_child(answer_box)


func _new_meter(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.12)
	background.corner_radius_top_left = 7
	background.corner_radius_top_right = 7
	background.corner_radius_bottom_left = 7
	background.corner_radius_bottom_right = 7
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 7
	fill.corner_radius_top_right = 7
	fill.corner_radius_bottom_left = 7
	fill.corner_radius_bottom_right = 7
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _new_meter_stack(fill_color: Color) -> Dictionary:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 24)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar := _new_meter(fill_color)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(bar)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	_apply_status_text_outline(label)
	stack.add_child(label)

	return {
		"root": stack,
		"bar": bar,
		"label": label
	}


func _apply_status_text_outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.78))


func _question_narration_text(question: Dictionary) -> String:
	for key in ["narration_text", "driver_monologue", "scene_text", "description_text", "status_text"]:
		var text := _localized_field(question, key)
		if text != "":
			return text
	return ""


func _rebuild_answers(answers: Array) -> void:
	for child in answer_box.get_children():
		child.queue_free()
	for answer in answers:
		if typeof(answer) != TYPE_DICTIONARY:
			continue
		var button := Button.new()
		button.text = _localized_field(answer, "text")
		button.custom_minimum_size = Vector2(0, 42)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_stylebox_override("normal", _new_answer_style(Color(0.035, 0.037, 0.042, 0.62), Color(1, 1, 1, 0.13)))
		button.add_theme_stylebox_override("hover", _new_answer_style(Color(0.12, 0.09, 0.105, 0.74), Color(1.0, 0.72, 0.62, 0.38)))
		button.add_theme_stylebox_override("pressed", _new_answer_style(Color(0.18, 0.10, 0.12, 0.82), Color(1.0, 0.72, 0.62, 0.52)))
		button.add_theme_stylebox_override("disabled", _new_answer_style(Color(0.035, 0.037, 0.042, 0.34), Color(1, 1, 1, 0.06)))
		button.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		button.add_theme_color_override("font_hover_color", Color(1, 0.88, 0.82, 1.0))
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.42))
		button.add_theme_constant_override("h_separation", 12)
		button.tooltip_text = "Emotion %+d / Alert %+d" % [
			int(answer.get("emotion_delta", 0)),
			int(answer.get("alert_delta", 0))
		]
		button.pressed.connect(func():
			_show_answer_response(answer, button)
		)
		_add_hover_effect(button)
		answer_box.add_child(button)


func _show_answer_response(answer: Dictionary, selected_button: Button) -> void:
	if answer_response_active:
		return
	answer_response_active = true
	_set_answers_locked(selected_button)
	_apply_answer_preview(answer)
	answer_selected.emit(answer)
	var response_text := _localized_field(answer, "response_text")
	if response_text == "":
		answer_response_active = false
		answer_response_finished.emit()
		return
	question_label.text = response_text
	question_bubble.visible = true
	await get_tree().create_timer(ANSWER_RESPONSE_SECONDS).timeout
	if not answer_response_active:
		return
	answer_response_active = false
	answer_response_finished.emit()


func _set_answers_locked(selected_button: Button) -> void:
	for child in answer_box.get_children():
		var button := child as Button
		if button == null:
			continue
		button.disabled = true
		button.scale = Vector2.ONE
		if button == selected_button:
			button.add_theme_stylebox_override("disabled", _new_answer_style(Color(0.19, 0.105, 0.125, 0.88), Color(1.0, 0.72, 0.62, 0.72)))
			button.add_theme_color_override("font_disabled_color", Color(1.0, 0.9, 0.84, 1.0))
		else:
			button.add_theme_stylebox_override("disabled", _new_answer_style(Color(0.025, 0.027, 0.032, 0.30), Color(1, 1, 1, 0.045)))
			button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.32))


func _apply_answer_preview(answer: Dictionary) -> void:
	var emotion: int = clamp(int(emotion_bar.value) + int(answer.get("emotion_delta", 0)), 0, 100)
	var alert: int = clamp(int(alert_bar.value) + int(answer.get("alert_delta", 0)), 0, 100)
	emotion_bar.value = emotion
	alert_bar.value = alert
	emotion_value_label.text = "Emotion %d / 100" % emotion
	alert_value_label.text = "Alert %d / 100" % alert


func _localized_field(source: Dictionary, field: String) -> String:
	var fallback := str(source.get(field, "")).strip_edges()
	var key := str(source.get("%s_key" % field, "")).strip_edges()
	if key == "":
		return fallback
	if localizer != null and localizer.has_method("translate_or_fallback"):
		return str(localizer.translate_or_fallback(key, fallback)).strip_edges()
	if localizer != null:
		var translated: String = str(localizer.translate(key)).strip_edges()
		return fallback if translated == key and fallback != "" else translated
	return fallback


func _add_hover_effect(control: Control) -> void:
	control.mouse_entered.connect(_on_hover_scale.bind(control, true))
	control.mouse_exited.connect(_on_hover_scale.bind(control, false))


func _on_hover_scale(control: Control, hovered: bool) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * (1.04 if hovered else 1.0)


func _raise_to_front() -> void:
	for node in [dismiss_layer, question_bubble, status_panel, narration_panel, answer_panel]:
		if node == null:
			continue
		var parent: Node = node.get_parent()
		if parent != null:
			parent.move_child(node, parent.get_child_count() - 1)


func _new_bubble_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.043, 0.05, 0.82)
	style.border_color = Color(1, 0.86, 0.72, 0.34)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


func _new_status_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.038, 0.045, 0.58)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _new_narration_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.037, 0.043, 0.66)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _new_answer_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style
