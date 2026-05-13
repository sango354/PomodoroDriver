extends Node

signal break_interaction_viewed(dialogue_id: String)
signal break_interaction_skipped(dialogue_id: String)
signal break_interaction_advanced(from_id: String, to_id: String)
signal ambient_prompt_shown(dialogue_id: String)
signal ambient_prompt_dismissed(dialogue_id: String)

const CompanionDialogueService = preload("res://scripts/companion_dialogue_service.gd")

var companion_panel: PanelContainer
var companion_dialogue_label: Label
var title_label: Label
var next_button: Button
var skip_button: Button
var ambient_panel: PanelContainer
var ambient_dialogue_label: Label
var ambient_dismiss_button: Button
var break_dialogue_index := 0
var ambient_dialogue_index := 0
var localizer
var current_dialogue := {}
var current_ambient_dialogue := {}
var current_bond_level := 1
var current_context := {}
var interaction_history: Array = []


func setup(parent: Control, localization_service = null) -> void:
	localizer = localization_service
	_build_companion_panel(parent)
	_build_ambient_panel(parent)


func show_break_interaction(bond_level: int = 1, context: Dictionary = {}, history: Array = []) -> void:
	if companion_panel == null:
		return
	current_bond_level = bond_level
	current_context = context
	interaction_history = history
	current_dialogue = CompanionDialogueService.break_dialogue(
		break_dialogue_index,
		current_bond_level,
		current_context,
		interaction_history
	)
	var text_key := str(current_dialogue.get("text_key", ""))
	companion_dialogue_label.text = _tr(text_key) if text_key != "" else str(current_dialogue.get("text", ""))
	companion_panel.visible = true
	break_interaction_viewed.emit(str(current_dialogue.get("dialogue_id", "")))


func hide_break_interaction() -> void:
	if companion_panel != null:
		companion_panel.visible = false


func skip_break_interaction() -> void:
	break_interaction_skipped.emit(str(current_dialogue.get("dialogue_id", "")))
	hide_break_interaction()


func show_ambient_prompt(bond_level: int = 1, context: Dictionary = {}, history: Array = []) -> void:
	if ambient_panel == null or _is_break_visible():
		return
	current_bond_level = bond_level
	current_context = context
	interaction_history = history
	current_ambient_dialogue = CompanionDialogueService.ambient_dialogue(
		ambient_dialogue_index,
		current_bond_level,
		current_context,
		interaction_history,
		str(current_ambient_dialogue.get("dialogue_id", ""))
	)
	ambient_dialogue_index += 1
	var text_key := str(current_ambient_dialogue.get("text_key", ""))
	ambient_dialogue_label.text = _tr(text_key) if text_key != "" else str(current_ambient_dialogue.get("text", ""))
	ambient_panel.visible = true
	ambient_prompt_shown.emit(str(current_ambient_dialogue.get("dialogue_id", "")))


func hide_ambient_prompt(emit_dismissed: bool = false) -> void:
	if ambient_panel == null:
		return
	if emit_dismissed and ambient_panel.visible:
		ambient_prompt_dismissed.emit(str(current_ambient_dialogue.get("dialogue_id", "")))
	ambient_panel.visible = false


func is_ambient_prompt_visible() -> bool:
	return ambient_panel != null and ambient_panel.visible


func _show_next_break_dialogue() -> void:
	var from_id := str(current_dialogue.get("dialogue_id", ""))
	break_dialogue_index += 1
	current_dialogue = CompanionDialogueService.break_dialogue(
		break_dialogue_index,
		current_bond_level,
		current_context,
		interaction_history,
		from_id
	)
	var text_key := str(current_dialogue.get("text_key", ""))
	companion_dialogue_label.text = _tr(text_key) if text_key != "" else str(current_dialogue.get("text", ""))
	companion_panel.visible = true
	break_interaction_viewed.emit(str(current_dialogue.get("dialogue_id", "")))
	break_interaction_advanced.emit(from_id, str(current_dialogue.get("dialogue_id", "")))


func set_localizer(localization_service) -> void:
	localizer = localization_service
	if title_label != null:
		title_label.text = _tr("companion.break_title")
	if next_button != null:
		next_button.text = _tr("companion.next")
	if skip_button != null:
		skip_button.text = _tr("companion.skip")
	if ambient_dismiss_button != null:
		ambient_dismiss_button.text = _tr("companion.dismiss")
	if companion_panel != null and companion_panel.visible:
		show_break_interaction(current_bond_level, current_context, interaction_history)
	if ambient_panel != null and ambient_panel.visible:
		var text_key := str(current_ambient_dialogue.get("text_key", ""))
		ambient_dialogue_label.text = _tr(text_key) if text_key != "" else str(current_ambient_dialogue.get("text", ""))


func _build_companion_panel(parent: Control) -> void:
	companion_panel = _new_panel()
	companion_panel.name = "BreakCompanionPanel"
	companion_panel.visible = false
	companion_panel.anchor_left = 0.5
	companion_panel.anchor_top = 1.0
	companion_panel.anchor_right = 0.5
	companion_panel.anchor_bottom = 1.0
	companion_panel.offset_left = -220
	companion_panel.offset_top = -220
	companion_panel.offset_right = 220
	companion_panel.offset_bottom = -72
	parent.add_child(companion_panel)

	var box := _panel_box(companion_panel)
	title_label = _new_title(_tr("companion.break_title"))
	box.add_child(title_label)
	companion_dialogue_label = _new_muted_label("")
	companion_dialogue_label.custom_minimum_size = Vector2(0, 54)
	box.add_child(companion_dialogue_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	next_button = Button.new()
	next_button.text = _tr("companion.next")
	next_button.custom_minimum_size = Vector2(84, 30)
	next_button.pressed.connect(_show_next_break_dialogue)
	_add_hover_effect(next_button)
	buttons.add_child(next_button)

	skip_button = Button.new()
	skip_button.text = _tr("companion.skip")
	skip_button.custom_minimum_size = Vector2(84, 30)
	skip_button.pressed.connect(skip_break_interaction)
	_add_hover_effect(skip_button)
	buttons.add_child(skip_button)


func _build_ambient_panel(parent: Control) -> void:
	ambient_panel = _new_panel()
	ambient_panel.name = "AmbientCompanionPanel"
	ambient_panel.visible = false
	ambient_panel.anchor_left = 0.5
	ambient_panel.anchor_top = 1.0
	ambient_panel.anchor_right = 0.5
	ambient_panel.anchor_bottom = 1.0
	ambient_panel.offset_left = -220
	ambient_panel.offset_top = -150
	ambient_panel.offset_right = 220
	ambient_panel.offset_bottom = -72
	ambient_panel.z_index = 20
	parent.add_child(ambient_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	ambient_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	ambient_dialogue_label = _new_muted_label("")
	ambient_dialogue_label.custom_minimum_size = Vector2(330, 0)
	ambient_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ambient_dialogue_label)

	ambient_dismiss_button = Button.new()
	ambient_dismiss_button.text = _tr("companion.dismiss")
	ambient_dismiss_button.custom_minimum_size = Vector2(34, 30)
	ambient_dismiss_button.focus_mode = Control.FOCUS_NONE
	ambient_dismiss_button.pressed.connect(func(): hide_ambient_prompt(true))
	_add_hover_effect(ambient_dismiss_button)
	row.add_child(ambient_dismiss_button)


func _is_break_visible() -> bool:
	return companion_panel != null and companion_panel.visible


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
