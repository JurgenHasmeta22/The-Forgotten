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
	print("SaveManager: Initializing...")

	# Create the saves directory if it doesn't exist
	if ensure_save_directory_exists():
		print("SaveManager: Saves directory is ready")
	else:
		push_error("SaveManager: Failed to create saves directory")

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
			# Load the last used slot
			current_save_slot = config.get_value("save", "last_slot", 1)
			print("SaveManager: Loaded last save slot: " + str(current_save_slot))

			# Load the last bonfire data
			if config.has_section("bonfire"):
				last_bonfire_position.x = config.get_value("bonfire", "position_x", 0.0)
				last_bonfire_position.y = config.get_value("bonfire", "position_y", 0.0)
				last_bonfire_position.z = config.get_value("bonfire", "position_z", 0.0)
				last_bonfire_id = config.get_value("bonfire", "id", "")
				last_bonfire_scene = config.get_value("bonfire", "scene", "")

				print("SaveManager: Loaded bonfire data from config:")
				print("  - Position: " + str(last_bonfire_position))
				print("  - ID: " + last_bonfire_id)
				print("  - Scene: " + last_bonfire_scene)
		else:
			push_error("SaveManager: Failed to load config file: " + str(err))

# Save configuration settings
func _save_config() -> void:
	var config = ConfigFile.new()

	# Save the last used slot
	config.set_value("save", "last_slot", current_save_slot)

	# Save the last bonfire data
	config.set_value("bonfire", "position_x", last_bonfire_position.x)
	config.set_value("bonfire", "position_y", last_bonfire_position.y)
	config.set_value("bonfire", "position_z", last_bonfire_position.z)
	config.set_value("bonfire", "id", last_bonfire_id)
	config.set_value("bonfire", "scene", last_bonfire_scene)

	# Save the config file
	var err = config.save("user://save_config.cfg")
	if err != OK:
		push_error("SaveManager: Failed to save config file: " + str(err))
	else:
		print("SaveManager: Config saved successfully")

