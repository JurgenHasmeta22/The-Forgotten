extends Node

# Game state variables
var is_game_paused: bool = false
var current_scene: Node = null
var loading_screen_scene = preload("res://ui/loading_screen/loading_screen.tscn")

# Signals
signal game_paused
signal game_resumed
signal game_loaded

func _ready():
	# Get the current scene
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func _input(event):
	if event.is_action_pressed("pause_game") and current_scene.name != "StartMenu":
		toggle_pause()

# Toggle the game pause state
func toggle_pause():
	is_game_paused = !is_game_paused
	get_tree().paused = is_game_paused

	if is_game_paused:
		game_paused.emit()
	else:
		game_resumed.emit()

# Change to a different scene with a loading screen
func change_scene_with_loading(scene_path: String):
	# Unpause the game if it was paused
	if is_game_paused:
		toggle_pause()

	# Create a new loading screen scene
	var loading_screen = loading_screen_scene.instantiate()

	# Add it directly to the root
	get_tree().root.add_child(loading_screen)

	# Start loading the new scene
	loading_screen.load_scene(scene_path)

# Change to a different scene immediately (without loading screen)
func change_scene(scene_path: String):
	# Unpause the game if it was paused
	if is_game_paused:
		toggle_pause()

	# Use Godot's built-in scene changer
	get_tree().change_scene_to_file(scene_path)

# Load a saved game
func load_game(slot: int = 1):
	# Unpause the game if it was paused
	if is_game_paused:
		toggle_pause()

	# Check if the save exists
	if not SaveManager.save_exists(slot):
		push_error("No save file exists in slot " + str(slot))
		# Stay on current scene if load fails
		return

	print("Loading game from slot " + str(slot))

	# Load the game using SaveManager
	var success = SaveManager.load_game(slot)

	if success:
		game_loaded.emit()
	else:
		push_error("Failed to load game from slot " + str(slot))
		# If loading fails, stay on current scene or go to start menu
		if get_tree().current_scene.name != "StartMenu":
			change_scene("res://ui/start_menu/start_menu.tscn")
