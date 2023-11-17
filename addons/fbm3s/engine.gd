@tool
class_name Fbm3sEngine
extends Node

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
@export var field_size := Vector2i(6,12)
@export_range(16,128,16) var tile_size = 64
@export_group("Gameplay")
@export_subgroup("Blocks and Matching")
@export_range(4,8) var tile_kinds = 6
@export var allow_diagonal_matches := true
@export var use_soft_drop := true
@export var hard_drop_style := HardDropBehavior.HARD_DROP
@export var lockdown_style := LockTimerBehavior.GRAV_RESET
