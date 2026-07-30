extends Node3D

@onready var time_label: Label = $CanvasLayer/time_label

@onready var tick_sound: AudioStreamPlayer3D = $sounds/tick
@onready var tock_sound: AudioStreamPlayer3D = $sounds/tock
@export var clock_interval: float = 2.0

@onready var bell_toll: AudioStreamPlayer = $sounds/deathtoll

@onready var hero: CharacterBody3D = $hero

var deathclock_starting_time = 15

var deathclock_time = 15

var label_scale = 1.3

var win_con = false

var is_demo_complete = false

var clock_timer: float = 0.0
var is_ticking = false
var next_is_tick = true  # alternates each call

func _ready() -> void:
	$sounds/fanambient.play()
	$sounds/humambient.play()

func _process(delta: float) -> void:
	if not is_ticking:
		return
	clock_timer -= delta
	
	if clock_timer <= 0.0:
		_play_clock()
		clock_timer = clock_interval
	
	_is_deathclock_done()
	
	

func _spin_cogs(spin_odd: bool):
	var children = $CanvasLayer/CenterContainer.get_children()
	for idx in range(children.size()):
		var is_odd = (idx % 2 == 0)
		if is_odd == spin_odd:
			var tween = create_tween()
			tween.tween_property(children[idx], "rotation_degrees", children[idx].rotation_degrees + 90, 0.1)



func _play_clock():
	
	if win_con or !is_demo_complete:
		return
	var player = tick_sound if next_is_tick else tock_sound
	player.pitch_scale = randf_range(0.97, 1.03)  # subtle - a clock's tick/tock should stay consistent, not vary much
	player.play()
	
	_spin_cogs(next_is_tick)
	next_is_tick = !next_is_tick
	
	deathclock_time -= 1
	
	if deathclock_time == 1:
		bell_toll.play()
	
	time_label.text = str(deathclock_time)
	
	time_label.scale = Vector2(label_scale, label_scale)
	
	var tween = create_tween()
	tween.tween_property(time_label, "scale", Vector2(1,1), 0.3).set_ease(Tween.EASE_OUT_IN)

func _is_deathclock_done():
	if deathclock_time <= 0 and bell_toll.finished:
		hero._die()
		is_ticking = false
		await get_tree().create_timer(2).timeout
		$CanvasLayer/respawn.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 

func _reset_clock():
	if !is_demo_complete:
		if $hero.cogs_allowed >= 3:
			_demo()
	if deathclock_time < deathclock_starting_time:
		is_ticking = false
		deathclock_time += 1
		time_label.text = str(deathclock_time)
		time_label.scale = Vector2(label_scale, label_scale)
		$sounds/tickup.play()
		var tween = create_tween()
		tween.tween_property(time_label, "scale", Vector2(1,1), 0.1).set_ease(Tween.EASE_OUT_IN)
		await tween.finished
		await get_tree().create_timer(0.15)
		_reset_clock()
	else:
		is_ticking = true

func _on_fall_catch_body_entered(body: Node3D) -> void:
	body.position = Vector3(0.0, 5, 0)


func _on_startgame_button_down() -> void:
	$transitionscreen.show()
	var tween = create_tween()
	tween.tween_property($transitionscreen, "modulate:a", 1, 0.5)
	await tween.finished
	
	
	$tutorials.show()
	$CanvasLayer.show()
	_demo()
	$menu.hide()
	$CanvasLayer.show()
	$cameraRig/cameraPivot/cameraArm/Camera.set_current(true)
	
	var tween2 = create_tween()
	tween2.tween_property($transitionscreen, "modulate:a", 0, 0.5)
	await tween2.finished
	$transitionscreen.hide()

func _on_restartgame_button_down() -> void:
	get_tree().reload_current_scene()


func _on_freeplay_button_down() -> void:
	hero.respawn()
	
	$ending.hide()
	$cameraRig/cameraPivot/cameraArm/Camera.set_current(true)
	$CanvasLayer.hide()



func _win():
	win_con = true
	is_ticking = false
	hero.is_frozen = true

	var cogs = $CanvasLayer/CenterContainer.get_children()
	for cog in cogs:
		await _explode_cog(cog)
		await get_tree().create_timer(0.10).timeout
	
	$CanvasLayer.hide()
	$transitionscreen.show()
	var tween = create_tween()
	tween.tween_property($transitionscreen, "modulate:a", 1, 1)
	await tween.finished
	
	$"ending/Camera3D".set_current(true)
	$"ending".show()
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	
	
	var tween2 = create_tween()
	tween2.tween_property($transitionscreen, "modulate:a", 0, 1)
	await tween2.finished
	$transitionscreen.hide()

