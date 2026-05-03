extends SceneTree

const SKELETON_PATH := "res://assets/spine/backgrounds/Room/Room.skel"
const ATLAS_PATH := "res://assets/spine/backgrounds/Room/Room.atlas"


func _initialize() -> void:
	print("Room skeleton exists: ", FileAccess.file_exists(SKELETON_PATH))
	print("Room atlas exists: ", FileAccess.file_exists(ATLAS_PATH))
	print("SpineSprite: ", ClassDB.class_exists("SpineSprite"))
	print("SpineSkeletonDataResource: ", ClassDB.class_exists("SpineSkeletonDataResource"))

	var skeleton_res := ResourceLoader.load(SKELETON_PATH)
	var atlas_res := ResourceLoader.load(ATLAS_PATH)
	print("Skeleton loaded: ", skeleton_res != null)
	print("Atlas loaded: ", atlas_res != null)
	if skeleton_res == null or atlas_res == null:
		quit(1)
		return

	var data_res := ClassDB.instantiate("SpineSkeletonDataResource") as Resource
	data_res.set("skeleton_file_res", skeleton_res)
	data_res.set("atlas_res", atlas_res)

	var sprite := ClassDB.instantiate("SpineSprite") as Node
	sprite.set("skeleton_data_res", data_res)
	root.add_child(sprite)

	var skeleton = sprite.get_skeleton()
	var skeleton_data = skeleton.get_data() if skeleton != null else null
	if skeleton_data == null:
		print("Skeleton data unavailable.")
		quit(1)
		return

	_print_methods("SpineSkeletonData", skeleton_data)
	_print_animations(skeleton_data)
	_print_skins(skeleton_data)
	_print_slots(skeleton_data)
	_print_bg_slot_methods(skeleton)
	_print_animation_bg_mapping(sprite, skeleton_data)
	quit()


func _print_methods(label: String, object) -> void:
	var names: Array[String] = []
	for method in object.get_method_list():
		var method_name := str(method.name)
		if method_name.contains("animation") or method_name.contains("skin") or method_name.contains("slot") or method_name.contains("attachment") or method_name.contains("event"):
			names.append(method_name)
	names.sort()
	print("%s relevant methods: %s" % [label, names])


func _print_animations(skeleton_data) -> void:
	var names: Array[String] = []
	for animation in skeleton_data.get_animations():
		names.append(animation.get_name())
	print("Animations: ", names)


func _print_skins(skeleton_data) -> void:
	if not skeleton_data.has_method("get_skins"):
		print("Skins: method unavailable")
		return
	var names: Array[String] = []
	for skin in skeleton_data.get_skins():
		names.append(skin.get_name())
	print("Skins: ", names)


func _print_slots(skeleton_data) -> void:
	if not skeleton_data.has_method("get_slots"):
		print("Slots: method unavailable")
		return
	var names: Array[String] = []
	for slot in skeleton_data.get_slots():
		names.append(slot.get_name())
	print("Slots: ", names)


func _print_bg_slot_methods(skeleton) -> void:
	if not skeleton.has_method("find_slot"):
		print("find_slot unavailable")
		return
	var slot = skeleton.find_slot("BG_A_01")
	if slot == null:
		print("BG_A_01 slot unavailable")
		return
	_print_methods("BG_A_01 slot", slot)


func _print_animation_bg_mapping(sprite: Node, skeleton_data) -> void:
	var state = sprite.get_animation_state()
	var skeleton = sprite.get_skeleton()
	if state == null or skeleton == null:
		print("Animation state or skeleton unavailable")
		return
	var bg_slots := ["BG_A_01", "BG_A_02", "BG_A_03", "BG_B", "BG_B_01"]
	for animation in skeleton_data.get_animations():
		var animation_name: String = animation.get_name()
		state.set_animation(animation_name, false, 0)
		state.update(0.0)
		state.apply(skeleton)
		skeleton.update_world_transform()
		var attachments := []
		for slot_name in bg_slots:
			var slot = skeleton.find_slot(slot_name) if skeleton.has_method("find_slot") else null
			if slot == null:
				continue
			var attachment_name := _slot_attachment_name(slot)
			if attachment_name != "":
				attachments.append("%s=%s" % [slot_name, attachment_name])
		print("Animation BG mapping: %s -> %s" % [animation_name, attachments])


func _slot_attachment_name(slot) -> String:
	if slot.has_method("get_attachment"):
		var attachment = slot.get_attachment()
		if attachment != null:
			if attachment.has_method("get_name"):
				return str(attachment.get_name())
			return str(attachment)
	if slot.has_method("get_attachment_name"):
		return str(slot.get_attachment_name())
	return ""
