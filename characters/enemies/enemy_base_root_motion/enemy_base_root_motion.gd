extends CharacterBody3D

@export var group_name :String = "targets"
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var nav_agent_3d = $NavigationAgent3D
@onready var animation_tree = $AnimationTree
@onready var anim_length = .5

@export var speed :float = 4.0
@onready var direction : Vector3 = Vector3.ZERO

@export var target_sensor : Area3D
@export var target : Node3D
## Use for pathfinding, it will return to following this default target after
## giving up a chase. Most commonly this is a pathfollow node, following a Path.
## if left blank, then the default target is simply the same locationw here this
## enemy spawns.
@export var health_system : HealthSystem

@export var default_target : Node3D
@onready var spawn_location : Marker3D = Marker3D.new()
@export var combat_range :float = 2
@onready var combat_timer : Timer = $CombatTimer
@onready var chase_timer = $ChaseTimer

@onready var hurt_cool_down = Timer.new() # while running, player can't be hurt
@export var ragdoll_death :bool = true
@onready var general_skeleton = $mannyquin/godot_rig/GeneralSkeleton

signal hurt_started
signal damage_taken
signal parried_started
signal death_started
signal attack_started
signal retreat_started

@onready var current_state = state.FREE : set = update_current_state # Enemy states controlled by enum PlayerStates
enum state {
	FREE,
	CHASE,
	COMBAT,
	ATTACK,
	DEAD
}
signal state_changed
var is_dead: bool = false


func _ready():
	# Reset death state on scene load
	is_dead = false

	# Add enemy to the Persist group for saving
	add_to_group("Persist")

	if animation_tree:
		animation_tree.animation_measured.connect(_on_animation_measured)

	hurt_cool_down.one_shot = true
	hurt_cool_down.wait_time = .4
	add_child(hurt_cool_down)

	add_to_group(group_name)
	collision_layer = 5
	if target_sensor:
		target_sensor.target_spotted.connect(_on_target_spotted)
		target_sensor.target_lost.connect(_on_target_lost)

	if health_system:
		health_system.died.connect(death)

	combat_timer.timeout.connect(_on_combat_timer_timeout)
	chase_timer.timeout.connect(_on_chase_timer_timeout)

	set_default_target()


func _process(delta):
	apply_gravity(delta)
	if current_state == state.DEAD:
		return
	rotate_character()
	navigation()
	free_movement(delta)
	evaluate_state()

func free_movement(delta):
	#set_quaternion(get_quaternion() * animation_tree.get_root_motion_rotation())
	var rate : float # imiates directional change acceleration rate
	if is_on_floor():
		rate = .5
	else:
		rate = .1
	var new_velocity = get_quaternion() * animation_tree.get_root_motion_position() / delta

	if is_on_floor():
		velocity.x = move_toward(velocity.x, new_velocity.x, rate)
		velocity.y = move_toward(velocity.y, new_velocity.y, rate)
		velocity.z = move_toward(velocity.z, new_velocity.z, rate)
	else:
		velocity.x = move_toward(velocity.x, calc_direction().x * speed, rate)
		velocity.z = move_toward(velocity.z, calc_direction().z * speed, rate)

	move_and_slide()

func calc_direction() -> Vector3 :
	var new_direction = global_transform.basis.z
	return new_direction

func update_current_state(_new_state):
	current_state = _new_state
	state_changed.emit(_new_state)

func navigation():
	if target:
		nav_agent_3d.target_position = target.global_position
		var new_dir = (nav_agent_3d.get_next_path_position() - global_position).normalized()
		new_dir *= Vector3(1,0,1) # strip the y value so enemy stays at current level
		direction = new_dir

func rotate_character():
	var rate = .2
	var new_direction = global_position.direction_to(nav_agent_3d.get_next_path_position())
	var current_rotation = global_transform.basis.get_rotation_quaternion()
	var target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, atan2(new_direction.x, new_direction.z)), rate)
	global_transform.basis = Basis(target_rotation)

