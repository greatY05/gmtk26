extends CharacterBody3D


const GEAR_PIC = preload("uid://bh5o6ghxnnaf1")


## gen stuf
@onready var speed = 10.0
@onready var jump_speed = 8.5
@onready var acceleration = 80.0
@onready var friction = 80.0

@onready var groundborne_ray: RayCast3D = $groundborne_ray
@onready var dash_post_timer: Timer = $dash_post_timer
@onready var dash_buffer_timer: Timer = $dash_buffer_timer
@onready var airjump_particle: GPUParticles3D = $airjump_particle

@onready var russ: Node3D = $russ
@onready var animation_player: AnimationPlayer = $russ/AnimationPlayer

@export var model : Node3D

@export var win_amount := 16

var checkpoint :Vector3 = Vector3(75, 5, -36)

var mouse_delta = Vector2.ZERO# save mouse movement change from frame to frame
@export_range(50, 500) var mouse_sensitivity := 200
var current_mouse_sensitivity = 150
@onready var rotation_speed = 12.0

@export var camera : Camera3D

var gravity = Vector3(0, -20, 0) # Adjust gravity as needed
var last_dir #last direction held by controls
var is_frozen = false

var dir_locked = false #wether the character can turn or not
#----------------------------------------------------------------
##jump stuff
@export var cogs_allowed = 0
var cogs_left #assigned jumps allowed on proccess/startup
@onready var jump_buffer_timer: Timer = $jump_buffer_timer
@onready var jump_multiplier : float = 1.0
var can_air_jump = true
var is_airjumping = false
var airjump_timer_left
@export var airjump_duration = 0.45

##new jump logic using sjvnnings exmaple
@export var jump_height : float = 4.0
@export var jump_time_to_peak : float = 0.4
@export var fall_gravity_multiplier : float = 1.5 

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = jump_gravity * fall_gravity_multiplier
##air jump 
@export var air_jump_height : float = 4.0
@export var air_jump_time_to_peak : float = 0.4
@export var air_fall_gravity_multiplier : float = 1.3

@onready var air_jump_velocity : float = ((2.0 * air_jump_height) / air_jump_time_to_peak) * -1.0
@onready var air_jump_gravity : float = ((-2.0 * jump_height) / (air_jump_time_to_peak * air_jump_time_to_peak)) * -1.0
@onready var air_fall_gravity : float = air_jump_gravity * air_fall_gravity_multiplier
#--------------------------------------------
##dash stuff
var is_dashing = false
var dash_timer_left = 0.0
@export var dash_duration = 0.45
@export var dash_speed_multiplier = 3.2
@export var dash_friction = 40.0

var dashjump_gravity_scale = 0.0
var is_dashjumping = false
var dashjump_time_left = 0.0
var dashjump_duration =.2
#----------------------------------------------



func _get_gravity():
	if dash_timer_left >= 0.5 and is_dashing and !is_airjumping or is_frozen: return 0
	if is_airjumping:
		return air_jump_gravity if velocity.y > 0.0 else air_fall_gravity
	return jump_gravity if velocity.y > 0.0 else fall_gravity


func _apply_gravity(delta):
	var g = _get_gravity()
	if is_dashjumping:
		g *= dashjump_gravity_scale
	velocity.y -= g * delta #gravity


func _handle_move_input():
	#input direction vector
	#var forward = -camera.transform.basis.x.normalized()
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized()


