extends Control

func _ready():
	# Ensure the game is not paused when the start menu is shown
	get_tree().paused = false

func _on_start_button_pressed():
	# Change to the main game scene
	GameManager.change_scene("res://demo_level/world_castle.tscn")
