extends RefCounted

const COMPONENT_FLOAT := 5126
const COMPONENT_UNSIGNED_SHORT := 5123
const COMPONENT_UNSIGNED_INT := 5125
const GENERATED_TEXTURE_ROOT := "res://assets/Generated/JapaneseStreet3D/Textures"
const SOURCE_TEXTURE_ROOT := "res://assets/Japanese_Street/Textures"

var _bytes := PackedByteArray()
var _json := {}
var _bin_offset := 0
var _materials := []
var _meshes := []
var _texture_cache := {}
var _current_model_name := ""


func load_node(path: String, normalize_origin: bool = false) -> Node3D:
	_current_model_name = path.get_file().get_basename()
	var imported_scene := _load_imported_scene(path, normalize_origin)
	if imported_scene != null:
		return imported_scene

	_bytes = FileAccess.get_file_as_bytes(path)
	if _bytes.size() < 20:
		return Node3D.new()
	if _bytes.slice(0, 4).get_string_from_ascii() != "glTF":
		return Node3D.new()

	var json_length := _bytes.decode_u32(12)
	var json_text := _bytes.slice(20, 20 + json_length).get_string_from_utf8()
	_json = JSON.parse_string(json_text)
	if typeof(_json) != TYPE_DICTIONARY:
		return Node3D.new()

	_bin_offset = _find_bin_offset(20 + json_length)
	_materials = _build_materials()
	_meshes.clear()

	var root := Node3D.new()
	root.name = _current_model_name
	var scenes: Array = _json.get("scenes", [])
	var scene_index := int(_json.get("scene", 0))
	if scenes.is_empty() or scene_index >= scenes.size():
		return root

	var scene: Dictionary = scenes[scene_index]
	for node_index in scene.get("nodes", []):
		root.add_child(_build_node(int(node_index)))
	if normalize_origin:
		_normalize_origin(root)
	return root


func _load_imported_scene(path: String, normalize_origin: bool) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path)
	if not resource is PackedScene:
		return null
	var instance := (resource as PackedScene).instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return null
	var root := instance as Node3D
	_remove_extra_lods(root)
	_apply_imported_materials(root)
	if normalize_origin:
		_normalize_origin(root)
	return root


func _remove_extra_lods(node: Node) -> void:
	for child in node.get_children():
		if child.name.contains("LOD1") or child.name.contains("LOD2") or child.name.contains("LOD3"):
			node.remove_child(child)
			child.free()
		else:
			_remove_extra_lods(child)


func _apply_imported_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material_name := mesh_instance.name
				var source_material := mesh_instance.mesh.surface_get_material(surface_index)
				if source_material != null and source_material.resource_name != "":
					material_name = source_material.resource_name
				var material := StandardMaterial3D.new()
				material.roughness = 0.92
				material.metallic = 0.0
				material.cull_mode = BaseMaterial3D.CULL_BACK
				_configure_material(material, material_name)
				if material.albedo_color.a < 1.0:
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_apply_imported_materials(child)


func _find_bin_offset(start: int) -> int:
	var cursor := start
	while cursor + 8 <= _bytes.size():
		var length := _bytes.decode_u32(cursor)
		var chunk_type := _bytes.slice(cursor + 4, cursor + 8).get_string_from_ascii()
		if chunk_type.begins_with("BIN"):
			return cursor + 8
		cursor += 8 + length
	return 0


