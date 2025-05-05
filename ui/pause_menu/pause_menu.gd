extends Control

@onready var resume_button = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var exit_button = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ExitButton

func _ready():
	# Hide the pause menu initially
	hide()

	# Connect to the GameManager signals
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)

func _on_game_paused():
	show()
	# Set initial focus to the resume button
	resume_button.grab_focus()

func _on_game_resumed():
	hide()

func _input(event):
	if visible:
		if event.is_action_pressed("ui_accept"):
			if resume_button.has_focus():
				_on_resume_button_pressed()
			elif exit_button.has_focus():
				_on_exit_button_pressed()
		elif event.is_action_pressed("ui_down") and resume_button.has_focus():
			exit_button.grab_focus()
		elif event.is_action_pressed("ui_up") and exit_button.has_focus():
			resume_button.grab_focus()

func _on_resume_button_pressed():
	GameManager.toggle_pause()

func _on_exit_button_pressed():
	# Use direct scene change (no loading screen) when going back to start menu
	GameManager.change_scene("res://ui/start_menu/start_menu.tscn")
