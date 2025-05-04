extends Control

@onready var respawn_button = $VBoxContainer/ButtonsContainer/RespawnButton
@onready var quit_button = $VBoxContainer/ButtonsContainer/QuitButton
@onready var animation_player = $AnimationPlayer

func _ready():
	# Set focus to the respawn button
	respawn_button.grab_focus()

	# Make sure the game is not paused
	get_tree().paused = false

	# Play the fade-in animation
	animation_player.play("fade_in")

func _input(event):
	if visible:
		if event.is_action_pressed("ui_accept"):
			if respawn_button.has_focus():
				_on_respawn_button_pressed()
			elif quit_button.has_focus():
				_on_quit_button_pressed()

func _on_respawn_button_pressed():
	# Hide the game over screen
	hide()

	# Respawn at the last bonfire
	if SaveSystem.last_bonfire_scene.is_empty():
		# If no bonfire has been visited, just reload the current scene
		get_tree().reload_current_scene()
	else:
		# Respawn at the last bonfire
		SaveSystem.respawn_at_last_bonfire()

func _on_quit_button_pressed():
	# Hide the game over screen
	hide()

	# Return to the main menu
	GameManager.change_scene("res://ui/start_menu.tscn")
