class_name Fbm3sGrid
extends Node2D

## FBM3S playfield controller.
##
## Fbm3sGrid handles the primary gameplay loop of a FBM3S matrix, including 
## placement of blocks, timer control, match logic, and randominzer queue handling. 
## Functions relating to scoring, input, etc. should be handled by the parent
## node of Fbm3sGrid.
##
## @tutorial: https://github.com/lunarlabs/godot-fbm3s/wiki

#region Declarations
## Emitted when a match is made.
signal match_made(blocks: int, combo: int)
## Emitted after a cascade which does not result in a match after a combo.
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
## For all options besides INSTANT_LOCK, the timer resets (or is paused if ENTRY_RESET) if the falling triad has empty space below it.
enum LockTimerBehavior {
	INSTANT_LOCK, ## The triad instantly locks when hitting bottom.
	ENTRY_RESET, ## The lock timer resets when a new triad enters the playfield.
	GRAV_RESET, ## The lock timer resets when the triad drops down a row.
	MOVE_RESET, ## The lock timer resets whenever any move is made.
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
enum Direction{
	LEFT = -1,
	RIGHT = 1
}

const ORTHOGONALS = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
const DIAGONALS = [Vector2(1,1), Vector2(1,-1), Vector2(-1,-1), Vector2(-1,1)]
#endregion

#region Exports
@export_group("Layout and Appearance")
## The size of the playfield, in tiles
@export var field_size := Vector2i(7,12)
## The texture of the blocks, in a single file
@export var appearance: Fbm3sAppearance
@export var tile_texture_atlas: Texture2D = preload("res://addons/fbm3s/kenney2.png")
@export_range(4,8) var tile_kinds = 6
## If [code]true[/code], will check for matches diagonally.
@export var allow_diagonal_matches := true
## The row where new triads spawn. See [enum CursorSpawnRow].
@export var triad_entry_row = CursorSpawnRow.ON_TOP_ROW
## What counts as a top out. See [enum TopOutMode].
@export var top_out_when = TopOutMode.ANY_OUTSIDE
@export_group("Gameplay")
@export_subgroup("Sequence Generation")
## The random sequence generator to use. 
## If empty, the default [SequenceGenerator] will be used at runtime.
@export var sequence_generator: SequenceGenerator
## How many triads are shown in the next queue.
@export_range(1,4,1,"suffix:triads") var next_queue_length = 1
@export_subgroup("Dropping and Locking")
## Whether or not soft dropping (temporarily doubling gravity while the input is held)
## is allowed.
@export var use_soft_drop := true
## The behavior of hard drops. See [enum HardDropBehavior].
@export var hard_drop_style := HardDropBehavior.HARD_DROP
## How the lockdown timer behaves. See [enum LockTimerBehavior].
@export var lockdown_style := LockTimerBehavior.GRAV_RESET
@export_subgroup("Timers")
## Time it takes for the triad to drop down a single row from gravity.
@export_range(0.05, 5, 0.05, "suffix:s") var initial_gravity_time = 0.75
## The time that the triad can still move and rotate after hitting bottom.
## Ignored if Lockdown Style is Instant Lock.
@export_range(0.05, 2, 0.01, "suffix:s") var initial_lock_time = 0.1
## How long after a match until the blocks cascade and another match check is made.
## This should cover the blocks' flashing and disappearing animations.
@export_range(0.1, 2, 0.1, "suffix:s") var initial_flash_time = 0.5
## The delay between phases.
@export_range(0.05, 0.5, 0.01, "suffix:s") var initial_interval_time = 0.07
#endregion

var cursor_location: Vector2i:
	get: return _cursor_location
	set(v):	pass
var current_triad: Array:
	get: return _current_triad
	set(v): pass
var next_queue: Array:
	get: return _next_queue
	set(v): pass
var game_active: bool:
	get: return _game_active
	set(v): pass

var _game_active := false
var _show_cursor := false
var _cursor_dropping := false
var _match_check_directions = []

#region Inner Classes
class Triad:
	enum TriadPosition {
		TOP,
		MIDDLE,
		BOTTOM,
	}
#endregion
