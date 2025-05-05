extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var new_game_button = $VBoxContainer/NewGameButton
@onready var load_game_button = $VBoxContainer/LoadGameButton

func _ready():
	# Ensure the game is not paused when the start menu is shown
	get_tree().paused = false

	# Check if there's a save file to enable/disable continue button
	if SaveSystem.save_exists():
		continue_button.disabled = false
	else:
		continue_button.disabled = true

	# Check if there are any save files to enable/disable load game button
	var has_any_saves = false
	for i in range(1, SaveSystem.MAX_SAVE_SLOTS + 1):
		if SaveSystem.save_exists(i):
			has_any_saves = true
			break

	load_game_button.disabled = !has_any_saves

	# Set focus to the appropriate button
	if !continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if continue_button.has_focus() and !continue_button.disabled:
			_on_continue_button_pressed()
		elif new_game_button.has_focus():
			_on_new_game_button_pressed()
		elif load_game_button.has_focus() and !load_game_button.disabled:
			_on_load_game_button_pressed()

func _on_continue_button_pressed():
	# Load the most recent save
	print("Loading most recent save...")
	SaveSystem.load_game()

	# This will load the saved scene and position the player at their saved location

func _on_new_game_button_pressed():
	# Start a new game
	GameManager.change_scene_with_loading("res://levels/prison/world_castle.tscn")

func _on_load_game_button_pressed():
	# Show the load game menu
	get_tree().change_scene_to_file("res://ui/load_game_menu.tscn")
