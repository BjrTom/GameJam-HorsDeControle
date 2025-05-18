extends Node

func _ready() -> void:
	$IntroMusic.play()
	$AnimationPlayer.play("appear")
	$AnimationPlayer.play("text_fade")
	await get_tree().create_timer(25).timeout
	$Button.visible = true
	await get_tree().create_timer(0.5).timeout
	$Button.disabled = false


func _on_button_pressed() -> void:
	$AnimationPlayer.play("leave")
	$Button.disabled = true
	await get_tree().create_timer(0.5).timeout
	$Button.visible = false
	await get_tree().create_timer(2).timeout
	$IntroMusic.stop()
	get_tree().change_scene_to_file("res://gameplay-scene/game.tscn")
