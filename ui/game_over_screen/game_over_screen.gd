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

		# Make sure the bonfire data is loaded from config
		SaveManager._load_config()

		# Force a reload of the config to ensure we have the latest data
		var config = ConfigFile.new()
		var err = config.load("user://save_config.cfg")
		if err == OK:
			# Load the bonfire data directly from config
			var pos_x = config.get_value("bonfire", "position_x", 0.0)
			var pos_y = config.get_value("bonfire", "position_y", 0.0)
			var pos_z = config.get_value("bonfire", "position_z", 0.0)
			SaveManager.last_bonfire_position = Vector3(pos_x, pos_y, pos_z)
			SaveManager.last_bonfire_id = config.get_value("bonfire", "id", "")
			SaveManager.last_bonfire_scene = config.get_value("bonfire", "scene", "")

		# Verify the bonfire data
		print("Game Over: Bonfire data for respawn:")
		print("  - Position: " + str(SaveManager.last_bonfire_position))
		print("  - ID: " + SaveManager.last_bonfire_id)
		print("  - Scene: " + SaveManager.last_bonfire_scene)

		# Create a callback to position the player after the scene is loaded
		var position_player_callback = func():
			# Wait for the scene to be fully loaded and ready
			await get_tree().process_frame
			await get_tree().create_timer(0.5).timeout

			print("Game Over: Scene loaded, positioning player at bonfire")

			# Find the player
			var player = get_tree().get_first_node_in_group("player")
			if player:
				# Position the player at the bonfire
				player.global_position = SaveManager.last_bonfire_position
				print("Game Over: Player positioned at bonfire: " + str(SaveManager.last_bonfire_position))

				# Reset player health and stamina
				if player.health_system:
					player.health_system.current_health = player.health_system.total_health
					player.health_system.health_updated.emit(player.health_system.current_health)

				if player.stamina_system:
					player.stamina_system.current_stamina = player.stamina_system.total_stamina
					player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

				# Find all bonfires in the scene
				var bonfires = get_tree().get_nodes_in_group("interactable")
				var found_matching_bonfire = false

				print("Game Over: Looking for bonfire with ID: " + SaveManager.last_bonfire_id)
				print("Game Over: Found " + str(bonfires.size()) + " interactables")

				# First, try to find the exact bonfire by ID
				for bonfire in bonfires:
					# Check if this is the bonfire we want to respawn at
					if bonfire.has_method("get_bonfire_id"):
						var bonfire_id = bonfire.get_bonfire_id()
						print("Game Over: Checking bonfire with ID: " + bonfire_id)

						if bonfire_id == SaveManager.last_bonfire_id:
							print("Game Over: Found matching bonfire: " + bonfire_id)
							found_matching_bonfire = true

							# Update the player position to match the exact bonfire position
							player.global_position = bonfire.global_position
							print("Game Over: Updated player position to exact bonfire position: " + str(bonfire.global_position))

							# Activate the bonfire visually if possible
							if bonfire.has_method("activate_visually"):
								bonfire.activate_visually()
								print("Game Over: Activated bonfire visually")

							break
					else:
						print("Game Over: Interactable doesn't have get_bonfire_id method: " + bonfire.name)

				if !found_matching_bonfire:
					print("Game Over: Could not find matching bonfire, using saved position")

					# As a fallback, position the player at the saved position
					player.global_position = SaveManager.last_bonfire_position
					print("Game Over: Positioned player at saved position: " + str(SaveManager.last_bonfire_position))
			else:
				print("Game Over: Player not found after scene load")

		# Connect to the tree_changed signal to detect when the scene is loaded
		get_tree().tree_changed.connect(position_player_callback, CONNECT_ONE_SHOT)

		# Load the scene
		GameManager.change_scene_with_loading(SaveManager.last_bonfire_scene)

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
	GameManager.change_scene("res://ui/start_menu/start_menu.tscn")
