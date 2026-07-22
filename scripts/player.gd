extends CharacterBody3D





# Exported variables allow you to adjust them easily in the Inspector panel
@onready var speed = 10.0
@onready var jump_speed = 8.5
@onready var acceleration = 60.0
@onready var friction = 80.0
@onready var jump_multiplier : float = 1.0
@onready var jump_buffer_timer: Timer = $jump_buffer_timer

@onready var camera_pivot: Node3D = $camera_pivot
@onready var camera_spring_arm: SpringArm3D = $camera_pivot/camera_arm

## temp
@onready var initCamera: Node3D = $"../cameraRig"
@onready var targettest: MeshInstance3D = $targettest
## temp

@onready var camera : Camera3D = $camera_pivot/camera_arm/Camera

@onready var model: MeshInstance3D = $model
@onready var crosshair: Label = $"../UI/crosshair"
@onready var crosshair_ammo: Path2D = $"../UI/crosshair_ammo"
@onready var bullet_spawn: Marker3D = $bullet_spawn
@onready var flashlight: SpotLight3D = $flashlight

@onready var model_gun: MeshInstance3D = $model/model_gun
@onready var statelabel: Label3D = $statetext



var gravity = Vector3(0, -20, 0) # Adjust gravity as needed
var mouse_delta = Vector2.ZERO# save mouse movement change from frame to frame
@export_range(50, 500) var mouse_sensitivity := 250
var current_mouse_sensitivity = 100 
@onready var rotation_speed = 12.0

@onready var shooting_pov_vars := [Vector3(1.5, 0.75, 0.0),Vector3(deg_to_rad(-5.5), deg_to_rad(7.5), 0.0),Vector3(0.5,0.5,0.5)]
@onready var regular_pov_vars := [Vector3(0,1,0), Vector3.ZERO, Vector3.ONE]
@onready var camera_rig: Node3D = $"../cameraRig"

var last_dir

func _ready() -> void:
	current_mouse_sensitivity = mouse_sensitivity
	#toggle_gun_ui(false)
	camera = get_viewport().get_camera_3d()


func _apply_gravity(delta):
	velocity += gravity * delta #gravity


func _handle_move_input():
	#input direction vector
	#var forward = -camera.transform.basis.x.normalized()
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized() 
	targettest.position = global_transform.basis.inverse() * velocity /1.75
	

@onready var groundborne_ray: RayCast3D = $groundborne_ray
func _is_groundborne():
	if groundborne_ray.is_colliding():
		return true
	else: return false 

func _apply_movement(delta):
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized() 
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	else:
		#apply friction when no input
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	
	last_dir = direction
	
	
	##gun logic - defunct
	if gun_mode:
		_rotate_model_forward()
		pass
	
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



func _jump():
	if !is_on_floor():
		_jump_buffer()
		return
	velocity.y = jump_speed * jump_multiplier

func _jump_buffer(): #buffer that starts for 2 seconds, if in these 2 seconds player lands on ground, immidately jump
	if jump_buffer_timer.time_left > 0:
		return true
	else:
		print("started jump buffer")
		jump_buffer_timer.start(1)
		return false

func _hit_floor(): #should be called by the fsm when existing the falling/other air states
	print("hi")
	if _jump_buffer():
		_jump()

func _wall_jump():
	velocity.y = jump_speed * jump_multiplier * 1.5
	#velocity.x -= 15
	for i in mid_rays.get_children():
		if i.is_colliding():
			var collider = i.get_collision_normal()
			velocity.x += collider.x * 15
			velocity.z += collider.z * 15
			break

func _dash():
	# TODO make a normal dash ffs
	speed *= 2
	velocity.x = move_toward(velocity.x, last_dir.x * speed, acceleration )
	velocity.z = move_toward(velocity.z, last_dir.z * speed, acceleration )
	await get_tree().create_timer(0.2).timeout
	speed /= 2

func _start_dash_jump_window(): #TODO doesnt work rn
	print("can dashjump")
	jump_multiplier = 1.5
	await get_tree().create_timer(0.8).timeout
	jump_multiplier = 1
	print("dashjump window over")

@onready var mid_rays: Node3D = $mid_rays
@onready var top_rays: Node3D = $top_rays
@onready var overhead_rays: Node3D = $overhead_rays

