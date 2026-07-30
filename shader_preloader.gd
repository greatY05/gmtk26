extends Node3D

@export var warmup_particles: Array[PackedScene] = []  
@export var warmup_materials: Array[Material] = []     
@export var warmup_frames: int = 15             

func _ready() -> void:
	$"../CanvasLayer/loadscreen".show()
	_warmup()

func _warmup() -> void:
	global_position = Vector3(0, -500, 0)

	for scene in warmup_particles:
		var instance = scene.instantiate()
		add_child(instance)
		if instance.has_method("restart"):
			instance.restart()
		if "emitting" in instance:
			instance.emitting = true

	for mat in warmup_materials:
		var quad = MeshInstance3D.new()
		var mesh = QuadMesh.new()
		mesh.size = Vector2(1, 1)
		quad.mesh = mesh
		quad.material_override = mat
		add_child(quad)

	for i in warmup_frames:
		await get_tree().process_frame

	for child in get_children():
		child.queue_free()
	$"../CanvasLayer/loadscreen".hide()
	queue_free()
