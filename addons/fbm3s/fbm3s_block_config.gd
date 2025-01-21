class_name Fbm3sBlockConfig
extends Resource

@export var id: StringName
@export var name: String
@export_multiline var description: String
@export var kind: String
@export var matches_any: bool = false
@export var special_behavior: bool = false

func match_with (other_block: Fbm3sBlockConfig) -> bool:
    if matches_any:
        return true
    else:
        return kind == other_block.kind or other_block.matches_any