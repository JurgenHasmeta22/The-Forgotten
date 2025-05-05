extends Node

# region "Signals, and data state"
signal save_started
signal save_completed
signal load_started
signal load_completed
signal save_icon_shown
signal save_icon_hidden
signal enemy_defeated(enemy_id)
signal door_opened(door_id)
signal last_bonfire_changed(bonfire_id, scene)

const SAVE_DIR = "user://saves/"
const MAX_SAVE_SLOTS = 3
const SAVE_FILE_EXTENSION = ".json"
const CURRENT_SAVE_VERSION = 1
const DEFAULT_SAVE_PATH = "res://data/default_save.json"

var data = {}
var current_save_slot = 1
var is_saving = false
var is_loading = false
var last_bonfire_id = ""
var last_bonfire_scene = ""
# endregion

# region "Save utils"
func get_save_path(slot: int = 0) -> String:
	if slot <= 0:
		slot = current_save_slot
	return SAVE_DIR + "save_" + str(slot) + SAVE_FILE_EXTENSION

func save_exists(slot: int = 0) -> bool:
	if slot <= 0:
		slot = current_save_slot
	return FileAccess.file_exists(get_save_path(slot))

func get_save_info(slot: int = 0) -> Dictionary:
	if !save_exists(slot):
		return {}

	var file = FileAccess.open(get_save_path(slot if slot > 0 else current_save_slot), FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	file.close()

	if content == null:
		return {}

	var info = {
		"timestamp": content.get("timestamp", 0),
		"version": content.get("version", 0),
		"last_bonfire_scene": content.get("last_bonfire_scene", ""),
		"last_bonfire_id": content.get("last_bonfire_id", "")
	}

	return info

func get_latest_save_slot() -> int:
	var latest_slot = 0
	var latest_timestamp = 0

	for slot in range(1, MAX_SAVE_SLOTS + 1):
		if save_exists(slot):
			var info = get_save_info(slot)
			var timestamp = info.get("timestamp", 0)

			if timestamp > latest_timestamp:
				latest_timestamp = timestamp
				latest_slot = slot

	return latest_slot

func ensure_save_directory_exists():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
		print("SaveManager: Created saves directory")
# endregion

# region "Save and load functions"
func save_game(slot: int = 0) -> bool:
	var player = get_tree().get_first_node_in_group("player")

	if player:
		# Update bonfire data if available
		if !last_bonfire_id.is_empty():
			data["last_bonfire_id"] = last_bonfire_id
		if !last_bonfire_scene.is_empty():
			data["last_bonfire_scene"] = last_bonfire_scene

		# Save player data
		if "player" not in data:
			data["player"] = {}

		if player.has_method("save"):
			var player_data = player.save()
			data["player"] = player_data

		# Save game state
		if "game_state" not in data:
			data["game_state"] = {
				"enemies_defeated": [], # Add logic to track defeated enemies
				"items_collected": [], # Add logic to track collected items
				"doors_opened": [] # Add logic to track opened doors
			}

		# Write the save file
		write_save(data, slot)
		print("Game saved to slot " + str(slot if slot > 0 else current_save_slot))

		return true

	return false

func save_at_bonfire():
	# Check if bonfire data is valid
	if last_bonfire_id.is_empty() or last_bonfire_scene.is_empty():
		push_error("SaveManager: Cannot save at bonfire - bonfire data is empty!")
		return false

	# Use the save_game function to save the game
	print("Game saved at bonfire: " + last_bonfire_id)
	return save_game()

func write_save(content, slot: int = 0):
	emit_signal("save_started")
	emit_signal("save_icon_shown")
	is_saving = true

	content["timestamp"] = Time.get_unix_time_from_system()
	content["version"] = CURRENT_SAVE_VERSION

	# Use the specified slot or current slot
	var save_slot = slot if slot > 0 else current_save_slot
	var save_path = get_save_path(save_slot)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(content))
	file.close()
	file = null

	# Wait a moment to show the save icon
	await get_tree().create_timer(1.0).timeout

	is_saving = false
	emit_signal("save_completed")
	emit_signal("save_icon_hidden")

