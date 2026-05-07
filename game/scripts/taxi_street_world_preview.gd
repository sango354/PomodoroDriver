@tool
extends Node3D

const TaxiStreetWorldController = preload("res://scripts/taxi_street_world_controller.gd")

const PREVIEW_WORLD_NAME := "TaxiStreetWorld"


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_build_editor_preview")


func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_runtime_preview()


func _build_editor_preview() -> void:
	_clear_preview()
	var world := TaxiStreetWorldController.new()
	world.name = PREVIEW_WORLD_NAME
	add_child(world)
	world.set_process(false)
	world._ready()
	_add_aerial_camera(world)


func _build_runtime_preview() -> void:
	_clear_preview()
	var world := TaxiStreetWorldController.new()
	world.name = PREVIEW_WORLD_NAME
	add_child(world)
	_add_aerial_camera(world)


func _clear_preview() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _add_aerial_camera(world: Node3D) -> void:
	for child in world.get_children():
		if child is Camera3D:
			(child as Camera3D).current = false

	var camera := Camera3D.new()
	camera.name = "AerialPreviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 330.0
	camera.near = 0.1
	camera.far = 520.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(-180.0, 190.0, 120.0), Vector3(0.0, 0.0, -56.0), Vector3.UP)
	camera.make_current()
