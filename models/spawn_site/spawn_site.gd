extends StaticBody3D

## All interactables function similarly. They have a function called "activate"
## that takes in the player node as an argument. Typically the interactable
## forces the player to a STATIC state, moves the player into a ready postiion,
## triggers the interact on the player while making any changes needed here.

# Called when the node enters the scene tree for the first time.
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var texture_rect = $TextureRect
@export var spawn_scene: PackedScene
@export var reset_level: bool = true # Keep this true to reset enemies when respawning
@onready var audio_stream_player = $AudioStreamPlayer
@onready var flame_particles = $FlameParticles
@onready var interact_type = "SPAWN"
@export var is_bonfire: bool = true
@export var bonfire_id: String = ""

func _ready():
	add_to_group("interactable")
	collision_layer = 9

	# Generate a unique ID for this bonfire if none is provided
	if bonfire_id.is_empty():
		# Use the position as part of the ID to make it unique
		bonfire_id = "bonfire_" + str(get_instance_id()) + "_" + str(global_position.x).substr(0, 4) + "_" + str(global_position.z).substr(0, 4)

	# Check if this is the last bonfire the player visited
	if bonfire_id == SaveManager.last_bonfire_id:
		# Wait for the scene to be fully loaded
		call_deferred("position_player_at_bonfire")

func activate(player: CharacterBody3D):
	if is_bonfire:
		var scene_path = get_tree().current_scene.scene_file_path

		if bonfire_id.is_empty():
			push_error("SpawnSite: Bonfire ID is empty! Generating a new one.")
			bonfire_id = "bonfire_" + str(get_instance_id()) + "_" + str(global_position.x).substr(0, 4) + "_" + str(global_position.z).substr(0, 4)

		# Use the proper function to set bonfire data
		SaveManager.set_last_bonfire(bonfire_id, scene_path)

		# Heal the player when they rest at a bonfire
		if player.health_system:
			player.health_system.current_health = player.health_system.total_health
			player.health_system.health_updated.emit(player.health_system.current_health)

		if player.stamina_system:
			player.stamina_system.current_stamina = player.stamina_system.total_stamina
			player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

		# Play the animation
		player.trigger_interact(interact_type)
		anim_player.play("respawn", .2)

		# Wait for animation to finish
		await anim_player.animation_finished

		# Auto-save the game AFTER animation finishes
		# Explicitly emit the save icon shown signal
		SaveManager.save_icon_shown.emit()

		# Save the game directly
		var _save_success = SaveManager.save_at_bonfire()

		# Make sure the save icon is hidden
		SaveManager.save_icon_hidden.emit()

		# Wait a moment to ensure the save is complete
		await get_tree().create_timer(0.5).timeout

		# Queue free the player before reloading the scene
		player.queue_free()

		# Call respawn which will reload the scene
		respawn()

		return

	# For non-bonfire spawn sites, continue with the original behavior
	player.trigger_interact(interact_type)
	anim_player.play("respawn", .2)
	await anim_player.animation_finished
	player.queue_free()

func activate_visually():
	if is_bonfire and flame_particles:
		# Make sure the flame particles are active
		flame_particles.emitting = true

		# Play sound if needed
		if audio_stream_player and !audio_stream_player.playing:
			audio_stream_player.play()

func position_player_at_bonfire():
	# Wait a moment for the scene to fully load
	await get_tree().create_timer(0.5).timeout

	# Find the player
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	# Position the player at this bonfire
	player.global_position = global_position

	# Activate the bonfire visually
	activate_visually()

	# Reset player health and stamina
	if player.health_system:
		player.health_system.current_health = player.health_system.total_health
		player.health_system.health_updated.emit(player.health_system.current_health)

	if player.stamina_system:
		player.stamina_system.current_stamina = player.stamina_system.total_stamina
		player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

func respawn():
	# Update the SaveManager with this bonfire's data using the proper function
	SaveManager.set_last_bonfire(bonfire_id, get_tree().current_scene.scene_file_path)

	if reset_level:
		# Reload the current scene to reset enemies
		get_tree().reload_current_scene()
	else:
		# This branch is used if you want to keep the world state when resting at a bonfire
		if spawn_scene:
			var new_scene: CharacterBody3D = spawn_scene.instantiate()
			add_sibling(new_scene)
			var new_translation = global_transform.translated_local(Vector3.BACK)
			await get_tree().process_frame
			new_scene.global_transform = new_translation
			new_scene.last_spawn_site = self
