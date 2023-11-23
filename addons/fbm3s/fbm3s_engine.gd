#@tool
class_name Fbm3sEngine
extends Node

## FBM3S playfield controller.
##
## Fbm3sEngine handles the primary gameplay loop of FBM3S, including placement
## of blocks, timer control, match logic, and queue handling.

## Emitted when a match is made.
signal match_made(blocks, combo)
## Emitted after a cascade which does not result in a match.
signal combo_ended()
## Emitted when topping out (blocks reached the top of the matrix.)
signal top_out()

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
enum CursorSpawnRow{
	ABOVE_TOP_ROW, ## The triad spawns above the matrix.
	ON_TOP_ROW, ## The triad spawns with its bottommost block on the first row.
}
## What defines topping out.
enum TopOutMode{
	ALL_OUTSIDE, ## Topping out occurs when no blocks in the triad can be placed inside the matrix.
					## Blocks over the matrix's top edge are deleted.
	ANY_OUTSIDE, ## Topping out occurs when any block in the triad is placed outside the matrix.
}
const DEFAULT_BLOCK_SCENE = "res://addons/fbm3s/fbm3s_block.tscn"

@export_group("Layout and Appearance")
## The size of the playfield, in tiles
@export var field_size := Vector2i(6,12)
## The texture of the blocks, in a single file
@export var tile_texture_atlas: Texture2D = preload("res://addons/fbm3s/kenney2.png")
## The size of each square tile, in pixels
@export_range(16,128,16,"suffix:px") var tile_size = 64
@export_group("Gameplay")
## The scene file for the blocks.
@export_file("*.tscn") var block_scene_path = DEFAULT_BLOCK_SCENE
## How many types of blocks in use.
@export_range(4,8) var tile_kinds = 6
## If [code]true[/code], will check for matches diagonally.
@export var allow_diagonal_matches := true
## The row where new triads spawn.
@export var triad_entry_row = CursorSpawnRow.ON_TOP_ROW
## What counts as a top out.
@export var top_out_when = TopOutMode.ANY_OUTSIDE
@export_subgroup("Sequence Generation")
## The random sequence generator to use.
@export var sequence_generator: SequenceGenerator
## How many triads are shown in the next queue.
@export_range(1,4,1,"suffix:triads") var next_queue_length = 1
@export_subgroup("Dropping and Locking")
## Whether or not soft dropping (temporarily doubling gravity while the input is held)
## is allowed.
@export var use_soft_drop := true
## The behavior of hard drops.
@export var hard_drop_style := HardDropBehavior.HARD_DROP
## How the lockdown timer behaves.
@export var lockdown_style := LockTimerBehavior.GRAV_RESET
@export_subgroup("Timers")
## Time it takes for the triad to drop down a single row from gravity.
@export_range(0.05, 1.5, 0.05, "suffix:s") var gravity_time = 0.75
## The time that the triad can still move and rotate after hitting bottom.
## Ignored if Lockdown Style is Instant Lock.
@export_range(0.05, 0.25, 0.01, "suffix:s") var lock_time = 0.1
## How long after a match until the blocks cascade and another match check is made.
## This should cover the blocks' flashing and disappearing animations.
@export_range(0.5, 5, 0.1, "suffix:s") var flash_time = 1
## The delay before a new triad spawns.
@export_range(0.05, 0.1, 0.01, "suffix:s") var interval_time = 0.1

var _block_scene
var _grav_timer = Timer.new()
var _lock_timer = Timer.new()
var _flash_timer = Timer.new()
var _interval_timer = Timer.new()
var _block_matrix = []
var _playfield: Fbm3sPlayfield = null
var _cursor_location: Vector2i
var _current_triad = []
var _next_queue = []

