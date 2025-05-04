extends Control

@onready var start_button = $VBoxContainer/StartButton

func _ready():
	# Ensure the game is not paused when the start menu is shown
	get_tree().paused = false

	# Set focus to the start button
	start_button.grab_focus()

func _input(event):
	if event.is_action_pressed("ui_accept") and start_button.has_focus():
		_on_start_button_pressed()

func _on_start_button_pressed():
	# Show loading screen and change to the main game scene
	GameManager.change_scene_with_loading("res://demo_level/world_castle.tscn")
