#@tool
class_name Fbm3sEngine
extends Node

## FBM3S playfield controller.
##
## Fbm3sEngine handles the primary gameplay loop of FBM3S, including placement
## of blocks, timer control, match logic, and queue handling.

signal match_made(gems, combo)
signal combo_ended()
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
@export_group("Layout and Appearance")
##The size of the playfield, in tiles
@export var field_size := Vector2i(6,12)
##The texture of the blocks, in a single file
@export var tile_texture_atlas: Texture2D = preload("res://addons/fbm3s/kenney2.png")
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
		push_error("Fbm3sEngine: Fbm3sBlock PackedScene doesn't exist or is invalid. Bailing out.")
		return
	if sequence_generator == null:
		push_warning("Fbm3sEngine: No SequenceGenerator defined. Using default.")
		sequence_generator = SequenceGenerator.new()
	_block_matrix = _set_up_array()
	if _block_matrix == null:
		return
		
	#We all good?
	sequence_generator.kinds_count = tile_kinds
	sequence_generator.reset_sequence()

func _set_up_array():
	if field_size.x > 4 and field_size.y > 4:
		var result = []
		result.resize(field_size.x)
		var column = []
		column.resize(field_size.y)
		result.fill(column.duplicate())
		print("made empty playfield of size ", field_size.x, " x ", field_size.y)
		return result
	else:
		push_error("Playfield too small, bailing out.")
		return null

func _set_up_timers():
	grav_timer.connect("timeout", Callable(self, "_drop_cursor"))
	grav_timer.one_shot = true
	grav_timer.wait_time = gravity_time
	add_child(grav_timer)
	
	lock_timer.connect("timeout", Callable(self, "_lock_down"))
	lock_timer.one_shot = true
	lock_timer.wait_time = lock_time
	add_child(lock_timer)
	
	flash_timer.connect("timeout", Callable(self, "_pop_gems"))
	flash_timer.one_shot = true
	flash_timer.wait_time = flash_time
	add_child(flash_timer)