func evaluate_state(): ## depending on distance to target, run or walk
	if target:
		if target == default_target:
			current_state = state.FREE
		else:
			if target:
				var current_distance = global_position.distance_to(target.global_position)
				if current_distance > combat_range:
					current_state = state.CHASE
				elif current_distance <= combat_range && current_state != state.COMBAT:
					current_state = state.COMBAT

func _on_combat_timer_timeout():
	if current_state == state.COMBAT:
		combat_randomizer()

func combat_randomizer():
	var random_choice = randi_range(1,10)
	if random_choice <= 3:
		retreat()
	else:
		attack()

func attack():
	attack_started.emit()

func retreat(): # Back away for a period of time
	retreat_started.emit()

func set_default_target(): ## Creates a node to return to after patrolling if
	## no default target is set.
	add_child(spawn_location)
	spawn_location.top_level = true
	spawn_location.global_position = to_global(Vector3(0,0,.2))
	if not default_target:
		default_target = spawn_location
	if !target:
		target = default_target

func _on_target_spotted(_spotted_target): # Updates from a TargetSensor if a target is found.
	if not is_instance_valid(self) or is_queued_for_deletion():
		return

	if target != _spotted_target:
		target = _spotted_target

	if chase_timer and is_instance_valid(chase_timer) and chase_timer.is_inside_tree():
		chase_timer.start()
	else:
		# If we can't start the timer, at least make sure we don't lose the target immediately
		print("Chase timer not available in _on_target_spotted")

func _on_target_lost():
	if is_instance_valid(target) and is_instance_valid(self) and not is_queued_for_deletion():
		if chase_timer and is_instance_valid(chase_timer) and chase_timer.is_inside_tree():
			chase_timer.start()
		else:
			# If chase_timer is not valid, just call give_up directly after a delay
			await get_tree().create_timer(3.0).timeout
			if is_instance_valid(self) and not is_queued_for_deletion():
				give_up()

func _on_chase_timer_timeout():
	give_up()

func give_up():
	await get_tree().create_timer(2).timeout
	target = default_target

func apply_gravity(_delta):
	if !is_on_floor():
		velocity.y -= gravity * _delta
		move_and_slide()

func hit(_by_who, _by_what):
	target = _by_who
	if hurt_cool_down.is_stopped():
		hurt_cool_down.start()
		hurt_started.emit()
		damage_taken.emit(_by_what)

func parried():
	if hurt_cool_down.is_stopped():
		hurt_cool_down.start()
		parried_started.emit()

func death():
	if is_dead:
		return  # Prevent death function from running multiple times

	# Set dead state immediately
	is_dead = true
	current_state = state.DEAD

	# Disable physics processing and collision
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0

	# Remove from targets group
	remove_from_group(group_name)

	# Apply death effects
	if ragdoll_death:
		apply_ragdoll()
	else:
		death_started.emit()
		# Freeze the character in place
		velocity = Vector3.ZERO

	# Use a one-shot timer to queue_free
	var free_timer = Timer.new()
	free_timer.one_shot = true
	free_timer.wait_time = 4.0
	free_timer.timeout.connect(func(): queue_free())
	add_child(free_timer)
	free_timer.start()


func apply_ragdoll():
	# Disable animation tree and enable ragdoll physics
	general_skeleton.physical_bones_start_simulation()
	animation_tree.active = false

	# Don't stop the ragdoll simulation - let it stay in ragdoll state until it's freed

func _on_animation_measured(_new_length):
	anim_length = _new_length - .05 # offset slightly for the process frame

# Helper method to check if a variable exists
func has_variable(var_name: String) -> bool:
	return var_name in self

# Save method to be called by the SaveManager
func save():
	var save_dict = {
		"filename": scene_file_path,
		"parent": get_parent().get_path(),

		# Health
		"health": health_system.current_health if health_system else 0,
		"max_health": health_system.total_health if health_system else 0,

		# Enemy state
		"is_alive": !is_dead,
		"aggro_state": current_state,
	}

	# Add target ID if target is valid
	if is_instance_valid(target) and target.is_in_group("player"):
		save_dict["has_player_target"] = true
	else:
		save_dict["has_player_target"] = false

	# Add other properties
	save_dict["enemy_type"] = group_name
	save_dict["level"] = 1  # Replace with actual enemy level if you have one

	return save_dict
