extends StateMachine


func _ready():
	add_state("idle")       #1
	add_state("walk")       #2
	add_state("run")        #3
	add_state("dash")       #4
	add_state("fall")       #5
	#add_state("shooting")   #6
	add_state("jump")       #7
	#add_state("wall")       #8
	#add_state("climb")      #9
	add_state("hanging")    #10
	call_deferred("set_state", states.idle) #sets state during idle time avoiding runtime issues, letting parent init states properly


func _input(event: InputEvent) -> void:
	if [states.fall, states.idle, states.run, states.walk, states.jump].has(state): #check if our current state is within the given list
		#jump
		if Input.is_action_just_pressed("jump"):
			parent._jump()
	
	#if [states.climb, states.wall].has(state): #wall jumping
		#if Input.is_action_just_pressed("jump"):
			#parent._wall_jump()
	
	#if Input.is_action_just_pressed("light"):
		#parent.flashlight.visible = !parent.flashlight.visible
	
	#if Input.is_action_just_pressed("toggle_ranged"):
		#parent.gun_mode = !parent.gun_mode
		#print("toggle gun ui ", parent.gun_mode)
		#parent.toggle_gun_ui(parent.gun_mode)
	
	if Input.is_action_just_pressed("dash"):
		parent._dash()
		
	
	#if Input.is_action_just_pressed("fire"):
		#if parent.spears.size() > 0:
			#parent._fire_spear(parent.spears[0])
	
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: #capture mouse on click
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.is_action_just_pressed("esc") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: #free mouse when esc
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	
	##trying to move it to follwoing camera script
	#if  event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: #mouse change
		#parent.camera_spring_arm.rotation.x -= event.screen_relative.y / parent.current_mouse_sensitivity
		#parent.rotation.y -= event.screen_relative.x / parent.current_mouse_sensitivity 
		#parent.camera_spring_arm.rotation.x = clamp(parent.camera_spring_arm.rotation.x, deg_to_rad(-50), deg_to_rad(30))
	##temp
	#if Input.is_action_just_pressed("cameraSwitch"):
		#parent.camera_handling()
	##temp

func _state_logic(delta):
	if !parent.camera:
		return
	#uses player script as a library of sorts, calls to grab input, applies movement and gravity
	parent._handle_move_input() 
	#parent._rotate_model()
	parent._apply_gravity(delta)
	parent._apply_movement(delta)


func _get_transition(delta):
	match state: #state loop - setting sates, in each state we lay out possible outcomes to where the state can lead to
		states.idle:
			if !parent.is_on_floor():
				if parent.velocity.y > 0:
					return states.jump
				elif parent.velocity.y < 0:
					return states.fall
			elif parent.velocity.x != 0:
				return states.run
		states.run:
			if !parent.is_on_floor():
				if parent.velocity.y < 0:
					return states.jump
				elif parent.velocity.y > 0:
					return states.fall
			elif parent.velocity.x == 0:
				return states.idle
		states.jump:
			if parent.is_on_floor():
				return states.idle
			elif parent.velocity.y >= 0:
				return states.fall
#			if parent._is_on_wall():
#				return states.wall
		states.fall:
			if parent.is_on_floor():
				#parent._hit_floor()
				print("just hit ground")
				return states.idle
			elif parent.velocity.y < 0:
				return states.jump
		states.dash:
			#elif parent.velocity.y < 0:
			return states.dash
#		states.wall:
#			if !parent._is_on_wall():
#				return states.fall
			#if parent.is_on_floor():
				#return states.idle
	return null

#for anim
func _enter_state(new_state, old_state):
	match new_state:
		states.idle:
			pass#states.anim_player.play("idle")
		states.run:
			pass#states.anim_player.play("run")
		states.jump:
			pass#parent.anim_player.play("jump")
		states.fall:
			pass#parent.anim_player.play()
		states.dash: 
			#parent.anim_player.play("fall")
			parent._start_dash_jump_window()

func _exit_state(new_state, old_state):
	pass
