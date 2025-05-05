extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var new_game_button = $VBoxContainer/NewGameButton
@onready var load_game_button = $VBoxContainer/LoadGameButton

func _ready():
	# Ensure the game is not paused when the start menu is shown
	get_tree().paused = false

	# Add this menu to a group so SaveManager can find it
	add_to_group("start_menu")

	# Check for save files and update buttons
	refresh_save_buttons()

# Function to refresh the save buttons (can be called from SaveManager)
func refresh_save_buttons():
	print("StartMenu: Checking for save files...")

	# Check if there's a save file to enable/disable continue button
	var has_current_save = SaveManager.save_exists()
	print("StartMenu: Current save exists: " + str(has_current_save))
	continue_button.disabled = !has_current_save

	# Check if there are any save files to enable/disable load game button
	var has_any_saves = false
	for i in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		var slot_has_save = SaveManager.save_exists(i)
		print("StartMenu: Save slot " + str(i) + " exists: " + str(slot_has_save))
		if slot_has_save:
			has_any_saves = true
			break

	print("StartMenu: Any saves exist: " + str(has_any_saves))
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
	print("StartMenu: Loading most recent save...")

	# Make sure we're using the current save slot
	var current_slot = SaveManager.current_save_slot
	print("StartMenu: Using save slot: " + str(current_slot))

	# Check if the save exists before trying to load it
	if SaveManager.save_exists(current_slot):
		print("StartMenu: Valid save found in slot " + str(current_slot))
		# Use GameManager to load the save
		GameManager.load_game(current_slot)
	else:
		push_error("StartMenu: No save file exists in slot " + str(current_slot))
		# Try to find any valid save slot
		for i in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
			if SaveManager.save_exists(i):
				print("StartMenu: Found valid save in slot " + str(i))
				# Use GameManager to load the save
				GameManager.load_game(i)
				return

		# If we get here, no valid saves were found
		push_error("StartMenu: No valid save files found")

func _on_new_game_button_pressed():
	# Start a new game
	GameManager.change_scene_with_loading("res://levels/prison/prison.tscn")

func _on_load_game_button_pressed():
	# Show the load game menu
	get_tree().change_scene_to_file("res://ui/load_game_menu/load_game_menu.tscn")
