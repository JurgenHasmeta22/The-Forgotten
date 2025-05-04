extends Control

func _ready():
	# Hide the pause menu initially
	hide()
	
	# Connect to the GameManager signals
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)

func _on_game_paused():
	show()

func _on_game_resumed():
	hide()

func _on_resume_button_pressed():
	GameManager.toggle_pause()

func _on_exit_button_pressed():
	GameManager.change_scene("res://ui/start_menu.tscn")