func _apply_movement(delta):
	if is_frozen:
		return
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized()
	
	if is_dashjumping:
		is_dashing = false
		dashjump_time_left -= delta
		var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, dash_friction * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		if dashjump_time_left <= 0:
			is_dashjumping = false
		move_and_slide()
		return
	
	if is_dashing:
		dash_timer_left -= delta
		var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, dash_friction * delta)
		if dash_timer_left <=1 and !is_airjumping and !is_dashjumping:
			velocity.y = 0
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		if dash_timer_left <= 0:
			is_dashing = false
			dir_locked = false
		move_and_slide()
		return #end of dash - no need the rest of the movement
	dir_locked = false
	
	var airjump_tweak = 1.0
	if is_airjumping:
		is_dashing = false
		airjump_duration -= delta
		
		airjump_tweak = 1.3
		
		if airjump_timer_left <= 0 or velocity.y < 0:
			is_airjumping = false
			airjump_tweak = 1.0
		
	
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
	if direction:
		horizontal_velocity = horizontal_velocity.move_toward(direction * speed * airjump_tweak, acceleration * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, friction/airjump_tweak * delta)
	
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	if direction != Vector3.ZERO: #direction hnadling for dash when not moving
		last_dir = direction
	else:
		last_dir = -cameraForward
	
	if not dir_locked: #instat rotation after leaving dirlock
		_rotate_model_forward(delta)
	
	if is_on_floor() and cogs_allowed != cogs_left: #logic for reseting air jump counter
		cogs_left = cogs_allowed
		_count_coguse(99)
	
	if is_on_floor() or velocity.y > 0: #end airjump state catchnet
		is_airjumping = false
	
	if is_on_floor() and (velocity.length() > 5) and !is_frozen:
		$dust_particles.set_emitting(true)
	else:
		$dust_particles.set_emitting(false)
	
	move_and_slide()


func _rotate_model():
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized() #cameras facing direction to dictate "forward"
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized()
	if direction.length() > 0.0:
		model.rotation.y = lerp_angle(rotation.y, atan2(-last_dir.x, -last_dir.z), rotation_speed * Engine.get_main_loop().root.get_process_delta_time()) #delta
		print(model.rotation.y)


func _rotate_model_forward(delta):
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cameraForward = camera.global_transform.basis.z * Vector3(1,0,1).normalized()
	var direction = (cameraForward * input_dir.y + camera.global_transform.basis.x * input_dir.x).normalized()
	if direction.length() > 0.0:
		#model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), rotation_speed * delta)
		model.rotation.y =  atan2(-direction.x, -direction.z)
	

var postdash_action = false
func _dash():
	if !dash_buffer_timer.is_stopped():
		return
	
	if !is_on_floor():
		if cogs_left <= 0:
			return
	
	dash_buffer_timer.start(0.6)
	
	is_dashing = true
	dir_locked = true
	dash_timer_left = dash_duration
	var dash_vel = speed * dash_speed_multiplier
	velocity.x = last_dir.x * dash_vel
	velocity.z = last_dir.z * dash_vel
	postdash_action = true
	#dash_post_timer.start(0.2)
	
	_count_coguse(-1)
	
	##shader stuff
	var world_velocity = velocity
	var local_velocity = model.global_transform.basis.inverse() * world_velocity
	
	dash_post_timer.start(0.5) #for post dash actions
	#model.get_active_material(0).set_shader_parameter("edge_fade", 0.0)
	#model.get_active_material(0).set_shader_parameter("dash_intensity", 5.0)
	#model.get_active_material(0).set_shader_parameter("dash_velocity", local_velocity)
	
	#var tween = create_tween().set_parallel(true)
	#tween.tween_property(model.get_active_material(0), "shader_parameter/edge_fade", 1, 0.5).set_ease(tween.EASE_OUT)
	#tween.tween_property(model.get_active_material(0), "shader_parameter/dash_intensity", 0, 0.5)
	postdash_action = true #for dashjumps
	#------------------------------
	##var dash_vel = speed * dash_speed_multiplier
	#velocity.x = move_toward(velocity.x, last_dir.x * dash_vel, 100 )
	#velocity.z = move_toward(velocity.z, last_dir.z * dash_vel, 100 )
	#await get_tree().create_timer(0.45).timeout
	#dir_locked = false

##ground stuff
func _get_ground_y():
	if groundborne_ray.is_colliding():
		return groundborne_ray.get_collision_point().y

func _is_groundborne():
	if groundborne_ray.is_colliding():
		return true
	else: return false

func _jump():
	
	if postdash_action and cogs_left > 0: #logic for jumping after dash - leading to dash jump - might need to move to as a state for animation purposes
		_count_coguse(-1)
		is_dashjumping = true
		dashjump_time_left = dashjump_duration
		velocity.y = -jump_velocity
		print("dashjump")
		return
	#regular jump logic
	velocity.y = -jump_velocity
	#velocity.y = jump_speed * jump_multiplier

