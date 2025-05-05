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
		SaveManager.set_last_bonfire(bonfire_pos, bonfire_id, scene_path)

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

		# Make sure the bonfire data is saved to the config file
		print("SpawnSite: Ensuring bonfire data is saved to config")
		SaveManager._save_config()

		# Auto-save the game AFTER animation finishes
		print("SpawnSite: Saving game after bonfire interaction")
		var save_success = await SaveManager.save_game()
		print("SpawnSite: Save result: " + str(save_success))

		# Create a callback to position the player after the scene is reloaded
		var position_player_callback = func():
			# Wait for the scene to be fully loaded and ready
			await get_tree().process_frame
			await get_tree().create_timer(0.5).timeout

			# Find the player and move them to this bonfire position
			var new_player = get_tree().get_first_node_in_group("player")
			if new_player:
				new_player.global_position = bonfire_pos
				print("Player positioned at bonfire: " + str(bonfire_pos))

				# Reset player health and stamina
				if new_player.health_system:
					new_player.health_system.current_health = new_player.health_system.total_health
					new_player.health_system.health_updated.emit(new_player.health_system.current_health)

				if new_player.stamina_system:
					new_player.stamina_system.current_stamina = new_player.stamina_system.total_stamina
					new_player.stamina_system.stamina_updated.emit(new_player.stamina_system.current_stamina)
			else:
				push_error("Player not found after scene reload")

		# Connect to the tree_changed signal to detect when the scene is reloaded
		get_tree().tree_changed.connect(position_player_callback, CONNECT_ONE_SHOT)

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


func respawn():
	# This function is called when a player interacts with the bonfire
	# For respawning after death, SaveManager.respawn_at_last_bonfire() is used instead

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
