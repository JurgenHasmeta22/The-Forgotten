extends Node
class_name StaminaSystem

## A stamina system that manages player's stamina for actions like running, attacking, and dodging.
## When stamina is depleted, the player cannot perform stamina-consuming actions until it regenerates.

@export var total_stamina: int = 100
@onready var current_stamina = total_stamina
@export var stamina_regen_rate: float = 15.0 # Stamina points regenerated per second
@export var stamina_regen_delay: float = 1.0 # Delay before stamina starts regenerating after use

@export var sprint_cost: float = 20.0 # Stamina cost per second while sprinting
@export var attack_cost: float = 15.0 # Stamina cost per attack
@export var dodge_cost: float = 25.0 # Stamina cost per dodge
@export var block_cost: float = 5.0 # Stamina cost per second while blocking

var is_regenerating: bool = true
var regen_timer: Timer

signal stamina_updated(new_stamina)
signal stamina_depleted
signal stamina_restored

func _ready():
	regen_timer = Timer.new()
	regen_timer.one_shot = true
	regen_timer.wait_time = stamina_regen_delay
	regen_timer.timeout.connect(_on_regen_timer_timeout)
	add_child(regen_timer)

func _process(delta):
	if is_regenerating and current_stamina < total_stamina:
		regenerate_stamina(delta)

func use_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_updated.emit(current_stamina)
		
		if current_stamina <= 0:
			current_stamina = 0
			stamina_depleted.emit()
		
		is_regenerating = false
		regen_timer.start()

		return true
	else:
		return false

func regenerate_stamina(delta: float):
	var regen_amount = stamina_regen_rate * delta
	current_stamina = min(current_stamina + regen_amount, total_stamina)
	stamina_updated.emit(current_stamina)
	
	if current_stamina >= total_stamina:
		current_stamina = total_stamina
		stamina_restored.emit()

func _on_regen_timer_timeout():
	is_regenerating = true

func has_enough_stamina(amount: float) -> bool:
	return current_stamina >= amount
