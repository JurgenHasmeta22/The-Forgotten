extends Node

# SaveManager for The Forgotten
# Handles saving and loading game data using JSON format
# Following Godot's best practices for saving games

signal save_started
signal save_completed
signal load_started
signal load_completed
signal save_icon_shown
signal save_icon_hidden

const SAVE_DIR = "user://saves/"
const SAVE_FILE_EXTENSION = ".json"
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

	# Try to load the last used save slot from a config file
	_load_config()

	print("SaveManager initialized")

# Load configuration settings
func _load_config() -> void:
	var config_path = "user://save_config.cfg"
	if FileAccess.file_exists(config_path):
		var config = ConfigFile.new()
		var err = config.load(config_path)
		if err == OK:
			current_save_slot = config.get_value("save", "last_slot", 1)
			print("Loaded last save slot: " + str(current_save_slot))

# Save configuration settings
func _save_config() -> void:
	var config = ConfigFile.new()
	config.set_value("save", "last_slot", current_save_slot)
	config.save("user://save_config.cfg")

# Save the current game state to the specified slot
func save_game(slot: int = current_save_slot) -> bool:
	if is_saving:
		return false

	is_saving = true
	save_started.emit()
	save_icon_shown.emit()

	# Set the current save slot and save it to config
	current_save_slot = slot
	_save_config()

	# Make sure we have valid bonfire data
	if last_bonfire_position == Vector3.ZERO or last_bonfire_id.is_empty() or last_bonfire_scene.is_empty():
		push_warning("Saving game with incomplete bonfire data. This may cause issues with respawning.")

	# Log the bonfire information being saved
	print("Saving game with bonfire data:")
	print("- Position: " + str(last_bonfire_position))
	print("- Scene: " + last_bonfire_scene)
	print("- ID: " + last_bonfire_id)

	# Create the global game state dictionary
	var game_state = {
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
	}

	# Get all nodes that need to be saved
	var save_nodes = get_tree().get_nodes_in_group("Persist")
	var nodes_data = []

	# Collect data from all persistent nodes
	for node in save_nodes:
		# Check the node is an instanced scene so it can be instanced again during load
		if node.scene_file_path.is_empty():
			print("Persistent node '%s' is not an instanced scene, skipped" % node.name)
			continue

		# Check the node has a save function
		if !node.has_method("save"):
			print("Persistent node '%s' is missing a save() function, skipped" % node.name)
			continue

		# Call the node's save function
		var node_data = node.call("save")
		nodes_data.append(node_data)

	# Add nodes data to the game state
	game_state["nodes"] = nodes_data

	# Save the data to a file
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION

	# Make sure the save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var save_file = FileAccess.open(save_path, FileAccess.WRITE)

	if save_file == null:
		push_error("Failed to open save file: " + save_path)
		is_saving = false
		save_icon_hidden.emit()
		return false

	# Convert the save data to JSON and save it
	var json_string = JSON.stringify(game_state, "  ") # Pretty print with 2-space indentation
	save_file.store_line(json_string)
	print("Game saved to: " + save_path)

	# Add a small delay to simulate saving process (optional)
	await get_tree().create_timer(0.5).timeout

	is_saving = false
	save_completed.emit()
	save_icon_hidden.emit()
	return true

