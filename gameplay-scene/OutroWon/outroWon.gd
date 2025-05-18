extends Node

func _ready() -> void:
	$WinMusic.play()
	$AnimationPlayer.play("appear")
	$AnimationPlayer.play("text_fade")
	await get_tree().create_timer(13).timeout
	$Exit.visible = true
	await get_tree().create_timer(0.5).timeout
	$Exit.disabled = false

func _on_Exit_pressed() -> void:
	$AnimationPlayer.play("leave")
	$Exit.disabled = true
	await get_tree().create_timer(0.5).timeout
	$Exit.visible = false
	await get_tree().create_timer(2).timeout
	$WinMusic.stop()
	get_tree().change_scene_to_file("res://Menu/scenes/menus/main_menu/main_menu.tscn")

	pass # Replace with function body.
