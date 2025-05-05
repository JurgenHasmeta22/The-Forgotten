extends Control

@onready var save_slot_1 = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/SaveSlot1
@onready var save_slot_2 = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/SaveSlot2
@onready var save_slot_3 = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/SaveSlot3
@onready var back_button = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

func _ready():
	visible = true
	modulate.a = 1.0

	show()
	update_save_slots()
	set_initial_focus()

func update_save_slots():
	print("LoadGameMenu: Updating save slots...")

	# Check if UI elements are properly loaded
	if !is_instance_valid(save_slot_1) or !is_instance_valid(save_slot_2) or !is_instance_valid(save_slot_3):
		push_error("LoadGameMenu: UI elements not properly loaded!")
		return

	SaveManager.ensure_save_directory_exists()

	var slot1_exists = SaveManager.save_exists(1)
	print("LoadGameMenu: Save slot 1 exists: " + str(slot1_exists))
    
	if slot1_exists:
		var save_info = SaveManager.get_save_info(1)

		if save_info.is_empty():
			save_slot_1.text = "Save Slot 1 - Corrupted"
			save_slot_1.disabled = true
			print("LoadGameMenu: Save slot 1 is corrupted")
		else:
			var date_time = Time.get_datetime_string_from_unix_time(save_info.get("timestamp", 0))
			save_slot_1.text = "Save Slot 1 - " + date_time
			save_slot_1.disabled = false
			print("LoadGameMenu: Save slot 1 has timestamp: " + date_time)
	else:
		save_slot_1.text = "Save Slot 1 - Empty"
		save_slot_1.disabled = true

	var slot2_exists = SaveManager.save_exists(2)
	print("LoadGameMenu: Save slot 2 exists: " + str(slot2_exists))

	if slot2_exists:
		var save_info = SaveManager.get_save_info(2)

		if save_info.is_empty():
			save_slot_2.text = "Save Slot 2 - Corrupted"
			save_slot_2.disabled = true
			print("LoadGameMenu: Save slot 2 is corrupted")
		else:
			var date_time = Time.get_datetime_string_from_unix_time(save_info.get("timestamp", 0))
			save_slot_2.text = "Save Slot 2 - " + date_time
			save_slot_2.disabled = false
			print("LoadGameMenu: Save slot 2 has timestamp: " + date_time)
	else:
		save_slot_2.text = "Save Slot 2 - Empty"
		save_slot_2.disabled = true

	var slot3_exists = SaveManager.save_exists(3)
	print("LoadGameMenu: Save slot 3 exists: " + str(slot3_exists))

	if slot3_exists:
		var save_info = SaveManager.get_save_info(3)

		if save_info.is_empty():
			save_slot_3.text = "Save Slot 3 - Corrupted"
			save_slot_3.disabled = true
			print("LoadGameMenu: Save slot 3 is corrupted")
		else:
			var date_time = Time.get_datetime_string_from_unix_time(save_info.get("timestamp", 0))
			save_slot_3.text = "Save Slot 3 - " + date_time
			save_slot_3.disabled = false
			print("LoadGameMenu: Save slot 3 has timestamp: " + date_time)
	else:
		save_slot_3.text = "Save Slot 3 - Empty"
		save_slot_3.disabled = true

func set_initial_focus():
	if !save_slot_1.disabled:
		save_slot_1.grab_focus()
	elif !save_slot_2.disabled:
		save_slot_2.grab_focus()
	elif !save_slot_3.disabled:
		save_slot_3.grab_focus()
	else:
		back_button.grab_focus()

func _process(_delta):
	if !visible:
		visible = true
		modulate.a = 1.0
		show()

func _input(event):
	if visible:
		if event.is_action_pressed("ui_cancel"):
			_on_back_button_pressed()

func _on_save_slot_1_pressed():
	hide()

	var load_success = SaveManager.load_game(1)

	if !load_success:
		push_error("LoadGameMenu: Failed to load save from slot 1")
		GameManager.change_scene("res://ui/start_menu/start_menu.tscn")

func _on_save_slot_2_pressed():
	hide()

	var load_success = SaveManager.load_game(2)

	if !load_success:
		push_error("LoadGameMenu: Failed to load save from slot 2")
		GameManager.change_scene("res://ui/start_menu/start_menu.tscn")

func _on_save_slot_3_pressed():
	hide()

	var load_success = SaveManager.load_game(3)

	if !load_success:
		push_error("LoadGameMenu: Failed to load save from slot 3")
		GameManager.change_scene("res://ui/start_menu/start_menu.tscn")

func _on_back_button_pressed():
	hide()
	GameManager.change_scene("res://ui/start_menu/start_menu.tscn")