# Save the current game state to the specified slot
func save_game(slot: int = current_save_slot) -> bool:
	print("SaveManager: Attempting to save game to slot " + str(slot))

	if is_saving:
		print("SaveManager: Already saving, ignoring request")
		return false

	is_saving = true
	save_started.emit()
	save_icon_shown.emit()

	# Set the current save slot and save it to config
	current_save_slot = slot
	_save_config()

	# Make sure we have valid bonfire data
	if last_bonfire_position == Vector3.ZERO or last_bonfire_id.is_empty() or last_bonfire_scene.is_empty():
		push_warning("SaveManager: Saving game with incomplete bonfire data. This may cause issues with respawning.")
		print("SaveManager: Bonfire data - Position: " + str(last_bonfire_position) + ", ID: " + last_bonfire_id + ", Scene: " + last_bonfire_scene)

		# Try to find a valid bonfire in the current scene
		var bonfires = get_tree().get_nodes_in_group("interactable")
		for bonfire in bonfires:
			if bonfire.has_method("get_bonfire_id"):
				var bonfire_id = bonfire.get_bonfire_id()
				if !bonfire_id.is_empty():
					print("SaveManager: Found valid bonfire with ID: " + bonfire_id + ", using it for save")
					last_bonfire_id = bonfire_id
					last_bonfire_position = bonfire.global_position
					last_bonfire_scene = get_tree().current_scene.scene_file_path
					_save_config()
					break

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

	# Add player data directly to ensure there's always something to save
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Create a basic player data entry
		game_state["player"] = {
			"is_player": true,
			"level": 1,
			"playtime": 0,
			"position": {
				"x": player.global_position.x,
				"y": player.global_position.y,
				"z": player.global_position.z
			},
			"scene_path": player.get_scene_file_path(),
			"parent_path": player.get_parent().get_path()
		}

		# Add health and stamina if available
		if player.health_system:
			game_state["player"]["health"] = player.health_system.current_health
			game_state["player"]["max_health"] = player.health_system.total_health

		if player.stamina_system:
			game_state["player"]["stamina"] = player.stamina_system.current_stamina
			game_state["player"]["max_stamina"] = player.stamina_system.total_stamina
	else:
		# Fallback player data if no player is found
		game_state["player"] = {
			"is_player": true,
			"level": 1,
			"playtime": 0
		}

	# Get all nodes that need to be saved
	var save_nodes = get_tree().get_nodes_in_group("Persist")
	var nodes_data = []

	print("SaveManager: Found " + str(save_nodes.size()) + " nodes in Persist group")

	# Make sure the player is in the Persist group
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		if !player_node.is_in_group("Persist"):
			print("SaveManager: Player is not in Persist group, adding it now")
			player_node.add_to_group("Persist")
			# Refresh the list of nodes to save
			save_nodes = get_tree().get_nodes_in_group("Persist")
			print("SaveManager: After adding player, found " + str(save_nodes.size()) + " nodes in Persist group")
	else:
		print("SaveManager: Player not found in scene")

	# Collect data from all persistent nodes
	for node in save_nodes:
		# Check the node is an instanced scene so it can be instanced again during load
		if node.scene_file_path.is_empty():
			print("Persistent node '%s' is not an instanced scene, skipped" % node.name)
			continue

		# Check if this is the player node
		var is_player_node = node.is_in_group("player")

		# Check the node has a save function
		if !node.has_method("save"):
			print("Persistent node '%s' is missing a save() function" % node.name)

			# If this is the player node, create a basic save data for it
			if is_player_node:
				print("SaveManager: Creating basic save data for player node")
				var basic_player_data = {
					"filename": node.get_scene_file_path(),
					"parent": node.get_parent().get_path(),
					"pos_x": node.global_position.x,
					"pos_y": node.global_position.y,
					"pos_z": node.global_position.z,
					"is_player": true
				}
				nodes_data.append(basic_player_data)
				print("SaveManager: Added basic player data")
			else:
				print("SaveManager: Node skipped")
			continue

		# Call the node's save function
		var node_data = node.call("save")
		nodes_data.append(node_data)
		print("SaveManager: Saved data for node: " + node.name)

	# Add nodes data to the game state
	game_state["nodes"] = nodes_data

	# Save the data to a file
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION

	# Make sure the save directory exists
	print("SaveManager: Ensuring save directory exists at " + SAVE_DIR)
	if not ensure_save_directory_exists():
		push_error("SaveManager: Failed to ensure save directory exists")
		is_saving = false
		save_icon_hidden.emit()
		return false

	print("SaveManager: Confirmed saves directory exists at: " + SAVE_DIR)

	print("SaveManager: Opening file for writing: " + save_path)
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)

	if save_file == null:
		var error_code = FileAccess.get_open_error()
		push_error("SaveManager: Failed to open save file: " + save_path + " - Error code: " + str(error_code))
		is_saving = false
		save_icon_hidden.emit()
		return false

	# Convert the save data to JSON and save it
	var json_string = JSON.stringify(game_state, "  ") # Pretty print with 2-space indentation
	save_file.store_line(json_string)
	save_file.flush() # Ensure data is written to disk
	save_file.close() # Explicitly close the file
	print("SaveManager: Game saved to: " + save_path)

	# Add a small delay to simulate saving process (optional)
	await get_tree().create_timer(0.5).timeout

	is_saving = false
	save_completed.emit()
	save_icon_hidden.emit()

	# Verify the save file was created
	if FileAccess.file_exists(save_path):
		print("SaveManager: Save successful! File created at: " + save_path)
		# Check if the save is now visible to the system
		print("SaveManager: save_exists(" + str(slot) + ") returns: " + str(save_exists(slot)))

		# Force refresh the start menu if we're in it
		var start_menu = get_tree().get_first_node_in_group("start_menu")
		if start_menu and start_menu.has_method("refresh_save_buttons"):
			print("SaveManager: Refreshing start menu buttons")
			start_menu.refresh_save_buttons()
	else:
		push_error("SaveManager: Save failed! File not found at: " + save_path)
		# Try to diagnose the issue
		print("SaveManager: Attempting to diagnose save failure...")
		var test_path = "user://test_save.tmp"
		var test_file = FileAccess.open(test_path, FileAccess.WRITE)
		if test_file == null:
			push_error("SaveManager: Failed to create test file at user:// - Error: " + str(FileAccess.get_open_error()))
		else:
			test_file.store_line("Test write")
			test_file.close()
			print("SaveManager: Successfully created test file at: " + test_path)

			# Try to clean up the test file
			var test_dir = DirAccess.open("user://")
			if test_dir != null:
				test_dir.remove("test_save.tmp")

	return FileAccess.file_exists(save_path)

