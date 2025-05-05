extends Control

@onready var respawn_button = $VBoxContainer/ButtonsContainer/RespawnButton
@onready var quit_button = $VBoxContainer/ButtonsContainer/QuitButton
@onready var animation_player = $AnimationPlayer

func _ready():
	# Set focus to the respawn button
	respawn_button.grab_focus()

	# Pause the game to stop all gameplay, including enemy AI and sounds
	get_tree().paused = true

	# Mute all gameplay sounds by setting the audio bus volume
	mute_gameplay_sounds()

	# Play the fade-in animation if it exists
	if animation_player.has_animation("fade_in"):
		animation_player.play("fade_in")
	else:
		# If animation doesn't exist, just set the modulate directly
		modulate = Color(1, 1, 1, 1)

# Mute all gameplay sounds
func mute_gameplay_sounds():
	# Get the master audio bus index
	var master_idx = AudioServer.get_bus_index("Master")

	# Store the current volume to restore later if needed
	var _current_volume = AudioServer.get_bus_volume_db(master_idx)

	# Mute the master bus (affects all sounds)
	AudioServer.set_bus_mute(master_idx, true)

func _input(event):
	if visible:
		if event.is_action_pressed("ui_accept"):
			if respawn_button.has_focus():
				_on_respawn_button_pressed()
			elif quit_button.has_focus():
				_on_quit_button_pressed()

func _on_respawn_button_pressed():
	# Unmute sounds before leaving the game over screen
	unmute_gameplay_sounds()

	# Hide the game over screen
	hide()

	# Queue free to remove this screen completely
	queue_free()

	# Unpause the game
	get_tree().paused = false

	# Respawn at the last bonfire
	if SaveManager.last_bonfire_scene.is_empty():
		# If no bonfire has been visited, just reload the current scene
		get_tree().reload_current_scene()
	else:
		# Respawn at the last bonfire - this will reset the level AND place you at the last bonfire
		print("Respawning at last bonfire: " + SaveManager.last_bonfire_id)
		SaveManager.respawn_at_last_bonfire()

# Unmute all gameplay sounds
func unmute_gameplay_sounds():
	# Get the master audio bus index
	var master_idx = AudioServer.get_bus_index("Master")

	# Unmute the master bus
	AudioServer.set_bus_mute(master_idx, false)

func _on_quit_button_pressed():
	# Unmute sounds before leaving the game over screen
	unmute_gameplay_sounds()

	# Hide the game over screen
	hide()

	# Queue free to remove this screen completely
	queue_free()

	# Unpause the game (important for scene transitions)
	get_tree().paused = false

	# Return to the main menu
	GameManager.change_scene("res://ui/start_menu.tscn")
