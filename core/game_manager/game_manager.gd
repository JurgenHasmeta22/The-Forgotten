extends Node

# Game state variables
var is_game_paused: bool = false
var current_scene: Node = null
var loading_screen_scene = preload("res://ui/loading_screen/loading_screen.tscn")

# Signals
signal game_paused
signal game_resumed

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
