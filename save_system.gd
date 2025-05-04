extends Node

# Save System for The Forgotten
# Handles saving and loading game data, with auto-save functionality at bonfires

signal save_started
signal save_completed
signal load_started
signal load_completed

const SAVE_DIR = "user://saves/"
const SAVE_FILE_EXTENSION = ".save"
const MAX_SAVE_SLOTS = 3
const CURRENT_SAVE_VERSION = 1

var current_save_slot = 1
var is_saving = false
var is_loading = false
var last_bonfire_position = Vector3.ZERO
var last_bonfire_scene = ""
var last_bonfire_id = "" # Unique identifier for the last bonfire used

func _ready():
	# Create the saves directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)

# Save the current game state to the specified slot
func save_game(slot: int = current_save_slot) -> bool:
	if is_saving:
		return false

	is_saving = true
	save_started.emit()

	# Set the current save slot
	current_save_slot = slot

	# Make sure we have valid bonfire data
	if last_bonfire_position == Vector3.ZERO or last_bonfire_id.is_empty() or last_bonfire_scene.is_empty():
		push_warning("Saving game with incomplete bonfire data. This may cause issues with respawning.")

	# Log the bonfire information being saved
	print("Saving game with bonfire data:")
	print("- Position: " + str(last_bonfire_position))
	print("- Scene: " + last_bonfire_scene)
	print("- ID: " + last_bonfire_id)

	# Get player data
	var player_data = _get_player_data()

	# Create the save data dictionary
	var save_data = {
		"version": CURRENT_SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"scene": get_tree().current_scene.scene_file_path,
		"last_bonfire_position": {
			"x": last_bonfire_position.x,
			"y": last_bonfire_position.y,
			"z": last_bonfire_position.z
		},
		"last_bonfire_scene": last_bonfire_scene,
		"last_bonfire_id": last_bonfire_id,
		"player_data": player_data
	}

	# Print player position for debugging
	if player_data.has("position"):
		print("Saving player at position: " + str(Vector3(
			player_data["position"]["x"],
			player_data["position"]["y"],
			player_data["position"]["z"]
		)))

	# Save the data to a file
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION

	# Make sure the save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var save_file = FileAccess.open(save_path, FileAccess.WRITE)

	if save_file == null:
		push_error("Failed to open save file: " + save_path)
		is_saving = false
		return false

	# Convert the save data to JSON and save it
	var json_string = JSON.stringify(save_data)
	save_file.store_line(json_string)
	print("Game saved to: " + save_path)

	# Add a small delay to simulate saving process (optional)
	await get_tree().create_timer(0.5).timeout

	is_saving = false
	save_completed.emit()
	return true

