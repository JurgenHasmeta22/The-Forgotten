extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var new_game_button = $VBoxContainer/NewGameButton
@onready var load_game_button = $VBoxContainer/LoadGameButton

func _ready():
	get_tree().paused = false
	add_to_group("start_menu")
	refresh_save_buttons()

func refresh_save_buttons():
	print("StartMenu: Checking for save files...")

	# Find the latest save slot
	var latest_slot = SaveManager.get_latest_save_slot()
	var has_any_saves = (latest_slot > 0)

	# Enable/disable continue button based on if we have any saves
	continue_button.disabled = !has_any_saves

	# Enable/disable load game button based on if we have any saves
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
	var latest_slot = SaveManager.get_latest_save_slot()

	if latest_slot > 0:
		var load_success = SaveManager.load_game(latest_slot)

		if !load_success:
			push_error("StartMenu: Failed to load save from slot " + str(latest_slot))
			# If loading fails, start a new game instead
			_on_new_game_button_pressed()
	else:
		push_error("StartMenu: No valid save files found")
		# Start a new game instead
		_on_new_game_button_pressed()

func _on_new_game_button_pressed():
	SaveManager.new_game()

func _on_load_game_button_pressed():
	print("StartMenu: Load Game button pressed, changing to load game menu")
	# Use GameManager to change the scene instead of direct call
	GameManager.change_scene("res://ui/load_game_menu/load_game_menu.tscn")