var can_climb = false
func _is_on_wall():
	for i in mid_rays.get_children():
		if i.is_colliding():
			return true

func _can_climb():
	if !mid_rays.get_children()[2].is_colliding:
		return false
	for ray in top_rays.get_children():
		if ray.is_colliding():
			return false
		return true


func _is_hanging():
	for i in top_rays.get_children():
		if i.is_colliding():
			return true



#func _input(event: InputEvent) -> void:
	##gun logic
	#if gun_mode:
		#if event is InputEventMouseButton:
			#if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				#gun_effect = "fire"
				#model_gun.get_active_material(0).albedo_color = Color.DARK_RED
			#if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				#gun_effect = "water"
				#model_gun.get_active_material(0).albedo_color = Color.DARK_BLUE
		#
		#if Input.is_action_just_pressed("fire"):
			#if cur_ammo <= 0:
				#print("no ammo left")
				#return
			#print("fired bullet")
			#fire_bullet(gun_effect)
			#cur_ammo -= 1
			#if cur_ammo < 100:
				#crosshair_ammo.text = str(0)
				#if cur_ammo < 10:
					#crosshair_ammo.text += str(0)
				#crosshair_ammo.text += str(cur_ammo, " / ", max_ammo)
			#else:
				#crosshair_ammo.text = str(cur_ammo, " / ", max_ammo)
		#if Input.is_action_just_pressed("reload"):
			#cur_ammo = max_ammo
			#crosshair_ammo.text = str(cur_ammo, " / ", max_ammo)
	###temp - defunct
	##if Input.is_action_just_pressed("cameraSwitch"):
	##	camera_handling()
	###temp


##defunct rn, logic to swtich camera smoothly
#func camera_handling():
	#CameraLogic.camera_switch(initCamera)
	#camera = get_viewport().get_camera_3d()

##defunct rn, dont think i will continue with the bullet aspect, will prob reqrite if do
var gun_mode = false
#var max_ammo = 128
#var cur_ammo = 100
#var gun_effect = ""
#
#
#func fire_bullet(type):
	#var bullet = DEFAULT_BULLET.instantiate()
	#get_tree().get_root().get_node("playground").get_node("bullets").add_child(bullet)
	#bullet.global_position = bullet_spawn.global_position
	#bullet.bullet_effect = type
	#
	#bullet.bullet_effect = gun_effect
	#
	#
	#var cameraForward = -camera.global_transform.basis.z * Vector3(1,1,1).normalized() #cameras facing direction to dictate "forward"
	#bullet.DIRECTION = cameraForward 
	#bullet.SPEED = 1
#

func _fire_spear(selected_spear):
	print("kapaw fired spear")
	var cameraForward = -camera.global_transform.basis.z * Vector3(1,1,1).normalized() #cameras facing direction to dictate "forward"
	selected_spear._fire(cameraForward, 40)

func toggle_gun_ui(mode):
	if mode:
		current_mouse_sensitivity = mouse_sensitivity * 2
		#print(current_mouse_sensitivity)
		
		camera_rig._set_target_info(self, Vector3(2, 1, 0))
		#var tween : Tween = create_tween().set_parallel(true)
		#tween.tween_property(camera_rig, "position", shooting_pov_vars[0], 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#tween.tween_property(camera_rig, "rotation", shooting_pov_vars[1], 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#tween.tween_property(camera_rig, "scale"   , shooting_pov_vars[2], 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		
		crosshair.show()
		#crosshair_ammo.show()
	else:
		current_mouse_sensitivity = mouse_sensitivity
		
		camera_rig._set_target_info(self, Vector3(0, 1.5, 0))
		
		#var tween : Tween = create_tween().set_parallel(true)
		#tween.tween_property(camera_rig, "position", regular_pov_vars[0], 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#tween.tween_property(camera_rig, "rotation", regular_pov_vars[1], 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#tween.tween_property(camera_rig, "scale"   , regular_pov_vars[2], 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		crosshair.hide()
		#crosshair_ammo.hide()

var spears = []

func _on_pickup_range_body_entered(body: Node3D) -> void:
	
	
	if body.is_in_group("spears"):
		#set the spear a target to follow, save the spear to available spears
		spears.append(body)
		body._set_target($spear_home)
