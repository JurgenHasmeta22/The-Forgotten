extends Control

signal confirmed
signal cancelled

@onready var message_label = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var yes_button = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/YesButton
@onready var no_button = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/NoButton

var _callback_object = null
var _callback_method = ""
var _callback_binds = []

func _ready():
	# Hide the dialog initially
	hide()
	
	# Set initial focus to the No button (safer default)
	no_button.grab_focus()

func show_dialog(message: String, callback_object = null, callback_method: String = "", callback_binds: Array = []):
	# Set the message
	message_label.text = message
	
	# Store callback information
	_callback_object = callback_object
	_callback_method = callback_method
	_callback_binds = callback_binds
	
	# Show the dialog
	show()
	
	# Set focus to the No button
	no_button.grab_focus()

func _input(event):
	if visible:
		if event.is_action_pressed("ui_cancel"):
			_on_no_button_pressed()

func _on_yes_button_pressed():
	# Hide the dialog
	hide()
	
	# Emit the confirmed signal
	confirmed.emit()
	
	# Call the callback if provided
	if _callback_object != null and _callback_method != "":
		if _callback_binds.size() > 0:
			_callback_object.callv(_callback_method, _callback_binds)
		else:
			_callback_object.call(_callback_method)

func _on_no_button_pressed():
	# Hide the dialog
	hide()
	
	# Emit the cancelled signal
	cancelled.emit()