func _build_node(node_index: int) -> Node3D:
	var nodes: Array = _json.get("nodes", [])
	if node_index < 0 or node_index >= nodes.size():
		return Node3D.new()

	var node_def: Dictionary = nodes[node_index]
	var node := Node3D.new()
	node.name = str(node_def.get("name", "GLBNode"))
	if _should_skip_lod_node(node.name):
		return node

	if node_def.has("translation"):
		var t: Array = node_def.translation
		node.position = Vector3(float(t[0]), float(t[1]), float(t[2]))
	if node_def.has("rotation"):
		var r: Array = node_def.rotation
		node.quaternion = Quaternion(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	if node_def.has("scale"):
		var s: Array = node_def.scale
		node.scale = Vector3(float(s[0]), float(s[1]), float(s[2]))

	if node_def.has("mesh"):
		var instance := MeshInstance3D.new()
		instance.name = "%sMesh" % node.name
		instance.mesh = _get_mesh(int(node_def.mesh))
		node.add_child(instance)

	for child_index in node_def.get("children", []):
		node.add_child(_build_node(int(child_index)))
	return node


func _should_skip_lod_node(node_name: String) -> bool:
	return node_name.contains("LOD1") or node_name.contains("LOD2") or node_name.contains("LOD3")


func _get_mesh(mesh_index: int) -> ArrayMesh:
	while _meshes.size() <= mesh_index:
		_meshes.append(null)
	if _meshes[mesh_index] != null:
		return _meshes[mesh_index]

	var mesh := ArrayMesh.new()
	var mesh_defs: Array = _json.get("meshes", [])
	if mesh_index < 0 or mesh_index >= mesh_defs.size():
		_meshes[mesh_index] = mesh
		return mesh

	var mesh_def: Dictionary = mesh_defs[mesh_index]
	for primitive in mesh_def.get("primitives", []):
		if int(primitive.get("mode", 4)) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var attributes: Dictionary = primitive.get("attributes", {})
		if not attributes.has("POSITION"):
			continue

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _read_vec3_accessor(int(attributes.POSITION))
		if attributes.has("NORMAL"):
			arrays[Mesh.ARRAY_NORMAL] = _read_vec3_accessor(int(attributes.NORMAL))
		if attributes.has("TEXCOORD_0"):
			arrays[Mesh.ARRAY_TEX_UV] = _read_vec2_accessor(int(attributes.TEXCOORD_0))
		if primitive.has("indices"):
			arrays[Mesh.ARRAY_INDEX] = _read_index_accessor(int(primitive.indices))

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface_index := mesh.get_surface_count() - 1
		var material_index := int(primitive.get("material", -1))
		if material_index >= 0 and material_index < _materials.size():
			mesh.surface_set_material(surface_index, _materials[material_index])

	_meshes[mesh_index] = mesh
	return mesh


func _read_vec3_accessor(accessor_index: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	var reader := _accessor_reader(accessor_index)
	for i in range(int(reader.count)):
		var offset := int(reader.offset) + i * int(reader.stride)
		result.append(Vector3(
			_bytes.decode_float(offset),
			_bytes.decode_float(offset + 4),
			_bytes.decode_float(offset + 8)
		))
	return result


func _read_vec2_accessor(accessor_index: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var reader := _accessor_reader(accessor_index)
	for i in range(int(reader.count)):
		var offset := int(reader.offset) + i * int(reader.stride)
		result.append(Vector2(
			_bytes.decode_float(offset),
			_bytes.decode_float(offset + 4)
		))
	return result


func _read_index_accessor(accessor_index: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var reader := _accessor_reader(accessor_index)
	for i in range(int(reader.count)):
		var offset := int(reader.offset) + i * int(reader.stride)
		match int(reader.component_type):
			COMPONENT_UNSIGNED_SHORT:
				result.append(_bytes.decode_u16(offset))
			COMPONENT_UNSIGNED_INT:
				result.append(_bytes.decode_u32(offset))
			_:
				result.append(_bytes[offset])
	return result


func _accessor_reader(accessor_index: int) -> Dictionary:
	var accessors: Array = _json.get("accessors", [])
	var views: Array = _json.get("bufferViews", [])
	var accessor: Dictionary = accessors[accessor_index]
	var view: Dictionary = views[int(accessor.bufferView)]
	var component_size := _component_size(int(accessor.componentType))
	var component_count := _component_count(str(accessor.type))
	var stride := int(view.get("byteStride", component_size * component_count))
	return {
		"offset": _bin_offset + int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0)),
		"stride": stride,
		"count": int(accessor.count),
		"component_type": int(accessor.componentType)
	}


func _component_size(component_type: int) -> int:
	match component_type:
		COMPONENT_FLOAT:
			return 4
		COMPONENT_UNSIGNED_INT:
			return 4
		COMPONENT_UNSIGNED_SHORT:
			return 2
		_:
			return 1


func _component_count(accessor_type: String) -> int:
	match accessor_type:
		"VEC2":
			return 2
		"VEC3":
			return 3
		"VEC4":
			return 4
		_:
			return 1


func _build_materials() -> Array:
	var result := []
	for material_def in _json.get("materials", []):
		var material := StandardMaterial3D.new()
		material.roughness = 0.92
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_configure_material(material, str(material_def.get("name", "")))
		if material.albedo_color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.append(material)
	return result


func _configure_material(material: StandardMaterial3D, material_name: String) -> void:
	material.albedo_color = _color_for_material(material_name)
	var lower := material_name.to_lower()
	var unity_material := _unity_material_for_current_model(material_name)
	var texture_stem := _texture_stem_for_unity_material(unity_material)
	if texture_stem != "":
		var alpha := material.albedo_color.a
		var albedo_texture := _load_texture_for_stem(texture_stem, "A")
		if albedo_texture != null:
			material.albedo_texture = albedo_texture
			material.albedo_color = Color(1.0, 1.0, 1.0, alpha)

		var normal_texture := _load_texture_for_stem(texture_stem, "N")
		if normal_texture != null:
			material.normal_enabled = true
			material.normal_texture = normal_texture
			material.normal_scale = 0.58

		var emission_texture := _load_texture_for_stem(texture_stem, "E")
		if emission_texture != null:
			material.emission_enabled = true
			material.emission_texture = emission_texture
			material.emission = Color.WHITE
			material.emission_energy_multiplier = 0.55

	if lower.contains("glass") or lower.contains("window"):
		material.metallic = 0.05
		material.roughness = 0.24
		material.emission_enabled = true
		material.emission = Color(0.24, 0.68, 1.0, 1.0)
		material.emission_energy_multiplier = 0.42
	elif lower.contains("sign") or lower.contains("vending"):
		material.roughness = 0.5
		material.emission_enabled = true
		material.emission = material.albedo_color.lightened(0.25)
		material.emission_energy_multiplier = 0.22
	elif lower.contains("traffic"):
		material.emission_enabled = true
		material.emission = Color(0.96, 0.36, 0.20, 1.0)
		material.emission_energy_multiplier = 0.16


func _unity_material_for_current_model(material_name: String) -> String:
	var clean_name := material_name.replace(".001", "")
	var house_remaps := _house_material_remaps()
	if house_remaps.has(_current_model_name):
		var model_remap: Dictionary = house_remaps[_current_model_name]
		if model_remap.has(clean_name):
			return str(model_remap[clean_name])
	return _default_unity_material(clean_name)


func _house_material_remaps() -> Dictionary:
	return {
		"AE_House_01": {
			"AE_Concrete": "AE_Concrete_01",
			"AE_Glass": "AE_Glass_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_01": "AE_Wall_Tile_01",
			"AE_Tilling material_02": "AE_Wallpaper_01",
			"AE_Tilling material_03": "AE_Wallpaper_02",
			"AE_Window": "AE_Windows"
		},
		"AE_House_02": {
			"AE_Concrete": "AE_Concrete_01",
			"AE_Glass": "AE_Glass_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_01": "AE_Wall_Tile_04",
			"AE_Tilling material_02": "AE_Wallpaper_01",
			"AE_Tilling material_03": "AE_Wall_Tile_02",
			"AE_Tilling material_04": "AE_Wallpaper_02",
			"AE_Window": "AE_Windows"
		},
		"AE_House_03": {
			"AE_Concrete": "AE_Concrete_01",
			"AE_Glass": "AE_Glass_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_02": "AE_Wallpaper_01",
			"AE_Tilling material_03": "AE_Wallpaper_02",
			"AE_Tilling material_05": "AE_Wall_Tile_03",
			"AE_Window": "AE_Windows"
		},
		"AE_House_04": {
			"AE_Concrete": "AE_Concrete_01",
			"AE_Glass": "AE_Glass_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_02": "AE_Wallpaper_01",
			"AE_Tilling material_04": "AE_Wall_Tile_04",
			"AE_Tilling material_05": "AE_Wall_Tile_04",
			"AE_Window": "AE_Windows"
		},
		"AE_House_05": {
			"AE_Glass": "AE_Glass_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_02": "AE_Wallpaper_01",
			"AE_Tilling material_06": "AE_Wall_Tile_05"
		},
		"AE_House_06": {
			"AE_Concrete": "AE_Concrete_01",
			"AE_Glass": "AE_Glass_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_01": "AE_Wall_Tile_01",
			"AE_Tilling material_02": "AE_Wallpaper_01",
			"AE_Window": "AE_Windows"
		},
		"AE_House_07": {
			"AE_Concrete": "AE_Concrete_02",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_01": "AE_Wall_Tile_01",
			"AE_Window": "AE_Windows"
		},
		"AE_House_08": {
			"AE_Concrete": "AE_Concrete_02",
			"AE_Glass": "AE_Glass_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_02": "AE_Wallpaper_01",
			"AE_Tilling material_03": "AE_Wall_Tile_02",
			"AE_Window": "AE_Windows"
		},
		"AE_House_09": {
			"AE_Concrete": "AE_Concrete_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_03": "AE_Wall_Tile_02",
			"AE_Window": "AE_Windows"
		},
		"AE_House_10": {
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_05": "AE_Wall_Tile_03",
			"AE_Window": "AE_Windows"
		},
		"AE_House_11": {
			"AE_Concrete": "AE_Concrete_01",
			"AE_Grass_02": "AE_Glass_02",
			"AE_Tilling material_04": "AE_Wall_Tile_04",
			"AE_Window": "AE_Windows"
		},
		"AE_House_12": {
			"AE_Glass": "AE_Glass_02",
			"AE_Tilling material_06": "AE_Wall_Tile_05",
			"AE_Window": "AE_Windows"
		}
	}


func _default_unity_material(material_name: String) -> String:
	var lower := material_name.to_lower()
	if lower.contains("concrete"):
		return "AE_Concrete_01"
	if lower.contains("glass"):
		return "AE_Glass_01"
	if lower.contains("window"):
		return "AE_Windows"
	if lower.contains("tilling material_01"):
		return "AE_Wall_Tile_01"
	if lower.contains("tilling material_02"):
		return "AE_Wallpaper_01"
	if lower.contains("tilling material_03"):
		return "AE_Wallpaper_02"
	if lower.contains("tilling material_04"):
		return "AE_Wall_Tile_04"
	if lower.contains("tilling material_05"):
		return "AE_Wall_Tile_03"
	if lower.contains("tilling material_06"):
		return "AE_Wall_Tile_05"
	return material_name


func _texture_stem_for_unity_material(unity_material: String) -> String:
	var lower := unity_material.to_lower()
	if lower == "ae_wallpaper_01":
		return "AE_House/AE_Wallpaper_01/AE_Wallpaper"
	if lower == "ae_wallpaper_02":
		return "AE_House/AE_Wallpaper_02/AE_Wallpaper_02"
	if lower == "ae_wall_tile_01":
		return "AE_House/AE_Wall_Tile_01/AE_Wall_Tile_01"
	if lower == "ae_wall_tile_02":
		return "AE_House/AE_Wall_Tile_02/AE_Wall_Tile_02"
	if lower == "ae_wall_tile_03":
		return "AE_House/AE_Wall_Tile_03/AE_Wall_Tile_03"
	if lower == "ae_wall_tile_04":
		return "AE_House/AE_Wall_Tile_04/AE_Wall_Tile_04"
	if lower == "ae_wall_tile_05":
		return "AE_House/AE_Wall_Tile_05/AE_Wall_Tile_05"
	if lower == "ae_wall_cast_concrete":
		return "AE_House/AE_Wall_Cast_Concrete/AE_Wall_Cast_Concrete"
	if lower.contains("concrete"):
		return "AE_House/AE_Concrete/AE_Concrete"
	if lower == "ae_glass_01" or lower == "ae_glass_02" or lower.contains("glass"):
		return "AE_House/AE_Glass/AE_Glass"
	if lower == "ae_windows" or lower.contains("window"):
		return "AE_House/AE_Windows/AE_Window"
	if lower == "ae_door_01" or lower.contains("door_01"):
		return "AE_House/AE_Door_01/AE_Door_01"
	if lower == "ae_door_02" or lower.contains("door_02"):
		return "AE_House/AE_Door_02/AE_Door_02"
	if lower.contains("roller"):
		return "AE_House/AE_Roller_Shutter/AE_Roller_Shutter"
	if lower.contains("floor_02"):
		return "AE_House/AE_Floor_02/AE_Floor_02"
	if lower.contains("floor"):
		return "AE_House/AE_Floor_01/AE_Floor"
	if lower.contains("decal"):
		return "AE_House/AE_Decals_01/AE_Decals_01"
	if lower.contains("road_elements_02"):
		return "AE_Street/AE_Road_Elements_02/AE_Road_Elements_02"
	if lower.contains("road_elements"):
		return "AE_Street/AE_Road_Elements_01/AE_Road_Elements_01"
	if lower.contains("road_sign"):
		return "AE_Road_Sign"
	if lower.contains("road"):
		return "AE_Street/AE_Road/AE_Road"
	if lower.contains("sidewalk"):
		return "AE_Street/AE_Sidewalk/AE_Sidewalk"
	if lower.contains("electric") or lower.contains("traffic"):
		return "AE_Street/AE_Electric_Post/AE_Electric_Post"
	if lower.contains("signboards"):
		return "AE_Street/AE_Signboards_01/AE_Signboards_01"
	if lower.contains("tream") or lower.contains("sheet"):
		return "AE_Street/AE_Tream_Sheets_01/AE_Tream_Sheets_01"
	if lower.contains("wire"):
		return "AE_Street/AE_Wires_01/AE_Wires_01"
	if lower.contains("ground"):
		return "AE_Street/AE_Ground/AE_Ground"
	if lower.contains("detail"):
		return "AE_Street/AE_Detail/AE_Detail"
	if lower.contains("vending_machine_02"):
		return "AE_Props/AE_Vending_Machine_02/AE_Vending_Machine_02"
	if lower.contains("vending"):
		return "AE_Props/AE_Vending_Machine_01/AE_Vending_Machine_01"
	if lower.contains("bicycle"):
		return "AE_Auto/AE_Bicycle/AE_Bicycle"
	if lower.contains("scooter"):
		return "AE_Auto/AE_Scooter_01/AE_Scooter"
	if lower.contains("flower_pot"):
		return "AE_Props/AE_Flower_Pot/AE_Flower_Pot"
	if lower.contains("flower_trunk"):
		return "AE_Props/AE_Flower/AE_Flower"
	if lower.contains("flower"):
		return "AE_Props/AE_Flower/AE_Flower"
	if lower.contains("wall_props"):
		return "AE_Props/AE_Wall_Props/AE_Wall_Props"
	return ""


func _load_texture_for_stem(texture_stem: String, suffix: String) -> Texture2D:
	var generated_path := "%s/%s_%s.png" % [GENERATED_TEXTURE_ROOT, texture_stem, suffix]
	var generated_texture := _load_texture(generated_path)
	if generated_texture != null:
		return generated_texture
	return _load_texture("%s/%s_%s.tga" % [SOURCE_TEXTURE_ROOT, texture_stem, suffix])


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			_texture_cache[path] = loaded
			return loaded
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture


func _color_for_material(material_name: String) -> Color:
	var lower := material_name.to_lower()
	if lower.contains("glass") or lower.contains("window"):
		return Color(0.48, 0.83, 1.0, 0.78)
	if lower.contains("door"):
		return Color(0.42, 0.23, 0.15, 1.0)
	if lower.contains("road"):
		return Color(0.13, 0.14, 0.15, 1.0)
	if lower.contains("sidewalk") or lower.contains("concrete"):
		return Color(0.58, 0.57, 0.54, 1.0)
	if lower.contains("roller"):
		return Color(0.52, 0.50, 0.47, 1.0)
	if lower.contains("sign") or lower.contains("vending"):
		if lower.contains("vending"):
			return Color(0.90, 0.22, 0.24, 1.0)
		return Color(0.95, 0.50, 0.24, 1.0)
	if lower.contains("electric") or lower.contains("traffic"):
		return Color(0.15, 0.15, 0.16, 1.0)
	if lower.contains("flower") or lower.contains("grass"):
		if lower.contains("flower") and not lower.contains("pot"):
			return Color(0.92, 0.38, 0.52, 1.0)
		return Color(0.26, 0.48, 0.28, 1.0)
	if lower.contains("bicycle") or lower.contains("scooter"):
		return Color(0.18, 0.22, 0.28, 1.0)
	if lower.contains("ceiling") or lower.contains("floor"):
		return Color(0.48, 0.43, 0.38, 1.0)
	if lower.contains("wall") or lower.contains("house"):
		return Color(0.72, 0.64, 0.56, 1.0)
	if lower.contains("tilling material_01"):
		return Color(0.42, 0.47, 0.52, 1.0)
	if lower.contains("tilling material_02"):
		return Color(0.67, 0.57, 0.47, 1.0)
	if lower.contains("tilling material_03"):
		return Color(0.36, 0.42, 0.48, 1.0)
	if lower.contains("tilling material_04"):
		return Color(0.55, 0.51, 0.46, 1.0)
	if lower.contains("tilling material_05"):
		return Color(0.31, 0.34, 0.38, 1.0)
	if lower.contains("tilling material_06"):
		return Color(0.56, 0.48, 0.40, 1.0)
	if lower.contains("tream") or lower.contains("sheet"):
		return Color(0.26, 0.27, 0.30, 1.0)
	if lower.contains("decal"):
		return Color(0.86, 0.82, 0.70, 1.0)
	return Color(0.60, 0.55, 0.50, 1.0)


func _normalize_origin(root: Node3D) -> void:
	var bounds := _local_bounds(root)
	if bounds.size == Vector3.ZERO:
		return
	var offset := Vector3(
		-(bounds.position.x + bounds.size.x * 0.5),
		-bounds.position.y,
		-(bounds.position.z + bounds.size.z * 0.5)
	)
	for child in root.get_children():
		if child is Node3D:
			child.position += offset


func _local_bounds(root: Node3D) -> AABB:
	return _local_bounds_recursive(root, Transform3D.IDENTITY).get("bounds", AABB())


func _local_bounds_recursive(node: Node, parent_transform: Transform3D) -> Dictionary:
	var has_bounds := false
	var bounds := AABB()
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds := mesh_instance.mesh.get_aabb()
			var points := [
				mesh_bounds.position,
				mesh_bounds.position + Vector3(mesh_bounds.size.x, 0.0, 0.0),
				mesh_bounds.position + Vector3(0.0, mesh_bounds.size.y, 0.0),
				mesh_bounds.position + Vector3(0.0, 0.0, mesh_bounds.size.z),
				mesh_bounds.position + Vector3(mesh_bounds.size.x, mesh_bounds.size.y, 0.0),
				mesh_bounds.position + Vector3(mesh_bounds.size.x, 0.0, mesh_bounds.size.z),
				mesh_bounds.position + Vector3(0.0, mesh_bounds.size.y, mesh_bounds.size.z),
				mesh_bounds.position + mesh_bounds.size
			]
			for point in points:
				var local_point: Vector3 = current_transform * point
				if has_bounds:
					bounds = bounds.expand(local_point)
				else:
					bounds = AABB(local_point, Vector3.ZERO)
					has_bounds = true

	for child in node.get_children():
		var child_result := _local_bounds_recursive(child, current_transform)
		if not bool(child_result.get("has_bounds", false)):
			continue
		if has_bounds:
			bounds = bounds.merge(child_result.bounds)
		else:
			bounds = child_result.bounds
			has_bounds = true
	return {
		"has_bounds": has_bounds,
		"bounds": bounds
	}