# Load a game from the specified slot
func load_game(slot: int = current_save_slot) -> bool:
	if is_loading:
		return false

	is_loading = true
	load_started.emit()

	# Set the current save slot and save it to config
	current_save_slot = slot
	_save_config()

	# Ensure the saves directory exists
	if not ensure_save_directory_exists():
		push_error("SaveManager: Failed to ensure save directory exists")
		is_loading = false
		return false

	# Check if the save file exists
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION
	if not FileAccess.file_exists(save_path):
		push_error("SaveManager: Save file does not exist: " + save_path)
		is_loading = false
		return false

	# Open the save file
	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		push_error("SaveManager: Failed to open save file: " + save_path + " - Error: " + str(FileAccess.get_open_error()))
		is_loading = false
		return false

	# Check if the file is empty
	if save_file.get_length() == 0:
		push_error("SaveManager: Save file is empty: " + save_path)
		save_file.close()
		is_loading = false
		return false

	# Read the JSON data
	var json_string = save_file.get_line()
	save_file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("SaveManager: Failed to parse save file JSON: " + save_path + " - Error: " + str(parse_result))
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
			print("SaveManager: Positioned player at last bonfire: " + str(last_bonfire_position))

			# Reset player health and stamina
			if player.health_system:
				player.health_system.current_health = player.health_system.total_health
				player.health_system.health_updated.emit(player.health_system.current_health)

			if player.stamina_system:
				player.stamina_system.current_stamina = player.stamina_system.total_stamina
				player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

			# Find all bonfires in the scene to check if we can find the exact bonfire
			var bonfires = get_tree().get_nodes_in_group("interactable")
			var found_matching_bonfire = false

			print("SaveManager: Looking for bonfire with ID: " + last_bonfire_id)
			print("SaveManager: Found " + str(bonfires.size()) + " interactables in the scene")

			for bonfire in bonfires:
				# Check if this is the bonfire we want to respawn at
				if bonfire.has_method("get_bonfire_id"):
					var found_bonfire_id = bonfire.get_bonfire_id()
					print("SaveManager: Checking bonfire with ID: " + found_bonfire_id + " against " + last_bonfire_id)

					if found_bonfire_id == last_bonfire_id:
						print("SaveManager: Found matching bonfire: " + found_bonfire_id)
						found_matching_bonfire = true

						# Update the player position to match the exact bonfire position
						player.global_position = bonfire.global_position
						print("SaveManager: Updated player position to exact bonfire position: " + str(bonfire.global_position))

						# Activate the bonfire visually if possible
						if bonfire.has_method("activate_visually"):
							bonfire.activate_visually()
							print("SaveManager: Activated bonfire visually")

						break
				else:
					print("SaveManager: Interactable doesn't have get_bonfire_id method: " + bonfire.name)

			if !found_matching_bonfire:
				push_warning("SaveManager: Could not find matching bonfire in scene, using saved position instead")

				# As a fallback, position the player at the saved position
				player.global_position = last_bonfire_position
				print("SaveManager: Positioned player at saved position: " + str(last_bonfire_position))
		else:
			push_error("SaveManager: Player not found after loading scene")

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
	# First, ensure the saves directory exists
	ensure_save_directory_exists()

	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION
	var exists = FileAccess.file_exists(save_path)
	print("SaveManager: Checking if save exists at " + save_path + ": " + str(exists))

	return exists

# Helper function to ensure the saves directory exists
func ensure_save_directory_exists() -> bool:
	print("SaveManager: Ensuring save directory exists")

	# First check if the user:// directory is accessible
	var dir = DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: Failed to open user:// directory - Error: " + str(FileAccess.get_open_error()))
		return false

	# Check if the saves directory exists
	var dir_path = SAVE_DIR.trim_suffix("/")
	if dir.dir_exists(dir_path):
		print("SaveManager: " + dir_path + " directory already exists")
		return true

	# Create the directory if it doesn't exist
	print("SaveManager: Creating " + dir_path + " directory")
	var err = dir.make_dir(dir_path)
	if err != OK:
		push_error("SaveManager: Failed to create " + dir_path + " directory: " + str(err))
		return false

	# Verify the directory was created
	if dir.dir_exists(dir_path):
		print("SaveManager: Successfully created " + dir_path + " directory")
		return true
	else:
		push_error("SaveManager: Directory creation failed for " + dir_path)
		return false

