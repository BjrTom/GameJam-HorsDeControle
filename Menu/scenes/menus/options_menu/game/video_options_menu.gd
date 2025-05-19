extends Node

func _on_censor_toggle_setting_changed(value) -> void:
	Global.censor = value

func _on_difficulty_control_setting_changed(value) -> void:
	if value == "Easy":
		Global.diff = Global.DIFFICULTY.EASY
	if value == "Normal":
		Global.diff = Global.DIFFICULTY.NORMAL
	if value == "Hard":
		Global.diff = Global.DIFFICULTY.HARD
	if value == "Endless":
		Global.diff = Global.DIFFICULTY.ENDLESS
	if value == "Debug":
		Global.diff = Global.DIFFICULTY.DEBUG

func _on_starting_cash_control_setting_changed(value) -> void:
	if value == "1$":
		Global.startCash = 1 
	if value == "5$":
		Global.startCash = 5
	if value == "10$":
		Global.startCash = 10 