func _air_jump():
	if !jump_buffer_timer.is_stopped(): ##cooldown between each jump
		return
	jump_buffer_timer.start(0.3)
	
	if postdash_action and cogs_left > 0: #logic for jumping after dash - leading to dash jump - might need to move to as a state for animation purposes
		_count_coguse(-1)
		is_dashjumping = true
		dashjump_time_left = dashjump_duration
		velocity.y = -jump_velocity
		print("dashjump")
		return
	if cogs_left > 0 and cogs_left > 0:
		$sounds/airjump.stop()
		airjump_timer_left = airjump_duration
		is_airjumping = true
		velocity.y = 0
		velocity.y += -air_jump_velocity
		airjump_particle.restart()
		$sounds/airjump.play()
		_count_coguse(-1)

func _jump_release():
	if velocity.y > 0 and cogs_left == cogs_allowed:
		velocity.y *= 0.5


func _count_coguse(change):
	if change != 99:
		cogs_left += change
	
	for i in $"../CanvasLayer/CenterContainer".get_children():
		if change == 99:
			i.show()
		elif change > 0:
			if !i.visible:
				i.show()
				return
		else:
			if i.visible:
				_play_cog_use_animation(i)
				return

func _play_cog_use_animation(cog_icon: Control):
	var tween = create_tween().set_parallel(true)
	tween.tween_property(cog_icon, "scale", cog_icon.scale * 1.6, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(cog_icon, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_OUT)
	await tween.finished
	cog_icon.hide()
	cog_icon.scale = Vector2(1, 1)
	cog_icon.modulate.a = 1.0

func _die():
	var tween = create_tween()
	tween.tween_property($russ/AnimationPlayer, "speed_scale", 0, .5).set_ease(Tween.EASE_OUT)
	await tween.finished
	$russ/AnimationPlayer.pause()
	is_frozen = true

func _respawn():
	is_frozen = false
	position = checkpoint
	$russ/AnimationPlayer.set_speed_scale(1.0)

#func _jump_buffer(): #buffer that starts for 2 seconds, if in these 2 seconds player lands on ground, immidately jump  ##DOESNT WORK
 	#if jump_buffer_timer.time_left > 0:
		#return true
	#else:
		#print("started jump buffer")
		#jump_buffer_timer.start(1)
		#return false

func _on_dash_post_timer_timeout() -> void:
	postdash_action = false
	print("postdash over")

func _collected_cog():
	checkpoint = position
	var new_cog = TextureRect.new()
	new_cog.set_texture(GEAR_PIC)
	
	new_cog.pivot_offset = Vector2(32, 32)
	new_cog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_cog.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	new_cog.custom_minimum_size = Vector2(64, 64)
	
	if cogs_allowed > 16:
		return
	$"../CanvasLayer/CenterContainer".add_child(new_cog)
	cogs_allowed+=1
	cogs_left+=1
	if cogs_allowed == win_amount: #win con
		get_tree().get_first_node_in_group("active_scene")._win()
		#await get_tree().create_timer(1).timeout
		#$"../ending/Camera3D".set_current(true)
		#$"../ending".show()
	


#collectiable handling
func _on_pickup_area_area_entered(area: Area3D) -> void:
	if area.is_in_group("collectiable"):
		print("item got")
		_collected_cog()
		area._collect()




## SOUND --------------

@onready var footstep_player: AudioStreamPlayer = $sounds/step
@export var footstep_sounds: Array[AudioStream] = []
@export var footstep_interval: float = 0.39
var footstep_timer: float = 0.0

func _play_footstep():
	if footstep_sounds.is_empty() or is_frozen:
		return
	footstep_player.stream = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_player.pitch_scale = randf_range(0.9, 1.1)
	footstep_player.play()

func _update_footstep_timer(delta, is_moving_on_ground):
	if is_moving_on_ground:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			_play_footstep()
			footstep_timer = footstep_interval
	else:
		footstep_timer = 0.0 