# Load a game from the specified slot
func load_game(slot: int = current_save_slot) -> bool:
	if is_loading:
		return false

	is_loading = true
	load_started.emit()

	# Set the current save slot and save it to config
	current_save_slot = slot
	_save_config()

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

	# Read the JSON data
	var json_string = save_file.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Failed to parse save file JSON: " + save_path)
		is_loading = false
		return false

	var game_state = json.data

	# Check the save version
	if not game_state.has("version") or game_state["version"] > CURRENT_SAVE_VERSION:
		push_error("Save file version is not compatible: " + save_path)
		is_loading = false
		return false

	# Store the last bonfire data
	if game_state.has("last_bonfire_position"):
		last_bonfire_position = Vector3(
			game_state["last_bonfire_position"]["x"],
			game_state["last_bonfire_position"]["y"],
			game_state["last_bonfire_position"]["z"]
		)
		print("Loaded last bonfire position: " + str(last_bonfire_position))

	if game_state.has("last_bonfire_scene"):
		last_bonfire_scene = game_state["last_bonfire_scene"]
		print("Loaded last bonfire scene: " + last_bonfire_scene)

	if game_state.has("last_bonfire_id"):
		last_bonfire_id = game_state["last_bonfire_id"]
		print("Loaded last bonfire ID: " + last_bonfire_id)

	# Create a callback to restore the game state after the scene is loaded
	var restore_game_state_callback = func():
		# Wait for the scene to be fully loaded and ready
		await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout

		print("Scene loaded, restoring game state...")

		# We need to remove any existing persistent nodes before adding the loaded ones
		var existing_persist_nodes = get_tree().get_nodes_in_group("Persist")
		for node in existing_persist_nodes:
			# Skip the player node - we'll handle it separately
			if node.is_in_group("player"):
				continue
			node.queue_free()

		# Wait for nodes to be removed
		await get_tree().process_frame

		# Find the player before instantiating other nodes
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# Position the player at the last bonfire
			player.global_position = last_bonfire_position
			print("Positioned player at last bonfire: " + str(last_bonfire_position))

			# Reset player health and stamina
			if player.health_system:
				player.health_system.current_health = player.health_system.total_health
				player.health_system.health_updated.emit(player.health_system.current_health)

			if player.stamina_system:
				player.stamina_system.current_stamina = player.stamina_system.total_stamina
				player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)
		else:
			push_error("Player not found after loading scene")

		# Now instantiate all saved nodes
		if game_state.has("nodes"):
			for node_data in game_state["nodes"]:
				# Skip player nodes - we already have a player in the scene
				if node_data.has("is_player") and node_data["is_player"]:
					continue

				# Try to instantiate the node
				var scene_resource = load(node_data["filename"])
				if scene_resource == null:
					push_error("Failed to load scene: " + node_data["filename"])
					continue

				var new_object = scene_resource.instantiate()
				if new_object == null:
					push_error("Failed to instantiate scene: " + node_data["filename"])
					continue

				# Try to get the parent node
				var parent_node = get_node_or_null(node_data["parent"])
				if parent_node == null:
					push_error("Failed to find parent node: " + node_data["parent"])
					new_object.queue_free()
					continue

				parent_node.add_child(new_object)

				# Set position for 2D or 3D nodes
				if new_object is Node2D:
					new_object.position = Vector2(node_data["pos_x"], node_data["pos_y"])
				elif new_object is Node3D:
					new_object.position = Vector3(node_data["pos_x"], node_data["pos_y"], node_data["pos_z"])

				# Set all the remaining properties
				for property in node_data.keys():
					if property == "filename" or property == "parent" or property == "pos_x" or property == "pos_y" or property == "pos_z":
						continue

					# Use set() to restore the property
					new_object.set(property, node_data[property])

				print("Restored node: " + new_object.name)

		is_loading = false
		load_completed.emit()

	# Connect to the tree_changed signal to detect when the scene is loaded
	get_tree().tree_changed.connect(restore_game_state_callback, CONNECT_ONE_SHOT)

	# Load the scene
	var target_scene = game_state["scene"]

	# Verify the scene path exists
	if !ResourceLoader.exists(target_scene):
		push_error("Scene file does not exist: " + target_scene)
		is_loading = false
		return false

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

	var game_state = json.data

	# Return a subset of the save data for display purposes
	var info = {
		"timestamp": game_state["timestamp"],
		"scene": game_state["scene"],
	}

	# Try to find player data in the nodes
	if game_state.has("nodes"):
		for node_data in game_state["nodes"]:
			# Look for player node
			if node_data.has("is_player") and node_data["is_player"]:
				if node_data.has("level"):
					info["player_level"] = node_data["level"]
				if node_data.has("playtime"):
					info["playtime"] = node_data["playtime"]
				break

	# Set defaults if not found
	if not info.has("player_level"):
		info["player_level"] = 1
	if not info.has("playtime"):
		info["playtime"] = 0

	return info

# Delete a save file
func delete_save(slot: int) -> bool:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION

	if not FileAccess.file_exists(save_path):
		return false

	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return false

	var err = dir.remove(save_path.get_file())
	return err == OK

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
	if last_bonfire_scene.is_empty() or last_bonfire_position == Vector3.ZERO:
		push_error("No valid bonfire data for respawn")
		return

	print("Respawning at bonfire: ID=" + last_bonfire_id + ", Position=" + str(last_bonfire_position))

	# Store the position locally to avoid accessing freed objects
	var respawn_position = last_bonfire_position
	var respawn_scene = last_bonfire_scene

	# Create a callback to position the player after the scene is loaded
	var position_player_callback = func():
		# Wait for the scene to be fully loaded and ready
		await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout

		print("Scene loaded for respawn, looking for player...")

		# Try to find the player with multiple attempts and increasing delays
		var player = null
		var max_attempts = 5
		var current_attempt = 1

		while player == null and current_attempt <= max_attempts:
			player = get_tree().get_first_node_in_group("player")

			if player:
				# Position the player at the bonfire
				player.global_position = respawn_position
				print("Player positioned at bonfire: " + str(respawn_position))

				# Reset player health and stamina
				if player.health_system:
					player.health_system.current_health = player.health_system.total_health
					player.health_system.health_updated.emit(player.health_system.current_health)

				if player.stamina_system:
					player.stamina_system.current_stamina = player.stamina_system.total_stamina
					player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

				break
			else:
				print("Player not found, attempt " + str(current_attempt) + " of " + str(max_attempts))
				current_attempt += 1
				await get_tree().create_timer(0.2 * current_attempt).timeout

		if player == null:
			push_error("Failed to find player after respawn")

		# Find all bonfires in the scene
		var bonfires = get_tree().get_nodes_in_group("interactable")
		for bonfire in bonfires:
			# Check if this is the bonfire we want to respawn at
			if bonfire.has_method("get_bonfire_id") and bonfire.get_bonfire_id() == last_bonfire_id:
				print("Found matching bonfire: " + bonfire.get_bonfire_id())
				# The bonfire is already in the scene, no need to do anything else
				break

	# Connect to the tree_changed signal to detect when the scene is loaded
	get_tree().tree_changed.connect(position_player_callback, CONNECT_ONE_SHOT)

	# Always reload the scene to reset enemies and world state
	# This is what makes it work like Dark Souls - the world resets but you start at your last bonfire

	# Verify the scene path exists
	if !ResourceLoader.exists(respawn_scene):
		push_error("Scene file does not exist: " + respawn_scene)
		# Fallback to reloading current scene
		get_tree().reload_current_scene()
		return

	if respawn_scene != get_tree().current_scene.scene_file_path:
		# If we're in a different scene, load that scene
		print("Loading different scene: " + respawn_scene)
		GameManager.change_scene_with_loading(respawn_scene)
	else:
		# If we're in the same scene, reload it to reset enemies
		print("Reloading current scene")
		get_tree().reload_current_scene()


