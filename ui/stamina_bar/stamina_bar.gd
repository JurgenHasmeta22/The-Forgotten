extends TextureProgressBar
class_name StaminaBar

@export var stamina_system: StaminaSystem
@export var low_stamina_threshold: float = 25.0  # Percentage of total stamina considered "low"
@export var pulse_speed: float = 2.0  # Speed of the pulse animation when stamina is low

var tween: Tween
var is_low_stamina: bool = false
var original_tint: Color

# Called when the node enters the scene tree for the first time.
func _ready():
	if stamina_system:
		max_value = stamina_system.total_stamina
		value = stamina_system.total_stamina
		stamina_system.stamina_updated.connect(_on_stamina_updated)
		stamina_system.stamina_depleted.connect(_on_stamina_depleted)
		stamina_system.stamina_restored.connect(_on_stamina_restored)
	
	original_tint = self_modulate

func _process(_delta):
	if is_low_stamina:
		# Create a pulsing effect when stamina is low
		var pulse_value = (sin(Time.get_ticks_msec() * 0.005 * pulse_speed) + 1.0) / 2.0
		self_modulate = original_tint.lerp(Color(1, 0.3, 0.3, 1.0), pulse_value * 0.5)

func _on_stamina_updated(new_stamina):
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, "value", new_stamina, 0.2)
	
	# Check if stamina is low
	var stamina_percentage = (new_stamina / max_value) * 100
	if stamina_percentage <= low_stamina_threshold and not is_low_stamina:
		is_low_stamina = true
	elif stamina_percentage > low_stamina_threshold and is_low_stamina:
		is_low_stamina = false
		self_modulate = original_tint

func _on_stamina_depleted():
	if tween:
		tween.kill()
	
	# Flash the bar when stamina is depleted
	tween = create_tween()
	tween.tween_property(self, "self_modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(self, "self_modulate", original_tint, 0.1)
	tween.tween_property(self, "self_modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(self, "self_modulate", original_tint, 0.1)
	
	is_low_stamina = true

func _on_stamina_restored():
	is_low_stamina = false
	self_modulate = original_tint
