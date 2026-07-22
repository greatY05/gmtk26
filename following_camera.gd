extends Node3D
@onready var camera_pivot: Node3D = $cameraPivot
@onready var camera_arm: SpringArm3D = $cameraPivot/cameraArm
@export var target: CharacterBody3D

@export_group("Left/right deadzone (screen x)")
@export var deadzone_right = 0.4
@export var catchup_right = 0.15
@export var recenter_damp = 0.08          # pulls back to center when player is idle
@export var move_threshold = 0.15         # below this horizontal speed = "idle"

@export_group("Forward/back - always tracked, no deadzone")
@export var catchup_forward = 0.1

@export_group("Vertical - grounded")
@export var damp_factor_y_ground = 0.06

@export_group("Vertical - rising (deadzone box)")
@export var deadzone_up = 2.0
@export var catchup_vertical_air = 0.01 

@export_group("Vertical - falling (continuous, keeps player upper-half)")
@export var fall_view_offset = 4.0        # camera sits this far below player while falling
@export var fall_catchup = 0.08
@export var min_fall_margin = 1.0         # camera can never get closer than this - player can't cross center

var cam_offset = Vector3(0, 1.5, 0)

func _ready() -> void:
	camera_pivot.position = cam_offset
	if target:
		position = target.position + Vector3(0, cam_offset.y, 0)

@export var deadzone_right_max = 1.3      # how far it's allowed to stretch under high speed
@export var speed_for_max_stretch = 12.0  # speed at which the stretch caps out

func _process(delta: float) -> void:
	var cam_fwd = -camera_pivot.global_transform.basis.z
	cam_fwd.y = 0; cam_fwd = cam_fwd.normalized()
	var cam_right = camera_pivot.global_transform.basis.x
	cam_right.y = 0; cam_right = cam_right.normalized()

	var to_player = target.position - position
	to_player.y = 0
	var offset_right = to_player.dot(cam_right)
	var offset_fwd = to_player.dot(cam_fwd)

	var horizontal_speed = Vector3(target.velocity.x, 0, target.velocity.z).length()
	var moving = horizontal_speed > move_threshold

	var speed_factor = clamp(horizontal_speed / speed_for_max_stretch, 0.0, 1.0)
	var effective_deadzone_right = lerp(deadzone_right, deadzone_right_max, speed_factor)

	var move = Vector3.ZERO
	move += cam_fwd * offset_fwd * catchup_forward

	if abs(offset_right) > effective_deadzone_right:
		var excess = offset_right - sign(offset_right) * effective_deadzone_right
		move += cam_right * excess * catchup_right
	elif not moving:
		move += cam_right * offset_right * recenter_damp

	position.x += move.x
	position.z += move.z

	#vertical - Y handling
	if target._is_groundborne():
		var ground_y = target._get_ground_y()
		position.y += (ground_y + cam_offset.y - position.y) * damp_factor_y_ground
	elif target.velocity.y < 0:
		#falling logic, lets the player fall freely, stick him to the upper half of hte screen, can never pass it
		var fall_target_y = target.position.y - fall_view_offset
		position.y += (fall_target_y - position.y) * fall_catchup
		position.y = min(position.y, target.position.y - min_fall_margin)
	else:
		# rising  deadzone box
		var offset_y = target.position.y - position.y
		if offset_y > deadzone_up:
			position.y += (offset_y - deadzone_up) * catchup_vertical_air

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.x -= event.screen_relative.y / target.current_mouse_sensitivity
		camera_pivot.rotation.y -= event.screen_relative.x / target.current_mouse_sensitivity
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-50), deg_to_rad(30))