# Load a game from the specified slot
func load_game(slot: int = current_save_slot) -> bool:
	if is_loading:
		return false

	is_loading = true
	load_started.emit()

	# Set the current save slot
	current_save_slot = slot

	# Check if the save file exists
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION
	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist: " + save_path)
		is_loading = false
		return false

	# Open the save file
	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		push_error("Failed to open save file: " + save_path)
		is_loading = false
		return false

	# Parse the JSON data
	var json_string = save_file.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Failed to parse save file JSON: " + save_path)
		is_loading = false
		return false

	var save_data = json.data

	# Check save version compatibility
	if save_data.has("version") and save_data["version"] != CURRENT_SAVE_VERSION:
		push_warning("Save version mismatch. Expected " + str(CURRENT_SAVE_VERSION) + ", got " + str(save_data["version"]))
		# Handle version migration if needed

	# Store the last bonfire data
	if save_data.has("last_bonfire_position"):
		last_bonfire_position = Vector3(
			save_data["last_bonfire_position"]["x"],
			save_data["last_bonfire_position"]["y"],
			save_data["last_bonfire_position"]["z"]
		)
		print("Loaded last bonfire position: " + str(last_bonfire_position))

	if save_data.has("last_bonfire_scene"):
		last_bonfire_scene = save_data["last_bonfire_scene"]
		print("Loaded last bonfire scene: " + last_bonfire_scene)

	if save_data.has("last_bonfire_id"):
		last_bonfire_id = save_data["last_bonfire_id"]
		print("Loaded last bonfire ID: " + last_bonfire_id)

	# Store player data for use after scene load
	var player_data = save_data["player_data"]

	# Create a callback to position the player after the scene is loaded
	var apply_player_data_callback = func():
		# Wait for the scene to be fully loaded and ready
		# Use a longer initial delay to ensure the scene is fully loaded
		await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout

		print("Scene loaded, looking for player...")

		# Try to find the player with multiple attempts and increasing delays
		var player = null
		var max_attempts = 5
		var current_attempt = 1

		while player == null and current_attempt <= max_attempts:
			player = get_tree().get_first_node_in_group("player")

			if player:
				print("Player found on attempt " + str(current_attempt))
				break

			# If player not found, wait longer with each attempt
			var delay = 0.5 * current_attempt
			print("Player not found, waiting " + str(delay) + " seconds before attempt " + str(current_attempt + 1))
			await get_tree().create_timer(delay).timeout
			current_attempt += 1

		if player:
			# Apply the player data - this will position the player at their saved position
			print("Applying player data to player: " + str(player))

			# Set player position
			if player_data.has("position"):
				var player_pos = Vector3(
					player_data["position"]["x"],
					player_data["position"]["y"],
					player_data["position"]["z"]
				)
				player.global_position = player_pos
				print("Player positioned at saved location: " + str(player_pos))
			else:
				# If no player position is saved, use the last bonfire position
				player.global_position = last_bonfire_position
				print("No player position found, using last bonfire position: " + str(last_bonfire_position))

			# Set player rotation
			if player_data.has("rotation"):
				player.global_rotation.y = player_data["rotation"]
				print("Set player rotation to: " + str(player_data["rotation"]))

			# Set player health
			if player_data.has("health") and player.health_system:
				player.health_system.current_health = player_data["health"]
				player.health_system.health_updated.emit(player.health_system.current_health)
				print("Set player health to: " + str(player_data["health"]))

			# Set player stamina
			if player_data.has("stamina") and player.stamina_system:
				player.stamina_system.current_stamina = player_data["stamina"]
				player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)
				print("Set player stamina to: " + str(player_data["stamina"]))

			# Load inventory items
			if player_data.has("inventory") and player.inventory_system:
				# Clear current inventory
				player.inventory_system.inventory.clear()

				# Add saved items
				for item_data in player_data["inventory"]:
					# Find the item resource by name
					var item = player.inventory_system.find_item_by_name(item_data["name"])
					if item:
						item.count = item_data["count"]
						player.inventory_system.inventory.append(item)
						print("Added item to inventory: " + item_data["name"] + " x" + str(item_data["count"]))

				# Update current item
				if not player.inventory_system.inventory.is_empty():
					player.current_item = player.inventory_system.inventory[0]
					player.inventory_system.inventory_updated.emit(player.inventory_system.inventory)
					print("Set current item to: " + player.inventory_system.inventory[0].item_name)
		else:
			push_error("Failed to find player after " + str(max_attempts) + " attempts")

		is_loading = false
		load_completed.emit()

	# Connect to the tree_changed signal to detect when the scene is loaded
	get_tree().tree_changed.connect(apply_player_data_callback, CONNECT_ONE_SHOT)

	# Load the scene
	var target_scene = save_data["scene"]
	if target_scene != get_tree().current_scene.scene_file_path:
		# Change to the saved scene with loading screen
		print("Loading scene: " + target_scene)
		GameManager.change_scene_with_loading(target_scene)
	else:
		# If we're already in the correct scene, reload it to ensure a clean state
		print("Reloading current scene")
		get_tree().reload_current_scene()

	return true

# Check if a save exists in the specified slot
func save_exists(slot: int = current_save_slot) -> bool:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION
	return FileAccess.file_exists(save_path)

# Get save info for the specified slot (for displaying in the load menu)
func get_save_info(slot: int) -> Dictionary:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION

	if not FileAccess.file_exists(save_path):
		return {}

	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		return {}

	var json_string = save_file.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		return {}

	var save_data = json.data

	# Return a subset of the save data for display purposes
	return {
		"timestamp": save_data["timestamp"],
		"scene": save_data["scene"],
		"player_level": save_data["player_data"].get("level", 1),
		"playtime": save_data["player_data"].get("playtime", 0)
	}

# Delete a save in the specified slot
func delete_save(slot: int) -> bool:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION

	if not FileAccess.file_exists(save_path):
		return false

	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return false

	return dir.remove(save_path.get_file()) == OK

# Set the last bonfire position and scene (called when player interacts with a bonfire)
func set_last_bonfire(position: Vector3, bonfire_id: String, scene: String = "") -> void:
	# Only update if this is a different bonfire or first bonfire
	if last_bonfire_id != bonfire_id or last_bonfire_id.is_empty():
		last_bonfire_position = position
		last_bonfire_id = bonfire_id

		if scene.is_empty():
			last_bonfire_scene = get_tree().current_scene.scene_file_path
		else:
			last_bonfire_scene = scene

		print("Bonfire set: ID=" + bonfire_id + ", Scene=" + last_bonfire_scene)

