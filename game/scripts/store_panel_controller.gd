extends Node

signal purchase_requested(content_id)

var localizer
var dismiss_layer: Button
var panel: PanelContainer
var title_label: Label
var item_list: VBoxContainer
var status_label: Label
var confirm_dismiss_layer: Button
var confirm_panel: PanelContainer
var confirm_title: Label
var confirm_body: Label
var confirm_buy_button: Button
var confirm_cancel_button: Button
var selected_item := {}
var current_items: Array = []


func setup(parent: Control, localization_service = null) -> void:
	localizer = localization_service
	_build_dismiss_layer(parent)
	_build_panel(parent)
	_build_confirm(parent)
	hide_store()


func set_localizer(localization_service) -> void:
	localizer = localization_service
	refresh_text()


func show_store(items: Array) -> void:
	current_items = items
	_rebuild_items()
	status_label.text = ""
	panel.visible = true
	dismiss_layer.visible = true
	_raise_to_front()


func hide_store() -> void:
	_hide_confirm()
	if panel != null:
		panel.visible = false
	if dismiss_layer != null:
		dismiss_layer.visible = false


func is_store_visible() -> bool:
	return panel != null and panel.visible


func show_status(text: String) -> void:
	status_label.text = text


func refresh_items(items: Array) -> void:
	current_items = items
	if panel != null and panel.visible:
		_rebuild_items()


func refresh_text() -> void:
	if title_label != null:
		title_label.text = _tr("store.title")
	if confirm_title != null:
		confirm_title.text = _tr("store.confirm_title")
	if confirm_buy_button != null:
		confirm_buy_button.text = _tr("store.buy")
	if confirm_cancel_button != null:
		confirm_cancel_button.text = _tr("store.cancel")
	if not selected_item.is_empty():
		_refresh_confirm_body()
	if panel != null and panel.visible:
		_rebuild_items()


func _build_dismiss_layer(parent: Control) -> void:
	dismiss_layer = Button.new()
	dismiss_layer.name = "StoreDismissLayer"
	dismiss_layer.flat = true
	dismiss_layer.visible = false
	dismiss_layer.text = ""
	dismiss_layer.focus_mode = Control.FOCUS_NONE
	dismiss_layer.z_index = 180
	dismiss_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dismiss_layer.pressed.connect(hide_store)
	parent.add_child(dismiss_layer)


func _build_panel(parent: Control) -> void:
	panel = PanelContainer.new()
	panel.name = "StorePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_top = -210
	panel.offset_right = 190
	panel.offset_bottom = 210
	panel.z_index = 200
	panel.add_theme_stylebox_override("panel", _new_panel_style(0.78))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	title_label = Label.new()
	title_label.text = _tr("store.title")
	title_label.add_theme_font_size_override("font_size", 20)
	box.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	box.add_child(scroll)
	item_list = VBoxContainer.new()
	item_list.add_theme_constant_override("separation", 8)
	scroll.add_child(item_list)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.74, 0.95))
	box.add_child(status_label)


func _build_confirm(parent: Control) -> void:
	confirm_dismiss_layer = Button.new()
	confirm_dismiss_layer.name = "StoreConfirmDismissLayer"
	confirm_dismiss_layer.flat = true
	confirm_dismiss_layer.visible = false
	confirm_dismiss_layer.text = ""
	confirm_dismiss_layer.focus_mode = Control.FOCUS_NONE
	confirm_dismiss_layer.z_index = 220
	confirm_dismiss_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_dismiss_layer.pressed.connect(_hide_confirm)
	parent.add_child(confirm_dismiss_layer)

	confirm_panel = PanelContainer.new()
	confirm_panel.name = "StoreConfirmPanel"
	confirm_panel.anchor_left = 0.5
	confirm_panel.anchor_top = 0.5
	confirm_panel.anchor_right = 0.5
	confirm_panel.anchor_bottom = 0.5
	confirm_panel.offset_left = -170
	confirm_panel.offset_top = -92
	confirm_panel.offset_right = 170
	confirm_panel.offset_bottom = 92
	confirm_panel.z_index = 240
	confirm_panel.add_theme_stylebox_override("panel", _new_panel_style(0.9))
	confirm_panel.visible = false
	parent.add_child(confirm_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	confirm_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	confirm_title = Label.new()
	confirm_title.text = _tr("store.confirm_title")
	confirm_title.add_theme_font_size_override("font_size", 18)
	box.add_child(confirm_title)

	confirm_body = Label.new()
	confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(confirm_body)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	confirm_buy_button = Button.new()
	confirm_buy_button.text = _tr("store.buy")
	confirm_buy_button.custom_minimum_size = Vector2(96, 30)
	confirm_buy_button.pressed.connect(_confirm_purchase)
	_add_hover_effect(confirm_buy_button)
	buttons.add_child(confirm_buy_button)

	confirm_cancel_button = Button.new()
	confirm_cancel_button.text = _tr("store.cancel")
	confirm_cancel_button.custom_minimum_size = Vector2(96, 30)
	confirm_cancel_button.pressed.connect(_hide_confirm)
	_add_hover_effect(confirm_cancel_button)
	buttons.add_child(confirm_cancel_button)


func _rebuild_items() -> void:
	for child in item_list.get_children():
		child.queue_free()
	if current_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = _tr("store.no_items")
		item_list.add_child(empty_label)
		return
	for item in current_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 36)
		button.text = _item_text(item)
		button.disabled = bool(item.get("unlocked", false))
		button.pressed.connect(_show_confirm.bind(item))
		_add_hover_effect(button)
		item_list.add_child(button)


func _item_text(item: Dictionary) -> String:
	var name := str(item.get("name", ""))
	if bool(item.get("unlocked", false)):
		return "%s  -  %s" % [name, _tr("store.unlocked")]
	return "%s  -  %s" % [name, _trf("store.cost", {"focus_points": int(item.get("cost_focus_points", 0))})]


func _show_confirm(item: Dictionary) -> void:
	selected_item = item
	_refresh_confirm_body()
	confirm_panel.visible = true
	confirm_dismiss_layer.visible = true


func _hide_confirm() -> void:
	selected_item = {}
	if confirm_panel != null:
		confirm_panel.visible = false
	if confirm_dismiss_layer != null:
		confirm_dismiss_layer.visible = false


func _refresh_confirm_body() -> void:
	confirm_body.text = _trf("store.purchase_confirm", {
		"name": str(selected_item.get("name", "")),
		"focus_points": int(selected_item.get("cost_focus_points", 0))
	})


func _confirm_purchase() -> void:
	if selected_item.is_empty():
		return
	var content_id := str(selected_item.get("content_id", ""))
	_hide_confirm()
	purchase_requested.emit(content_id)


func _raise_to_front() -> void:
	for node in [dismiss_layer, panel, confirm_dismiss_layer, confirm_panel]:
		if node == null:
			continue
		var parent: Node = node.get_parent()
		if parent != null:
			parent.move_child(node, parent.get_child_count() - 1)


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


func _tr(key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key


func _trf(key: String, values: Dictionary) -> String:
	if localizer != null:
		return localizer.trf(key, values)
	var text := key
	for value_key in values.keys():
		text = text.replace("{%s}" % str(value_key), str(values[value_key]))
	return text
