extends StateMachine


func _ready():
	add_state("idle")       #1
	add_state("walk")       #2
	add_state("run")        #3
	add_state("dash")       #4
	add_state("fall")       #5
	#add_state("shooting")   
	add_state("jump")        #6
	add_state("airjump")     #7
	add_state("dashjump")    #8
	add_state("death")    #8
	#add_state("wall")       
	#add_state("climb")      
	#add_state("hanging")    #8
	call_deferred("set_state", states.idle) #sets state during idle time avoiding runtime issues, letting parent init states properly
	
	parent.cogs_left = parent.cogs_allowed



func _input(event: InputEvent) -> void:
	if [states.fall, states.idle, states.run, states.walk, states.jump, states.airjump, states.dash].has(state): #check if our current state is within the given list
		#jump
		if Input.is_action_just_pressed("jump"):
			if !parent.is_on_floor():
				if !parent.cogs_left >0:
					return
				parent._air_jump()
				set_state(states.airjump)
			else:
				parent._jump()
		if Input.is_action_just_released("jump"):
			#if !parent.is_airjumping:
			parent._jump_release()#?
	#if [states.climb, states.wall].has(state): #wall jumping
		#if Input.is_action_just_pressed("jump"):
			#parent._wall_jump()
		#if Input.is_action_just_pressed("ui_focus_next"): ##dev mode
			#parent._collected_cog()
			#parent.cogs_left = 99
			#parent.cogs_allowed = 99
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
	
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and !$"../../menu".visible: #capture mouse on click
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
	#print(state)
	if !parent.camera:
		return
	#uses player script as a library of sorts, calls to grab input, applies movement and gravity
	parent._handle_move_input() 
	#parent._rotate_model()
	parent._apply_gravity(delta)
	parent._apply_movement(delta)
	
	#sound that uses delta
	if state == states.run:
		parent._update_footstep_timer(delta, true)
	else:
		parent._update_footstep_timer(delta, false)


func _get_transition(delta):
	match state: #state loop - setting sates, in each state we lay out possible outcomes to where the state can lead to
		states.idle:
			if !parent.is_on_floor():
				if parent.velocity.y > 0:
					return states.jump
				elif parent.velocity.y <= 0:
					return states.fall
			elif parent.velocity.x != 0:
				return states.run
			elif parent.is_dashjumping:
				return states.dashjump
		states.run:
			if !parent.is_on_floor():
				if parent.velocity.y > 0:
					return states.jump
				elif parent.velocity.y <= 0:
					return states.fall
			elif parent.velocity.x == 0:
				return states.idle
			elif parent.is_dashing:
				return states.dash
			elif parent.is_dashjumping:
				return states.dashjump
		states.jump:
			if parent.is_on_floor():
				return states.idle
			elif parent.is_dashing:
				return states.dash
			elif parent.velocity.y <= 0:
				return states.fall
			elif parent.is_airjumping:
				return states.airjump
			elif parent.is_dashjumping:
				return states.dashjump
		states.fall:
			if parent.is_on_floor():
				#parent._hit_floor()
				print("just hit ground")
				return states.idle
			elif parent.is_airjumping:
				return states.airjump
			elif parent.velocity.y > 0:
				return states.jump
			elif parent.is_dashing:
				return states.dash
		states.dash:
			#elif parent.velocity.y < 0:
			if !parent.is_dashing:
				if parent.is_on_floor():
					return states.idle
				elif parent.velocity.y <= 0:
					return states.fall
				elif parent.velocity.y >= 0:
					return states.jump
			elif parent.is_dashjumping:
				return states.dashjump
			elif parent.is_airjumping:
				return states.airjump
		states.airjump:
			if parent.velocity.y <= 0:
				return states.fall
			elif parent.is_on_floor():
				return states.idle
			elif parent.is_dashjumping:
				return states.dashjump
		states.dashjump:
			if parent.velocity.y <= 7:
				return states.jump
			elif parent.is_airjumping:
				return states.airjump
		states.death:
			pass
#		states.wall:
#			if !parent._is_on_wall():
#				return states.fall
			#if parent.is_on_floor():
				#return states.idle
	return null

#for anim
func _enter_state(new_state, old_state):
	match new_state:
		states.dash: 
			if !parent.is_frozen:
				parent.animation_player.play("dash")
				print("yo yo dash")
				$"../sounds/dash".play()
			#parent.anim_player.play("fall")
			pass#parent._start_dash_jump_window()
		states.dashjump:
			if !parent.is_frozen:
				$"../sounds/dash".stop()
				$"../sounds/dashjump".play()
			parent.animation_player.play("dashjump")
		states.jump:
			if !parent.is_frozen:
				$"../sounds/jump".play()
			
			if parent.velocity.y  >  30:
				print(parent.velocity.y)
				parent.animation_player.play("jump peak")
			else:
				parent.animation_player.play("jump raise")
			#pass#parent.anim_player.play("jump")
		states.fall:
			parent.animation_player.play("fall")
			pass#parent.anim_player.play()
		states.idle:
			parent.animation_player.play("idle")
			#pass#states.anim_player.play("idle")
		states.run:
			parent.animation_player.play("run")
			#pass#states.anim_player.play("run")
		states.airjump:
			if !parent.is_frozen:
				$"../sounds/dash".stop()
			
			pass#$"../sounds/airjump".stop()
			#$"../sounds/airjump".play()

func _exit_state(new_state, old_state):
	pass
