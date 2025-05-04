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

func _ready():
	# Hide the loading screen initially
	hide()

	# Show a random tip
	randomize()
	tip_label.text = tips[randi() % tips.size()]

func load_scene(scene_path):
	show()
	target_scene = scene_path
	progress = 0.0
	progress_bar.value = 0.0

	# Create a ResourceLoader to load the scene in the background
	var loader = ResourceLoader.load_threaded_request(target_scene)

	# Start a timer to check the loading progress
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.one_shot = false
	timer.timeout.connect(_check_loading_progress.bind(loader))
	add_child(timer)
	timer.start()

func _check_loading_progress(loader):
	var status = ResourceLoader.load_threaded_get_status(target_scene)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Still loading, update the progress bar
		progress = ResourceLoader.load_threaded_get_status(target_scene, [])
		progress_bar.value = progress

	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		# Loading complete, get the loaded resource
		var resource = ResourceLoader.load_threaded_get(target_scene)

		# Instance the loaded scene
		var new_scene = resource.instantiate()

		# Add it to the tree
		get_tree().root.add_child(new_scene)

		# Set it as the current scene
		get_tree().current_scene = new_scene

		# Remove the old scene (which is the parent of this loading screen)
		var old_scene = get_parent()
		old_scene.queue_free()

		# Hide the loading screen
		hide()

		# Update the GameManager's current_scene reference
		GameManager.current_scene = new_scene

	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		# Loading failed
		push_error("Failed to load scene: " + target_scene)

		# Hide the loading screen
		hide()