func create_new_save_file(slot: int = 0):
	var save_slot = slot if slot > 0 else current_save_slot

	var file = FileAccess.open(DEFAULT_SAVE_PATH, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	file.close()

	if content == null:
		push_error("Failed to parse default save file")
		content = {
			"version": CURRENT_SAVE_VERSION,
			"timestamp": Time.get_unix_time_from_system(),
			"player": {
				"inventory": {}
			},
			"last_bonfire_id": "",
			"last_bonfire_scene": "",
			"game_state": {
				"enemies_defeated": [],
				"items_collected": [],
				"doors_opened": []
			}
		}

	content["timestamp"] = Time.get_unix_time_from_system()
	data = content
	write_save(content, save_slot)

	return content

func load_game(slot: int = 0) -> bool:
	var save_slot = slot if slot > 0 else current_save_slot

	emit_signal("load_started")
	is_loading = true

	if !save_exists(save_slot):
		push_error("No save file exists in slot " + str(save_slot))
		is_loading = false
		emit_signal("load_completed")
		return false

	var save_path = get_save_path(save_slot)
	var file = FileAccess.open(save_path, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	file.close()

	if content == null:
		push_error("Failed to parse save file: " + save_path)
		is_loading = false
		emit_signal("load_completed")
		return false

	data = content
	last_bonfire_id = content.get("last_bonfire_id", "")
	last_bonfire_scene = content.get("last_bonfire_scene", "")
	current_save_slot = save_slot
	is_loading = false
	emit_signal("load_completed")

	# Load the scene where the last bonfire is located
	if !last_bonfire_id.is_empty() and !last_bonfire_scene.is_empty():
		GameManager.change_scene_with_loading(last_bonfire_scene)
		return true
	else:
		# If no bonfire data, load the default scene
		GameManager.change_scene_with_loading("res://levels/prison/prison.tscn")
		return true

func new_game(slot: int = 0) -> bool:
	if slot <= 0:
		# Try to find an empty slot first
		for i in range(1, MAX_SAVE_SLOTS + 1):
			if !save_exists(i):
				slot = i
				break

		# If all slots are used, use slot 1 (or we could use the oldest save)
		if slot <= 0:
			slot = 1

	# Create a new save file in the specified slot
	create_new_save_file(slot)

	# Set as current slot
	current_save_slot = slot

	# Reset bonfire data
	last_bonfire_id = ""
	last_bonfire_scene = ""

	# Make sure the data is saved
	save_game(slot)

	# Start a new game in the default scene
	GameManager.change_scene_with_loading("res://levels/prison/prison.tscn")

	return true
# endregion

# region "Ready function"
func _ready():
	ensure_save_directory_exists()
# endregion

# region "Bonfire functions"
func set_last_bonfire(bonfire_id: String, scene: String = "") -> void:
	last_bonfire_id = bonfire_id

	if scene.is_empty():
		last_bonfire_scene = get_tree().current_scene.scene_file_path
	else:
		last_bonfire_scene = scene

	last_bonfire_changed.emit(last_bonfire_id, last_bonfire_scene)
# endregion

# region "Game state tracking functions"
func add_defeated_enemy(enemy_id: String) -> void:
	if "game_state" not in data:
		data["game_state"] = {
			"enemies_defeated": [],
			"items_collected": [],
			"doors_opened": []
		}

	if "enemies_defeated" not in data["game_state"]:
		data["game_state"]["enemies_defeated"] = []

	if not enemy_id in data["game_state"]["enemies_defeated"]:
		data["game_state"]["enemies_defeated"].append(enemy_id)
		enemy_defeated.emit(enemy_id)
		_silent_save()

func add_opened_door(door_id: String) -> void:
	if "game_state" not in data:
		data["game_state"] = {
			"enemies_defeated": [],
			"items_collected": [],
			"doors_opened": []
		}

	if "doors_opened" not in data["game_state"]:
		data["game_state"]["doors_opened"] = []

	if not door_id in data["game_state"]["doors_opened"]:
		data["game_state"]["doors_opened"].append(door_id)
		door_opened.emit(door_id)
		_silent_save()

func is_enemy_defeated(enemy_id: String) -> bool:
	if "game_state" not in data:
		return false

	if "enemies_defeated" not in data["game_state"]:
		return false

	return enemy_id in data["game_state"]["enemies_defeated"]

func is_door_opened(door_id: String) -> bool:
	if "game_state" not in data:
		return false

	if "doors_opened" not in data["game_state"]:
		return false

	return door_id in data["game_state"]["doors_opened"]

# Silent save function that doesn't show the save icon
func _silent_save(slot: int = 0) -> bool:
	var player = get_tree().get_first_node_in_group("player")

	if player:
		# Update bonfire data if available
		if !last_bonfire_id.is_empty():
			data["last_bonfire_id"] = last_bonfire_id
		if !last_bonfire_scene.is_empty():
			data["last_bonfire_scene"] = last_bonfire_scene

		# Save player data
		if "player" not in data:
			data["player"] = {}

		if player.has_method("save"):
			var player_data = player.save()
			data["player"] = player_data

		# Save game state
		if "game_state" not in data:
			data["game_state"] = {
				"enemies_defeated": [],
				"items_collected": [],
				"doors_opened": []
			}

		# Write the save file silently (without showing the save icon)
		_write_save_silent(data, slot)
		return true

	return false

# Write save without showing the save icon
func _write_save_silent(content, slot: int = 0):
	emit_signal("save_started")
	is_saving = true

	content["timestamp"] = Time.get_unix_time_from_system()
	content["version"] = CURRENT_SAVE_VERSION

	# Use the specified slot or current slot
	var save_slot = slot if slot > 0 else current_save_slot
	var save_path = get_save_path(save_slot)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(content))
	file.close()
	file = null

	is_saving = false
	emit_signal("save_completed")
# endregion