extends Area3D

@onready var animation_player: AnimationPlayer = $cog/AnimationPlayer

func _ready() -> void:
	animation_player.play("idle")


func _collect():
	get_tree().get_first_node_in_group("active_scene")._reset_clock()
	remove_from_group("collectiable")
	animation_player.play("collected")
	$sound.play()
	await get_tree().create_timer(1.6).timeout
	if animation_player.animation_finished:
		$cog.hide()
	$particles.restart()
	await $particles.finished
	$light.hide()
	set_deferred("monitorable", false)
