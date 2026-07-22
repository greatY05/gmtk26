extends CharacterBody3D

@onready var speed = 10.0
@onready var jump_speed = 8.5
@onready var acceleration = 60.0
@onready var friction = 80.0

@onready var groundborne_ray: RayCast3D = $groundborne_ray
@onready var dash_post_timer: Timer = $dash_post_timer


var mouse_delta = Vector2.ZERO# save mouse movement change from frame to frame
@export_range(50, 500) var mouse_sensitivity := 200
var current_mouse_sensitivity = 100 
@onready var rotation_speed = 12.0

@export var camera : Camera3D

var gravity = Vector3(0, -20, 0) # Adjust gravity as needed
var last_dir #last direction held by controls

var dir_locked = false #wether the character can turn or not

##gameplay vars
@export var jumps_allowed = 3
var jumps_left  #assigned jumps allowed on proccess/startup

func _apply_gravity(delta):
	velocity += gravity * delta #gravity


func _handle_move_input():
	#input direction vector
	#var forward = -camera.transform.basis.x.normalized()
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized() 


func _apply_movement(delta):
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized() 
	
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
	if direction:
		horizontal_velocity = horizontal_velocity.move_toward(direction * speed, acceleration * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, friction * delta)
	
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	last_dir = direction
	
	if not dir_locked:
		_rotate_model_forward()
	
	if is_on_floor(): #logic for reseting air jump counter
		jumps_left = jumps_allowed
		_count_airjump(99)
	
	move_and_slide()


func _rotate_model():
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized() 
	if direction.length() > 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(-last_dir.x, -last_dir.z), rotation_speed * Engine.get_main_loop().root.get_process_delta_time()) #delta


func _rotate_model_forward():
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized() 
	rotation.y = lerp_angle(rotation.y, direction.y, rotation_speed * Engine.get_main_loop().root.get_process_delta_time()) #delta

var postdash_action = false
func _dash():
	#what we need to do: 1. lock rotation for the first instance off the dash, use last direction looked at for the direction, move forward,
	dir_locked = true
	var world_velocity = velocity
	var local_velocity = $model.global_transform.basis.inverse() * world_velocity
	
	dash_post_timer.start(0.2) #for post dash actions
	$model.get_active_material(0).set_shader_parameter("edge_fade", 0.0)
	$model.get_active_material(0).set_shader_parameter("dash_intensity", 5.0)
	$model.get_active_material(0).set_shader_parameter("dash_velocity", local_velocity)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property($model.get_active_material(0), "shader_parameter/edge_fade", 1, 0.5).set_ease(tween.EASE_OUT)
	tween.tween_property($model.get_active_material(0), "shader_parameter/dash_intensity", 0, 0.5)
	postdash_action = true #for dashjumps
	
	var dash_vel = speed * 3.2
	velocity.x = move_toward(velocity.x, last_dir.x * dash_vel, 100 )
	velocity.z = move_toward(velocity.z, last_dir.z * dash_vel, 100 )
	await get_tree().create_timer(0.45).timeout
	dir_locked = false

##ground stuff
func _get_ground_y():
	if groundborne_ray.is_colliding():
		return groundborne_ray.get_collision_point().y

func _is_groundborne():
	if groundborne_ray.is_colliding():
		return true
	else: return false 

##jump stuff
@onready var jump_buffer_timer: Timer = $jump_buffer_timer
@onready var jump_multiplier : float = 1.0
var can_air_jump = true
func _jump():
	if !is_on_floor():
		if jumps_left > 0 and can_air_jump:
			velocity.y = 0
			velocity.y += jump_speed *jump_multiplier *1.3
			_count_airjump(-1)
		_jump_buffer()
		return
	if postdash_action:
		var dash_vel = speed * 3.2
		velocity.x = move_toward(velocity.x, last_dir.x * dash_vel, 100 )
		velocity.z = move_toward(velocity.z, last_dir.z * dash_vel, 100 )
		velocity.y = jump_speed * jump_multiplier * 1.2
		return
	velocity.y = jump_speed * jump_multiplier

func _count_airjump(change):
	jumps_left += change
	for i in $"../CanvasLayer/CenterContainer".get_children():
		if change > 0:
			if !i.visible:
				i.show()
				return
		else:
			if i.visible:
				i.hide()
				return
		
		if change == 99: # edge number - reset everything
			if !i.visible:
				i.show()

func _jump_buffer(): #buffer that starts for 2 seconds, if in these 2 seconds player lands on ground, immidately jump
	if jump_buffer_timer.time_left > 0:
		return true
	else:
		print("started jump buffer")
		jump_buffer_timer.start(1)
		return false


func _on_dash_post_timer_timeout() -> void:
	postdash_action = false