func _ready():
	#sanity check time!
	for n in get_children():
		if n is Fbm3sPlayfield:
			if _playfield == null:
				_playfield = n
			else:
				push_warning("Removing extraneous playfield.")
				n.queue_free()
	if _playfield == null:
		push_warning("No Playfield child. Using default.")
		_playfield = Fbm3sPlayfield.new()
		add_child(_playfield)
	_playfield.setup(field_size, tile_size)
	_block_scene = load(block_scene_path)
	var test_block_scene = _block_scene.instantiate() as Fbm3sBlock
	if test_block_scene == null:
		push_error("Fbm3sBlock PackedScene doesn't exist or is invalid. Using default.")
		_block_scene = load(DEFAULT_BLOCK_SCENE)
	else:
		test_block_scene.queue_free()
	if sequence_generator == null:
		push_warning("No SequenceGenerator defined. Using default.")
		sequence_generator = SequenceGenerator.new()
	_block_matrix = _set_up_array()
	if _block_matrix == null:
		return
	# All the dependency checks passed? Good, let's go on
	_set_up_timers()
	_reset_next_queue()

func _set_up_array():
	if field_size.x > 4 and field_size.y > 4:
		var result = []
		result.resize(field_size.x)
		var column = []
		column.resize(field_size.y)
		result.fill(column.duplicate())
		print("made empty playfield matrix of size ", field_size.x, " x ", field_size.y)
		return result
	else:
		push_error("Playfield too small, bailing out.")
		return null

func _set_up_timers():
	print("setting up timers")
	_grav_timer.connect("timeout", Callable(self, "_drop_cursor"))
	_grav_timer.one_shot = true
	_grav_timer.wait_time = gravity_time
	add_child(_grav_timer)
	
	_lock_timer.connect("timeout", Callable(self, "_lock_down"))
	_lock_timer.one_shot = true
	_lock_timer.wait_time = lock_time
	add_child(_lock_timer)
	
	_flash_timer.connect("timeout", Callable(self, "_pop_blocks"))
	_flash_timer.one_shot = true
	_flash_timer.wait_time = flash_time
	add_child(_flash_timer)
	
	_interval_timer.connect("timeout", Callable(self, "_spawn_triad"))
	_interval_timer.one_shot = true
	_interval_timer.wait_time = interval_time
	add_child(_interval_timer)

func _reset_next_queue():
	sequence_generator.kinds_count = tile_kinds
	sequence_generator.reset_sequence()
	_current_triad = sequence_generator.get_sequence(3)
	_next_queue = []
	for i in next_queue_length:
		_next_queue.push_front(sequence_generator.get_sequence(3))

func _check_for_matches():
	for i in field_size.x:
		for j in field_size.y:
			if _block_matrix[i][j] != null:
				var _not_on_horiz_edge = i > 0 && i < (field_size.x - 1)
				var _not_on_vert_edge = j > 0 && j < (field_size.y - 1)
				var current_kind = _block_matrix[i][j].kind
				if _not_on_horiz_edge:
					if _block_matrix[i-1][j] != null && _block_matrix[i+1][j] != null:
						if _block_matrix[i-1][j].kind == current_kind && _block_matrix[i+1][j].kind == current_kind:
							_block_matrix[i-1][j].add_to_group("matched")
							_block_matrix[i][j].add_to_group("matched")
							_block_matrix[i+1][j].add_to_group("matched")

				if _not_on_vert_edge:
					if _block_matrix[i][j-1] != null && _block_matrix[i][j+1] != null:
						if _block_matrix[i][j-1].kind == current_kind && _block_matrix[i][j+1].kind == current_kind:
							_block_matrix[i][j-1].add_to_group("matched")
							_block_matrix[i][j].add_to_group("matched")
							_block_matrix[i][j+1].add_to_group("matched")

				if _not_on_horiz_edge and _not_on_vert_edge and allow_diagonal_matches:
					if _block_matrix[i-1][j-1] != null && _block_matrix[i+1][j+1] != null:
						if _block_matrix[i-1][j-1].kind == current_kind && _block_matrix[i+1][j+1].kind == current_kind:
							_block_matrix[i-1][j-1].add_to_group("matched")
							_block_matrix[i][j].add_to_group("matched")
							_block_matrix[i+1][j+1].add_to_group("matched")
					if _block_matrix[i+1][j-1] != null && _block_matrix[i-1][j+1] != null:
						if _block_matrix[i+1][j-1].kind == current_kind && _block_matrix[i-1][j+1].kind == current_kind:
							_block_matrix[i+1][j-1].add_to_group("matched")
							_block_matrix[i][j].add_to_group("matched")
							_block_matrix[i-1][j+1].add_to_group("matched")
