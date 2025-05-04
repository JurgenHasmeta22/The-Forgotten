extends Node
class_name InventorySystem

## A Very crude and simple inventory system. This inventory is refreshed
## at each spawn, so it's not currently useable for a full game inventory.
## It's intention is to give ideas for how to work with invetory resource
## objects. But it could be adjusted to tie into a singleton based system
## or fuller inventory node, and this one would only pass out signals
## for currently equipped gear, fetching current inventory from a
## centralized system, or some other nonsense.

@export var signaling_node : Node3D
@export var change_item_signal : String = "item_change_started"
@export var use_item_signal  : String = "item_used"

@onready var inventory : Array = []
@export var starter_item : ItemResource
@export var starter_item2 : ItemResource
@onready var current_item

# All available items in the game (for loading saved games)
var all_items = []

signal item_used
signal inventory_updated(Array)

func _ready():
	if signaling_node:
		signaling_node.connect(change_item_signal,_on_change_item_signal)
		signaling_node.connect(use_item_signal, _on_item_used_signal)

	# Initialize all available items in the game
	_initialize_all_items()

	# I'm giving the player some stuff to start with, but you can see here
	# how obtaining items in game can be as simple as appendingg to the inventory array.
	starter_item.count = 3
	starter_item2.count = 3
	inventory.append(starter_item)
	inventory.append(starter_item2)

	restack_inventory()

# Initialize all available items in the game for save/load system
func _initialize_all_items():
	# Add starter items to the all_items array
	if starter_item and not all_items.has(starter_item):
		all_items.append(starter_item)

	if starter_item2 and not all_items.has(starter_item2):
		all_items.append(starter_item2)

	# Add any other items that might be available in the game
	# This could be expanded to load items from a resource directory

# Find an item by name (used for loading saved games)
func find_item_by_name(item_name: String) -> ItemResource:
	# First check the current inventory
	for item in inventory:
		if item.item_name == item_name:
			return item

	# Then check all available items
	for item in all_items:
		if item.item_name == item_name:
			# Create a duplicate of the item to avoid modifying the original
			var new_item = item.duplicate()
			return new_item

	# If item not found, return null
	return null

func _on_item_used_signal():
	if current_item.count > 0:
		item_used.emit(current_item)
		current_item.count -= 1
		inventory_updated.emit(inventory)
	else:
		item_used.emit(null)

func _on_change_item_signal():
	if inventory.size() > 0:
		change_item(0,inventory.size()-1)

func add_item(_new_item: ItemResource):
	inventory.append(_new_item)
	restack_inventory()

func change_item(_start_index,_destination_index):
	var start_item = inventory[_start_index]
	var dest_item = inventory[_destination_index]
	inventory[_start_index] = dest_item
	inventory[_destination_index] = start_item
	current_item = inventory[0]

	inventory_updated.emit(inventory)

#func remove_item(_index):
	#var former_item = inventory[_index] #store item in the current spot
	#inventory[_index] = null
	#inventory_updated.emit(inventory)
	#return former_item
	#
#func set_item(_index,_new_item: ItemResource):
	#var former_item = inventory[_index] #store item in the current spot
	#inventory[_index] = _new_item
	#inventory_updated.emit(inventory)
	#return former_item

func restack_inventory(): ## Will stack same type items.
	var inventory_refresh = []
	await get_tree().process_frame # arrays are slow, give it a frame

	for item in range(inventory.size()):
		var this_item = inventory[item]
		var found = false
		for item_check in range(inventory_refresh.size()):
			## check each item, and flag if already found in our new inventory
			## being refreshed. If it's already found, just increment the count.
			if this_item.item_name == inventory_refresh[item_check].item_name:
				this_item.count += inventory_refresh[item_check].count
				found = true

		if not found:
			inventory_refresh.append(this_item)

	inventory = inventory_refresh

	if inventory[0]:
		current_item = inventory[0]
	inventory_updated.emit(inventory)
