extends Control

@onready var progress_bar = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var tip_label = $VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/TipLabel

# Array of loading tips to display
var tips = [
	"Prepare for your journey...",
	"Stamina is crucial for combat and movement",
	"Remember to time your dodges carefully",
	"Explore thoroughly to find hidden treasures",
	"Watch your stamina when blocking attacks"
]

var target_scene = ""
var progress = 0.0
var loading_done = false

func _ready():
	# Show a random tip
	randomize()
	tip_label.text = tips[randi() % tips.size()]

	# Make sure we're visible
	show()

	# Set up progress bar
	progress_bar.value = 0

func load_scene(scene_path):
	target_scene = scene_path

	# Start the loading process
	var loader = ResourceLoader.load_threaded_request(target_scene)

	# Create a timer to check progress
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.one_shot = false
	timer.timeout.connect(_check_loading_progress)
	add_child(timer)
	timer.start()

func _check_loading_progress():
	var status = ResourceLoader.load_threaded_get_status(target_scene)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Update progress bar
		var array = []
		progress = ResourceLoader.load_threaded_get_status(target_scene, array)
		if array.size() > 0:
			progress = float(array[0])
		progress_bar.value = progress * 100

	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		progress_bar.value = 100
		loading_done = true

		# Wait a moment at 100% before changing scenes
		await get_tree().create_timer(0.5).timeout

		# Get the loaded resource
		var resource = ResourceLoader.load_threaded_get(target_scene)

		# Change to the new scene
		get_tree().change_scene_to_packed(resource)

		# Remove ourselves
		queue_free()

	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Failed to load scene: " + target_scene)

		# Go back to start menu as fallback
		get_tree().change_scene_to_file("res://ui/start_menu.tscn")
		queue_free()
