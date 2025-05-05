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

	# Connect to SaveManager signals
	SaveManager.load_completed.connect(_on_save_manager_load_completed)

# Called when SaveManager completes loading a game
func _on_save_manager_load_completed():
	print("GameManager: Save loading completed")
	game_loaded.emit()

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
		push_error("GameManager: No save file exists in slot " + str(slot))
		# Stay on current scene if load fails
		return

	print("GameManager: Loading game from slot " + str(slot))

	# Start the loading process
	# Note: We don't await here because SaveManager.load_game will handle the scene change
	# and we want to return control to the caller immediately
	SaveManager.load_game(slot)

	# The load_completed signal from SaveManager will be emitted when loading is done
	# We can connect to it if we need to do something after loading completes