# Respawn the player at the last bonfire
func respawn_at_last_bonfire() -> void:
	if last_bonfire_scene.is_empty():
		push_error("No last bonfire scene set")
		return

	print("Respawning at bonfire: ID=" + last_bonfire_id + ", Position=" + str(last_bonfire_position))

	# Store the position locally to avoid accessing freed objects
	var respawn_position = last_bonfire_position
	var respawn_scene = last_bonfire_scene

	# Create a callback to position the player after the scene is loaded
	var position_player_callback = func():
		# Wait for the scene to be fully loaded and ready
		await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout

		print("Scene loaded for respawn, looking for player...")

		# Try to find the player with multiple attempts and increasing delays
		var player = null
		var max_attempts = 5
		var current_attempt = 1

		while player == null and current_attempt <= max_attempts:
			player = get_tree().get_first_node_in_group("player")

			if player:
				print("Player found for respawn on attempt " + str(current_attempt))
				break

			# If player not found, wait longer with each attempt
			var delay = 0.5 * current_attempt
			print("Player not found for respawn, waiting " + str(delay) + " seconds before attempt " + str(current_attempt + 1))
			await get_tree().create_timer(delay).timeout
			current_attempt += 1

		if player:
			# Move player to the last bonfire position
			player.global_position = respawn_position
			print("Player respawned at position: " + str(player.global_position))

			# Reset player health and stamina
			if player.health_system:
				player.health_system.current_health = player.health_system.total_health
				player.health_system.health_updated.emit(player.health_system.current_health)
				print("Reset player health to full")

			if player.stamina_system:
				player.stamina_system.current_stamina = player.stamina_system.total_stamina
				player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)
				print("Reset player stamina to full")
		else:
			push_error("Failed to find player for respawn after " + str(max_attempts) + " attempts")

	# Connect to the tree_changed signal to detect when the scene is loaded
	get_tree().tree_changed.connect(position_player_callback, CONNECT_ONE_SHOT)

	# Always reload the scene to reset enemies and world state
	# This is what makes it work like Dark Souls - the world resets but you start at your last bonfire
	if respawn_scene != get_tree().current_scene.scene_file_path:
		# If we're in a different scene, load that scene
		print("Loading different scene: " + respawn_scene)
		GameManager.change_scene_with_loading(respawn_scene)
	else:
		# If we're in the same scene, reload it to reset enemies
		print("Reloading current scene")
		get_tree().reload_current_scene()

# Get the player data for saving
func _get_player_data() -> Dictionary:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return {}

	var player_data = {
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},
		"rotation": player.global_rotation.y,
		"health": player.health_system.current_health if player.health_system else 0,
		"stamina": player.stamina_system.current_stamina if player.stamina_system else 0,
		"inventory": []
	}

	# Save inventory items
	if player.inventory_system:
		for item in player.inventory_system.inventory:
			player_data["inventory"].append({
				"name": item.item_name,
				"count": item.count
			})

	return player_data

# Apply the loaded player data
func _apply_player_data(player_data: Dictionary) -> void:
	# This function is now a simplified version since the main player data application
	# is handled directly in the apply_player_data_callback function

	# Try to find the player with multiple attempts
	var player = null
	var max_attempts = 3
	var current_attempt = 1

	while player == null and current_attempt <= max_attempts:
		player = get_tree().get_first_node_in_group("player")

		if player:
			print("Player found in _apply_player_data on attempt " + str(current_attempt))
			break

		# If player not found, wait longer with each attempt
		var delay = 0.3 * current_attempt
		print("Player not found in _apply_player_data, waiting " + str(delay) + " seconds")
		await get_tree().create_timer(delay).timeout
		current_attempt += 1

	if not player:
		push_error("Player not found in _apply_player_data after " + str(max_attempts) + " attempts")
		return

	print("Applying player data to player: " + str(player))

	# Set player health and stamina (position is handled in the callback)
	if player_data.has("health") and player.health_system:
		player.health_system.current_health = player_data["health"]
		player.health_system.health_updated.emit(player.health_system.current_health)
		print("Set player health to: " + str(player_data["health"]))

	if player_data.has("stamina") and player.stamina_system:
		player.stamina_system.current_stamina = player_data["stamina"]
		player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)
		print("Set player stamina to: " + str(player_data["stamina"]))
