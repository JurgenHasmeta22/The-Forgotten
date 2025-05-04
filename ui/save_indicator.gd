extends Control

@onready var animation_player = $AnimationPlayer

func _ready():
	# Hide the indicator initially
	modulate.a = 0
	
	# Connect to SaveSystem signals
	SaveSystem.save_started.connect(_on_save_started)
	SaveSystem.save_completed.connect(_on_save_completed)

func _on_save_started():
	# Show the saving animation
	animation_player.play("saving")

func _on_save_completed():
	# If the animation is still playing, let it finish naturally
	# The animation already fades out at the end
	pass
