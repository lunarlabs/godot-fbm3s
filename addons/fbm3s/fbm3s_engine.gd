#@tool
class_name Fbm3sEngine
extends Node

## FBM3S playfield controller.
##
## Fbm3sEngine handles the primary gameplay loop of FBM3S, including placement
## of blocks, timer control, match logic, and queue handling.

## How hard drops behave.
enum HardDropBehavior {
	NONE, ## The hard drop mechanic is disabled.
	FIRM_DROP, ## Hard drops do not lock down instantly.
	HARD_DROP, ## Hard drops instantly lock down.
}
## How the lock timer behaves once the triad hits the bottom.
##
## For all options besides INSTANT_LOCK, the timer is paused if the falling triad has empty space below it.
enum LockTimerBehavior {
	INSTANT_LOCK, ## The triad instantly locks when hitting bottom.
	MOVE_RESET, ## The lock timer resets whenever any move is made.
	GRAV_RESET, ## The lock timer resets when the triad drops down a row.
	ENTRY_RESET, ## The lock timer resets when a new triad enters the playfield.
}
@export_group("Layout")
##The size of the playfield, in tiles
@export var field_size := Vector2i(6,12)
##The size of each square tile, in pixels
@export_range(16,128,16,"suffix:px") var tile_size = 64
@export_group("Gameplay")
@export var block_scene: PackedScene
@export_range(4,8) var tile_kinds = 6
@export var allow_diagonal_matches := true
@export_subgroup("Sequence Generation")
@export var sequence_generator: SequenceGenerator
@export_range(1,4,1,"suffix:triads") var next_queue_length = 1
@export_subgroup("Dropping and Locking")
@export var use_soft_drop := true
@export var hard_drop_style := HardDropBehavior.HARD_DROP
@export var lockdown_style := LockTimerBehavior.GRAV_RESET
@export_subgroup("Timers")
@export_range(0.05, 1.5, 0.05, "suffix:s") var gravity_time = 0.75
@export_range(0.05, 0.1, 0.01, "suffix:s") var lock_time = 0.1
@export_range(0.5, 5, 0.1, "suffix:s") var flash_time = 1

var grav_timer = Timer.new()
var lock_timer = Timer.new()
var flash_timer = Timer.new()

var _block_matrix = []
var _cursor_location: Vector2i
var _current_triad = []
var _next_queue = []

func _ready():
	#sanity check time!
	#check for playfield scene child here.
	var test_block_scene = block_scene.instantiate() as Fbm3sBlock
	if test_block_scene == null:
		push_error("Fbm3sEngine: Fbm3sBlock PackScene doesn't exist or is invalid. Bailing out.")
		return
	if sequence_generator == null:
		push_error("Fbm3sEngine: No SequenceGenerator defined. Bailing out.")
		return


func _set_up_array():
	var result = []
	for i in field_size.x:
		result.append([])
		for j in field_size.y:
			result[i].append(null)
	return result