func _demo():
	if $hero.cogs_allowed >= 3:
		_lower_demo_wall()

func _lower_demo_wall():
	await get_tree().create_timer(1).timeout
	var tween = create_tween().set_parallel(true)
	tween.tween_property($demo_wall, "position:y", -25, 4)
	$sounds/lowerwall.play()
	await tween.finished
	
	$CanvasLayer/time_label.show()
	is_demo_complete = true
	is_ticking = true
	$tutorials/tick_exp.show()
	await get_tree().create_timer(6).timeout
	$tutorials/tick_exp.hide()
	
	$tutorials/tick_negate_exp.show()
	await get_tree().create_timer(6).timeout
	$tutorials/tick_negate_exp.hide()
	


func _explode_cog(cog: Control):
	# glow
	var glow_tween = create_tween()
	glow_tween.tween_property(cog, "modulate", Color(2.5, 2.5, 1.5, 1.0), 0.5).set_ease(Tween.EASE_OUT)
	await glow_tween.finished

	# explosion - grow + fade, same shape as the existing cog-use animation
	var explode_tween = create_tween().set_parallel(true)
	explode_tween.tween_property(cog, "scale", cog.scale * 2.0, 0.1).set_ease(Tween.EASE_OUT)
	explode_tween.tween_property(cog, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_OUT)

	# once you add the sound node, uncomment:
	$sounds/tickup.play()

	await explode_tween.finished
	cog.hide()

	# clock ticks down one second per cog, with the existing grow/shrink pop
	deathclock_time = max(deathclock_time - 1, 0)
	time_label.text = str(deathclock_time)
	time_label.scale = Vector2(label_scale, label_scale)
	var label_tween = create_tween()
	label_tween.tween_property(time_label, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT_IN)

## tutorial areas ----------------


func _on_walkjump_exp_area_entered(area: Area3D) -> void:
	if area.name != "pickup_area": return
	$tutorials/walk_jump_exp.show()

func _on_walk_jump_exp_area_exited(area: Area3D) -> void:
	$tutorials/walk_jump_exp.hide()


func _on_dash_exp_area_entered(area: Area3D) -> void:
	if area.name != "pickup_area" or hero.cogs_allowed < 1 or is_demo_complete: return
	
	$tutorials/dash_jump_exp.show()

func _on_dash_exp_area_exited(area: Area3D) -> void:
	$tutorials/dash_jump_exp.hide()

func _on_airjump_exp_area_entered(area: Area3D) -> void:
	if area.name != "pickup_area" or hero.cogs_allowed < 1 or is_demo_complete: return
	
	$tutorials/air_jump_exp.show()

func _on_airjump_exp_area_exited(area: Area3D) -> void:
	$tutorials/air_jump_exp.hide()


func _on_gear_exp_area_entered(area: Area3D) -> void:
	if area.name != "pickup_area" or is_demo_complete: return
	$tutorials/gear_exp.show()


func _on_gear_exp_area_exited(area: Area3D) -> void:
	$tutorials/gear_exp.hide()

var is_music_mute = false
func _on_musicmute_button_down() -> void:
	is_music_mute = !is_music_mute
	if is_music_mute:$menu/musicmute.add_theme_color_override("font_color", Color(0.95, 0.342, 0.453, 1.0))
	else: $menu/musicmute.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0)) 
	var bgm = AudioServer.get_bus_index("bgm")
	AudioServer.set_bus_mute(bgm, is_music_mute)


var is_sfx_mute = false
func _on_sfxmute_button_down() -> void:
	is_sfx_mute = !is_sfx_mute
	if is_music_mute:$menu/sfxmute.add_theme_color_override("font_color", Color(0.95, 0.342, 0.453, 1.0)) 
	else: $menu/sfxmute.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0)) 
	var bgm = AudioServer.get_bus_index("bgm")
	AudioServer.set_bus_mute(bgm, is_sfx_mute)


func _on_gear_exp_2_area_entered(area: Area3D) -> void:
	if area.name != "pickup_area" or is_demo_complete: return
	$tutorials/gear_exp2.show()


func _on_gear_exp_2_area_exited(area: Area3D) -> void:
	if area.name != "pickup_area": return
	$tutorials/gear_exp2.hide()
	


func _on_respawn_button_down() -> void:
	hero._respawn()
	$CanvasLayer/respawn.hide()
	_reset_clock()
