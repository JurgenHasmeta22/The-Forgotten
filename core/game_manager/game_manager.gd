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
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	SaveManager.load_completed.connect(_on_save_manager_load_completed)

func _on_save_manager_load_completed():
	game_loaded.emit()

func _input(event):
	if event.is_action_pressed("pause_game") and current_scene.name != "StartMenu":
		toggle_pause()

func toggle_pause():
	is_game_paused = !is_game_paused
	get_tree().paused = is_game_paused

	if is_game_paused:
		game_paused.emit()
	else:
		game_resumed.emit()

func change_scene_with_loading(scene_path: String):
	if is_game_paused:
		toggle_pause()

	var loading_screen = loading_screen_scene.instantiate()
	get_tree().root.add_child(loading_screen)
	loading_screen.load_scene(scene_path)

func change_scene(scene_path: String):
	if is_game_paused:
		toggle_pause()

	get_tree().change_scene_to_file(scene_path)
