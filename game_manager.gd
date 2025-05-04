extends Node

# Game state variables
var is_game_paused: bool = false
var current_scene: Node = null

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

# Change to a different scene
func change_scene(scene_path: String):
	# This function will be called when changing scenes
	call_deferred("_deferred_change_scene", scene_path)

func _deferred_change_scene(scene_path: String):
	# Unpause the game if it was paused
	if is_game_paused:
		toggle_pause()
	
	# Free the current scene
	current_scene.free()
	
	# Load the new scene
	var new_scene = load(scene_path)
	
	# Instance the new scene
	current_scene = new_scene.instantiate()
	
	# Add it to the active scene, as child of root
	get_tree().root.add_child(current_scene)
	
	# Optionally, set it as the current scene (not necessary for Godot 4)
	get_tree().current_scene = current_scene
