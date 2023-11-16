@tool
class_name Fbm3sEngine
extends Node

enum HardDropBehavior {
    NONE,
    FIRM_DROP,
    HARD_DROP,
}
enum LockTimerBehavior {
    INSTANT_LOCK,
    MOVE_RESET,
    GRAV_RESET,
    ENTRY_RESET,
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