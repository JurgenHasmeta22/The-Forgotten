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
var last_bonfire_id = ""  # Unique identifier for the last bonfire used

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
		"player_data": _get_player_data()
	}

	# Save the data to a file
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_FILE_EXTENSION
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)

	if save_file == null:
		push_error("Failed to open save file: " + save_path)
		is_saving = false
		return false

	# Convert the save data to JSON and save it
	var json_string = JSON.stringify(save_data)
	save_file.store_line(json_string)

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

	if save_data.has("last_bonfire_scene"):
		last_bonfire_scene = save_data["last_bonfire_scene"]

	if save_data.has("last_bonfire_id"):
		last_bonfire_id = save_data["last_bonfire_id"]

	# Load the scene
	var target_scene = save_data["scene"]
	if target_scene != get_tree().current_scene.scene_file_path:
		# Change to the saved scene with loading screen
		GameManager.change_scene_with_loading(target_scene)
		# Wait for the scene to load
		await get_tree().process_frame

	# Apply the player data
	_apply_player_data(save_data["player_data"])

	is_loading = false
	load_completed.emit()
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

	# If we're in a different scene, load the bonfire scene first
	if respawn_scene != get_tree().current_scene.scene_file_path:
		GameManager.change_scene_with_loading(respawn_scene)
		# Wait for the scene to load
		await get_tree().process_frame

	# Find the player and move them to the last bonfire position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Use the stored position rather than trying to access the bonfire
		player.global_position = respawn_position

		print("Player respawned at position: " + str(player.global_position))

		# Reset player health and stamina
		if player.health_system:
			player.health_system.current_health = player.health_system.total_health
			player.health_system.health_updated.emit(player.health_system.current_health)

		if player.stamina_system:
			player.stamina_system.current_stamina = player.stamina_system.total_stamina
			player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

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
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Player not found, wait for the next frame and try again
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if not player:
			push_error("Player not found in the scene")
			return

	# Set player position
	if player_data.has("position"):
		player.global_position = Vector3(
			player_data["position"]["x"],
			player_data["position"]["y"],
			player_data["position"]["z"]
		)

	# Set player rotation
	if player_data.has("rotation"):
		player.global_rotation.y = player_data["rotation"]

	# Set player health
	if player_data.has("health") and player.health_system:
		player.health_system.current_health = player_data["health"]
		player.health_system.health_updated.emit(player.health_system.current_health)

	# Set player stamina
	if player_data.has("stamina") and player.stamina_system:
		player.stamina_system.current_stamina = player_data["stamina"]
		player.stamina_system.stamina_updated.emit(player.stamina_system.current_stamina)

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

		# Update current item
		if not player.inventory_system.inventory.is_empty():
			player.current_item = player.inventory_system.inventory[0]
			player.inventory_system.inventory_updated.emit(player.inventory_system.inventory)
