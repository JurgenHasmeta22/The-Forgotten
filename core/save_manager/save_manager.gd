extends Node

# region "Signals, and data state"
signal save_started
signal save_completed
signal load_started
signal load_completed
signal save_icon_shown
signal save_icon_hidden

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

	# Return only basic info to avoid loading the entire save
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

	# Check all save slots
	for slot in range(1, MAX_SAVE_SLOTS + 1):
		if save_exists(slot):
			var info = get_save_info(slot)
			var timestamp = info.get("timestamp", 0)

			# If this save is newer than our current latest
			if timestamp > latest_timestamp:
				latest_timestamp = timestamp
				latest_slot = slot

	# If no saves found, return 0
	return latest_slot

func ensure_save_directory_exists():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
		print("SaveManager: Created saves directory")
# endregion

# region "Read and write save files"
func save_at_bonfire():
	var player = get_tree().get_first_node_in_group("player")

	if player:
		if last_bonfire_id.is_empty() or last_bonfire_scene.is_empty():
			push_error("SaveManager: Cannot save at bonfire - bonfire data is empty!")
			return false

		data["last_bonfire_id"] = last_bonfire_id
		data["last_bonfire_scene"] = last_bonfire_scene

		if "player" not in data:
			data["player"] = {}

		if player.has_method("save"):
			var player_data = player.save()
			data["player"] = player_data

		data["game_state"] = {
			"enemies_defeated": [], # Add logic to track defeated enemies
			"items_collected": [], # Add logic to track collected items
			"doors_opened": [] # Add logic to track opened doors
		}

		write_save(data)
		print("Game saved at bonfire: " + last_bonfire_id)

		return true

	return false

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
				"health": 100,
				"max_health": 100,
				"stamina": 100,
				"max_stamina": 100,
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

	# Update timestamp to current time
	content["timestamp"] = Time.get_unix_time_from_system()

	# Set as current data
	data = content

	# Save to file
	write_save(content, save_slot)

	return content
# endregion

# region "Load game, new game, ready"
func _ready():
	ensure_save_directory_exists()

	# We don't need to load any save data on startup
	# The start menu will handle loading the appropriate save

func load_game(slot: int = 0) -> bool:
	var save_slot = slot if slot > 0 else current_save_slot

	emit_signal("load_started")
	is_loading = true

	if !save_exists(save_slot):
		push_error("No save file exists in slot " + str(save_slot))
		is_loading = false
		emit_signal("load_completed")
		return false

	# Load the save data
	var save_path = get_save_path(save_slot)
	var file = FileAccess.open(save_path, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	file.close()

	if content == null:
		push_error("Failed to parse save file: " + save_path)
		is_loading = false
		emit_signal("load_completed")
		return false

	# Update current data
	data = content

	# Update bonfire data
	last_bonfire_id = content.get("last_bonfire_id", "")
	last_bonfire_scene = content.get("last_bonfire_scene", "")

	# Set the current save slot
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

	# Start a new game in the default scene
	GameManager.change_scene_with_loading("res://levels/prison/prison.tscn")

	return true
# endregion

# region "Bonfire functions"
func set_last_bonfire(bonfire_id: String, scene: String = "") -> void:
	last_bonfire_id = bonfire_id

	if scene.is_empty():
		last_bonfire_scene = get_tree().current_scene.scene_file_path
	else:
		last_bonfire_scene = scene
# endregion