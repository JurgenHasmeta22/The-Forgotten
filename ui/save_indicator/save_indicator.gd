extends Control

@onready var animation_player = $AnimationPlayer

func _ready():
	# Hide the indicator initially
	modulate.a = 0

	# Connect to SaveManager signals
	SaveManager.save_icon_shown.connect(_on_save_started)
	SaveManager.save_icon_hidden.connect(_on_save_completed)

func _on_save_started():
	# Show the saving animation
	animation_player.play("saving")

func _on_save_completed():
	# If the animation is still playing, let it finish naturally
	# The animation already fades out at the end
	pass