# Get save info for the specified slot (for displaying in the load menu)
func get_save_info(slot: int) -> Dictionary:
	# First, ensure the saves directory exists
	ensure_save_directory_exists()

	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION
	print("SaveManager: Getting save info for slot " + str(slot) + " at path: " + save_path)

	if not FileAccess.file_exists(save_path):
		print("SaveManager: Save file does not exist at " + save_path)
		return {}

	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		push_error("SaveManager: Failed to open save file: " + save_path + " - Error: " + str(FileAccess.get_open_error()))
		return {}

	# Check if the file is empty
	if save_file.get_length() == 0:
		push_error("SaveManager: Save file is empty: " + save_path)
		save_file.close()
		return {}

	# Try to read the JSON data
	var json_string = ""
	# GDScript doesn't have try/except, so we'll just read the line directly
	json_string = save_file.get_line()
	save_file.close()

	# Parse the JSON data
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("SaveManager: Failed to parse save file JSON: " + save_path + " - Error: " + str(parse_result))
		# The save file might be corrupted, return default values
		return {
			"timestamp": Time.get_unix_time_from_system(),
			"scene": "res://levels/prison/prison.tscn",
			"player_level": 1,
			"playtime": 0
		}

	var game_state = json.data
	print("SaveManager: Successfully parsed save file JSON")

	# Return a subset of the save data for display purposes
	var info = {
		"timestamp": game_state.get("timestamp", 0),
		"scene": game_state.get("scene", ""),
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

	print("SaveManager: Save info - Timestamp: " + str(info.timestamp) + ", Scene: " + info.scene)
	return info

# Delete a save file
func delete_save(slot: int) -> bool:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION
	var found_file = false

	# If not found with the configured extension, check for file with no extension
	if not FileAccess.file_exists(save_path):
		var alt_path = SAVE_DIR + "slot_" + str(slot)
		if FileAccess.file_exists(alt_path):
			save_path = alt_path
			found_file = true
		# If still not found, check for file with .json extension (for backward compatibility)
		elif SAVE_FILE_EXTENSION != ".json":
			alt_path = SAVE_DIR + "slot_" + str(slot) + ".json"
			if FileAccess.file_exists(alt_path):
				save_path = alt_path
				found_file = true
	else:
		found_file = true

	if not found_file:
		return false

	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return false

	var err = dir.remove(save_path.get_file())
	return err == OK

# Set the last bonfire position and scene (called when player interacts with a bonfire)
func set_last_bonfire(position: Vector3, bonfire_id: String, scene: String = "") -> void:
	print("SaveManager: Setting last bonfire - Position: " + str(position) + ", ID: " + bonfire_id)

	# Always update the bonfire data to ensure it's correctly saved
	last_bonfire_position = position
	last_bonfire_id = bonfire_id

	if scene.is_empty():
		last_bonfire_scene = get_tree().current_scene.scene_file_path
	else:
		last_bonfire_scene = scene

	print("SaveManager: Bonfire set: ID=" + bonfire_id + ", Scene=" + last_bonfire_scene)

	# Save the config to ensure this data persists even without a full save
	_save_config()

	# Double-check that the config was saved correctly by reloading it
	_load_config()

	# Verify the data was saved correctly
	print("SaveManager: Verifying bonfire data after save:")
	print("  - Position: " + str(last_bonfire_position))
	print("  - ID: " + last_bonfire_id)
	print("  - Scene: " + last_bonfire_scene)

	# We don't trigger a save here because the spawn_site.gd will handle that
	# This prevents duplicate saves and ensures the save icon works correctly

# Respawn the player at the last bonfire
func respawn_at_last_bonfire() -> void:
	# Make sure we have the latest bonfire data from the config file
	_load_config()

	if last_bonfire_scene.is_empty() or last_bonfire_position == Vector3.ZERO or last_bonfire_id.is_empty():
		push_error("No valid bonfire data for respawn")
		return

	print("SaveManager: Respawning at bonfire: ID=" + last_bonfire_id + ", Position=" + str(last_bonfire_position) + ", Scene=" + last_bonfire_scene)

	# Debug: Print all bonfire IDs in the current scene to help diagnose issues
	var current_bonfires = get_tree().get_nodes_in_group("interactable")
	print("SaveManager: Current scene has " + str(current_bonfires.size()) + " interactables")
	for bonfire in current_bonfires:
		if bonfire.has_method("get_bonfire_id"):
			print("SaveManager: Found bonfire with ID: " + bonfire.get_bonfire_id() + " at position: " + str(bonfire.global_position))

	# Store the position locally to avoid accessing freed objects
	var respawn_position = last_bonfire_position
	var respawn_scene = last_bonfire_scene
	var respawn_bonfire_id = last_bonfire_id

	# Save the current bonfire data to ensure it persists
	print("SaveManager: Saving current bonfire data before respawn")
	_save_config()

	# Try to save the game to ensure the bonfire data is saved
	print("SaveManager: Attempting to save game before respawn")
	# We don't need to await the save_game result here since we're just ensuring the data is saved
	# and we don't want to delay the respawn process
	save_game(current_save_slot) # This will run in the background and use the current save slot
	print("SaveManager: Save initiated before respawn")

	# Create a callback to position the player after the scene is loaded
	var position_player_callback = func():
		# Wait for the scene to be fully loaded and ready
		await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout

		print("SaveManager: Scene loaded for respawn, looking for player...")

		# Try to find the player with multiple attempts and increasing delays
		var player = null
		var max_attempts = 5
		var current_attempt = 1

		while player == null and current_attempt <= max_attempts:
			player = get_tree().get_first_node_in_group("player")

			if player:
				# Position the player at the bonfire
				player.global_position = respawn_position
				print("SaveManager: Player positioned at bonfire: " + str(respawn_position))

				# Reset player health and stamina
				if player.health_system:
					player.health_system.current_health = player.health_system.total_health
					player.health_system.health_updated.emit(player.health_system.current_health)

				if player.stamina_system:
					player.stamina_system.current_stamina = player.stamina_system.total_stamina
					player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

				break
			else:
				print("SaveManager: Player not found, attempt " + str(current_attempt) + " of " + str(max_attempts))
				current_attempt += 1
				await get_tree().create_timer(0.2 * current_attempt).timeout

		if player == null:
			push_error("SaveManager: Failed to find player after respawn")

		# Find all bonfires in the scene
		var bonfires = get_tree().get_nodes_in_group("interactable")
		var found_matching_bonfire = false

		print("SaveManager: Looking for bonfire with ID: " + respawn_bonfire_id)
		print("SaveManager: Found " + str(bonfires.size()) + " interactables in the scene")

		# First, try to find the exact bonfire by ID
		for bonfire in bonfires:
			# Check if this is the bonfire we want to respawn at
			if bonfire.has_method("get_bonfire_id"):
				var found_bonfire_id = bonfire.get_bonfire_id()
				print("SaveManager: Checking bonfire with ID: " + found_bonfire_id + " against " + respawn_bonfire_id)

				if found_bonfire_id == respawn_bonfire_id:
					print("SaveManager: Found matching bonfire: " + found_bonfire_id)
					found_matching_bonfire = true

					# Update the player position to match the exact bonfire position
					player.global_position = bonfire.global_position
					print("SaveManager: Updated player position to exact bonfire position: " + str(bonfire.global_position))

					# Activate the bonfire visually if possible
					if bonfire.has_method("activate_visually"):
						bonfire.activate_visually()
						print("SaveManager: Activated bonfire visually")

					break
			else:
				print("SaveManager: Interactable doesn't have get_bonfire_id method: " + bonfire.name)

		if !found_matching_bonfire:
			push_warning("SaveManager: Could not find matching bonfire in scene, using saved position instead")

			# As a fallback, position the player at the saved position
			player.global_position = respawn_position
			print("SaveManager: Positioned player at saved position: " + str(respawn_position))

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
