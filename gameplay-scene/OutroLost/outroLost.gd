extends Node

func _ready() -> void:
	$LostMusic.play()
	$AnimationPlayer.play("appear")
	$AnimationPlayer.play("text_fade")
	await get_tree().create_timer(15).timeout
	$Exit.visible = true
	$Retry.visible = true
	await get_tree().create_timer(0.5).timeout
	$Exit.disabled = false
	$Retry.disabled = false

func _on_Exit_pressed() -> void:
	$AnimationPlayer.play("leave")
	$Exit.disabled = true
	$Retry.disabled = true
	await get_tree().create_timer(3.5).timeout
	$LostMusic.stop()
	get_tree().change_scene_to_file("res://Menu/scenes/menus/main_menu/main_menu.tscn")

func _on_Retry_pressed() -> void:
	$AnimationPlayer.play("leave")
	$Exit.disabled = true
	$Retry.disabled = true
	await get_tree().create_timer(2.25).timeout
	$LostMusic.stop()
	get_tree().change_scene_to_file("res://gameplay-scene/game.tscn")
