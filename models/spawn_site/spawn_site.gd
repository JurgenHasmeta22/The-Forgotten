extends StaticBody3D

## All interactables function similarly. They have a function called "activate"
## that takes in the player node as an argument. Typically the interactable
## forces the player to a STATIC state, moves the player into a ready postiion,
## triggers the interact on the player while making any changes needed here.

# Called when the node enters the scene tree for the first time.
@onready var anim_player :AnimationPlayer = $AnimationPlayer
@onready var texture_rect = $TextureRect
@export var spawn_scene : PackedScene
@export var reset_level : bool = true  # Keep this true to reset enemies when respawning
@onready var audio_stream_player = $AudioStreamPlayer
@onready var flame_particles = $FlameParticles
@onready var interact_type = "SPAWN"
@export var is_bonfire: bool = true  # Whether this spawn site acts as a bonfire (save point)
@export var bonfire_id: String = ""  # Unique identifier for this bonfire

func _ready():
	add_to_group("interactable")
	collision_layer = 9

	# Generate a unique ID for this bonfire if none is provided
	if bonfire_id.is_empty():
		# Use the position as part of the ID to make it unique
		bonfire_id = "bonfire_" + str(get_instance_id()) + "_" + str(global_position.x).substr(0, 4) + "_" + str(global_position.z).substr(0, 4)
		print("Generated bonfire ID: " + bonfire_id + " at position: " + str(global_position))

	# Print the bonfire ID for debugging
	print("SpawnSite: Bonfire initialized with ID: " + bonfire_id + " at position: " + str(global_position))

# Return the bonfire ID for use by the SaveManager
func get_bonfire_id() -> String:
	return bonfire_id

func activate(player: CharacterBody3D):
	# Set this as the last bonfire if it's a bonfire
	if is_bonfire:
		# Store the position in a local variable to ensure it's captured correctly
		var bonfire_pos = global_position
		print("Activating bonfire at position: " + str(bonfire_pos) + ", ID: " + bonfire_id)

		# Save this bonfire as the last one visited
		print("SpawnSite: Setting last bonfire - ID: " + bonfire_id + ", Position: " + str(bonfire_pos))
		var scene_path = get_tree().current_scene.scene_file_path

		# Save the bonfire data directly to the config file
		SaveManager.last_bonfire_position = bonfire_pos
		SaveManager.last_bonfire_id = bonfire_id
		SaveManager.last_bonfire_scene = scene_path
		SaveManager._save_config()

		# Double-check that the config was saved correctly by reloading it
		SaveManager._load_config()

		# Verify the data was saved correctly
		print("SpawnSite: Verifying bonfire data after save:")
		print("  - Position: " + str(SaveManager.last_bonfire_position))
		print("  - ID: " + str(SaveManager.last_bonfire_id))
		print("  - Scene: " + SaveManager.last_bonfire_scene)

		# Heal the player when they rest at a bonfire
		if player.health_system:
			player.health_system.current_health = player.health_system.total_health
			player.health_system.health_updated.emit(player.health_system.current_health)

		if player.stamina_system:
			player.stamina_system.current_stamina = player.stamina_system.total_stamina
			player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

		# Play the animation
		player.trigger_interact(interact_type)
		anim_player.play("respawn",.2)

		# Wait for animation to finish
		await anim_player.animation_finished

		# Make sure the bonfire data is saved to the config file again
		print("SpawnSite: Ensuring bonfire data is saved to config")
		SaveManager._save_config()

		# Auto-save the game AFTER animation finishes
		print("SpawnSite: Saving game after bonfire interaction")

		# Explicitly emit the save icon shown signal
		SaveManager.save_icon_shown.emit()

		# Save the game directly
		var save_success = await SaveManager.save_game(SaveManager.current_save_slot)
		print("SpawnSite: Save result: " + str(save_success))

		# Make sure the save icon is hidden
		SaveManager.save_icon_hidden.emit()

		# Force a save config update to ensure the bonfire data is saved
		SaveManager._save_config()

		# Wait a moment to ensure the save is complete
		await get_tree().create_timer(0.5).timeout

		# Queue free the player before reloading the scene
		player.queue_free()

		# Call respawn which will reload the scene
		respawn()

		return

	# For non-bonfire spawn sites, continue with the original behavior
	player.trigger_interact(interact_type)
	anim_player.play("respawn",.2)
	await anim_player.animation_finished
	player.queue_free()


# Activate the bonfire visually without player interaction
func activate_visually():
	if is_bonfire and flame_particles:
		# Make sure the flame particles are active
		flame_particles.emitting = true

		# Play sound if needed
		if audio_stream_player and !audio_stream_player.playing:
			audio_stream_player.play()

		print("SpawnSite: Bonfire " + bonfire_id + " activated visually")

func respawn():
	# This function is called when a player interacts with the bonfire
	# For respawning after death, SaveManager.respawn_at_last_bonfire() is used instead

	# Make sure the bonfire data is saved to the config file one last time
	SaveManager._save_config()

	# Print the current bonfire data for debugging
	print("SpawnSite: Respawning with bonfire data:")
	print("  - ID: " + SaveManager.last_bonfire_id)
	print("  - Position: " + str(SaveManager.last_bonfire_position))
	print("  - Scene: " + SaveManager.last_bonfire_scene)

	if reset_level:
		# Reset the level to respawn all enemies
		# This is the Dark Souls behavior - reset the world when resting at a bonfire
		get_tree().reload_current_scene()
	else:
		# This branch is used if you want to keep the world state when resting at a bonfire
		if spawn_scene:
			var new_scene : CharacterBody3D = spawn_scene.instantiate()
			add_sibling(new_scene)
			var new_translation = global_transform.translated_local(Vector3.BACK)
			await get_tree().process_frame
			new_scene.global_transform = new_translation
			new_scene.last_spawn_site = self
