class_name Fbm3sEngine
extends Node

## FBM3S playfield controller.
##
## Fbm3sEngine handles the primary gameplay loop of a FBM3S matrix, including 
## placement of blocks, timer control, match logic, and randominzer queue handling. 
## Functions relating to scoring, input, etc. should be handled by the parent
## node of Fbm3sEngine.
##
## @tutorial: https://github.com/lunarlabs/godot-fbm3s/wiki

## Emitted when the triad goes down a row when soft drop is on.
signal soft_drop_row()
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
## The path to the built-in block packed scene.
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
## The row where new triads spawn. See [enum CursorSpawnRow].
@export var triad_entry_row = CursorSpawnRow.ON_TOP_ROW
## What counts as a top out. See [enum TopOutMode].
@export var top_out_when = TopOutMode.ANY_OUTSIDE
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

var cursor_location: Vector2i:
	get: return _cursor_location
	set(v):	pass
var current_triad: Array:
	get: return _current_triad
	set(v): pass
var next_queue: Array:
	get: return _next_queue
	set(v): pass
var gravity_time: float:
	get: return _normal_grav_time
	set(v):
		_normal_grav_time = v
		_soft_drop_grav_time = v/2
var lock_time: float:
	get: return _lock_timer.wait_time
	set(v): _lock_timer.wait_time = v
var interval_time: float:
	get: return _interval_timer.wait_time
	set(v): _interval_timer.wait_time = v
var flash_time: float
var grav_time_left: float:
	get: return _grav_timer.time_left
	set(v): pass
var lock_time_left: float:
	get: return _lock_timer.time_left
	set(v): pass
var flash_time_left: float:
	get: return _flash_timer.time_left
	set(v): pass
var interval_time_left: float:
	get: return _interval_timer.time_left
	set(v): pass
var game_active: bool:
	get: return _game_active
	set(v): pass

var _game_active := false
var _block_scene: PackedScene
var _grav_timer = Timer.new()
var _lock_timer = Timer.new()
var _flash_timer = Timer.new()
var _interval_timer = Timer.new()
var _normal_grav_time: float
var _soft_drop_grav_time: float
var _block_matrix = []
var _playfield: Fbm3sPlayfield = null
var _cursor_location: Vector2i
var _cursor := Cursor.new(tile_size, self)
var _ghost := Cursor.new(tile_size, self)
var _current_triad = []
var _next_queue = []
var _is_soft_dropping := false
var _before_triad_entry: Callable
var _before_match_check: Callable
var _before_flash: Callable
var _combo: int = 0

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
	add_child(_ghost)
	add_child(_cursor)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ghost.modulate = Color(0.75, 0.75, 0.75, 0.5)
	_cursor.modulate = Color(1.25, 1.25, 1.25)
	_create_timers()

## Gets an [AtlasTexture] representing the block with the kind [param which].
func get_block_texture(which: int) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = tile_texture_atlas
	result.region = Rect2(which * tile_size, 0, tile_size, tile_size)
	return result

func slide_cursor(what_dir: Direction) -> bool:
	if _cursor_location.x + what_dir in range(field_size.x) and _cursor.visible == true:
		if _block_matrix[_cursor_location.x + what_dir][_cursor_location.y] == null\
		  or _cursor_location.y < 0:
			_cursor_location.x += what_dir
			if _is_space_below():
				if _grav_timer.is_stopped():
					_grav_timer.start()
				if not (_lock_timer.is_stopped() or _lock_timer.paused):
					if lockdown_style == LockTimerBehavior.ENTRY_RESET:
						_lock_timer.paused = true
					else:
						_lock_timer.stop()
			_update_cursor()
			return true
	return false

func rotate_triad_down():
	if _cursor.visible == true:
		_current_triad.push_front(_current_triad.pop_back())
		if not _is_space_below() and lockdown_style == LockTimerBehavior.MOVE_RESET:
			_lock_timer.start()
		_update_cursor()

func rotate_triad_up():
	if _cursor.visible == true:
		_current_triad.push_back(_current_triad.pop_front())
		if not _is_space_below() and lockdown_style == LockTimerBehavior.MOVE_RESET:
			_lock_timer.start()
		_update_cursor()

func start_soft_drop():
	if use_soft_drop and _cursor.visible == true:
		if _is_space_below():
			_is_soft_dropping = true
			_drop_cursor()
			if _is_space_below():
				_grav_timer.start(_soft_drop_grav_time)
		else:
			_lock_down()

func stop_soft_drop():
	if _is_soft_dropping == true and use_soft_drop and _cursor.visible == true:
		_is_soft_dropping = false
		if _is_space_below():
			var reset_time = min(_soft_drop_grav_time, _grav_timer.time_left)
			_grav_timer.start(reset_time * 2.0)

## Performs a hard drop, moving the triad to the ground instantly.
## The behavior of the triad depends on [member hard_drop_style].
##
## Returns the number of rows dropped.
func hard_drop() -> int:
	if hard_drop_style == HardDropBehavior.NONE or not _cursor.visible:
		return 0
	else:
		_grav_timer.stop()
		var occupied = _get_occupancy_array(_cursor_location.x)
		var lowest = occupied.find(true)
		var target = lowest - 1 if (lowest >= 0) else field_size.y - 1
		var result = target - _cursor_location.y
		_cursor_location.y = target
		_update_cursor()
		match hard_drop_style:
			HardDropBehavior.FIRM_DROP:
				_activate_lockdown_timer()
			HardDropBehavior.HARD_DROP:
				_lock_down()
		return result

func start_game():
	_game_active = true
	_reset_next_queue()
	_spawn_triad()

func reset_matrix(reset_queue := false):
	_block_matrix = _set_up_array()
	get_tree().call_group("blocks", "queue_free")
	if reset_queue:
		_reset_next_queue()

func sanity_check():
	if _game_active:
		var block_list = get_tree().get_nodes_in_group("blocks").duplicate()
		# we want an array of all blocks that are referenced in _block_matrix
		var board_list = []
		for arr in _block_matrix:
			board_list.append_array(arr)
		# remove empty spaces...
		board_list = board_list.filter(func(node): return node != null)
		for block in block_list:
			if block not in board_list:
				# It's a "zombie" block, so get rid of it.
				block.queue_free()
		_cascade_blocks()

func skip_interval():
	if _interval_timer.time_left > 0:
		_interval_timer.stop()
		_spawn_triad()

func is_valid_coordinate(where: Vector2i) -> bool:
	return where < field_size and where > Vector2i(0,0)

# TODO: Why the hell is this causing transient frame rate spikes???
func put_block_at(which: int, where: Vector2i, clobber := false) -> bool:
	print("attempting putting ", which, " at ", where)
	if is_valid_coordinate(where):
		if _block_matrix[where.x][where.y] == null:
			var new_block = _block_scene.instantiate() as Fbm3sBlock
			_block_matrix[where.x][where.y] = new_block
			new_block.kind = which
			new_block.texture = get_block_texture(which)
			_playfield.add_child(new_block)
			new_block.position = _playfield.tile_to_pixel(where)
			new_block.add_to_group("blocks")
			return true
		elif clobber:
			_block_matrix[where.x][where.y].texture = get_block_texture(which)
			_block_matrix[where.x][where.y].kind = which
			return true
		else:
			push_warning("Space is occupied:", where)
			return false
	else:
		return false
			

func _set_up_array():
	if field_size.x > 4 and field_size.y > 4:
		var result = []
		#result.resize(field_size.x)
		var column = []
		column.resize(field_size.y)
		# silly me, thought Array.fill() would make a new duplicate at each column
		# no, they were all pointing at the same damn column!
		# no wonder the horizontal match check kept returning true!
		#result.fill(column.duplicate())
		for i in field_size.x:
			result.append(column.duplicate())
		print("made empty playfield matrix of size ", field_size.x, " x ", field_size.y)
		return result
	else:
		push_error("Playfield too small, bailing out.")
		return null

func _create_timers():
	print("setting up timers")
	_normal_grav_time = initial_gravity_time
	_soft_drop_grav_time = initial_gravity_time / 2
	_grav_timer.connect("timeout", Callable(self, "_drop_cursor"))
	_grav_timer.one_shot = true
	_grav_timer.wait_time = initial_gravity_time
	add_child(_grav_timer)
	
	_lock_timer.connect("timeout", Callable(self, "_lock_down"))
	_lock_timer.one_shot = true
	_lock_timer.wait_time = initial_lock_time
	add_child(_lock_timer)
	
	_interval_timer.connect("timeout", Callable(self, "_spawn_triad"))
	_interval_timer.one_shot = true
	_interval_timer.wait_time = initial_interval_time
	add_child(_interval_timer)
	
	flash_time = initial_flash_time

func _reset_next_queue():
	sequence_generator.kinds_count = tile_kinds
	sequence_generator.reset_sequence()
	_current_triad = sequence_generator.get_sequence(3)
	_next_queue = []
	for i in next_queue_length:
		_next_queue.push_front(sequence_generator.get_sequence(3))

func _spawn_triad():
	_lock_timer.stop()
	_combo = 0
	var middle = floor(field_size.x / 2.0)
	if _block_matrix[middle][0] == null:
		if _before_triad_entry.is_valid():
			_before_triad_entry.call()
		_cursor_location.y = -1 if triad_entry_row == CursorSpawnRow.ABOVE_TOP_ROW \
		  else 0
		_cursor_location.x = middle
		_update_cursor()
		_cursor.show()
		_ghost.show()
		if _cursor_location.y + 1 < field_size.y \
		  and _block_matrix[_cursor_location.x][_cursor_location.y + 1] == null:
			_grav_timer.start()
		elif lockdown_style != LockTimerBehavior.INSTANT_LOCK:
			_activate_lockdown_timer()
		else:
			_lock_down()
	else:
		_top_out()

func _advance_triad():
	_current_triad = _next_queue.pop_back()
	_next_queue.push_front(sequence_generator.get_sequence(3))

func _update_cursor():
	_cursor.update(_current_triad, _playfield.tile_to_pixel(_cursor_location))
	_ghost.update(_current_triad, _playfield.tile_to_pixel(Vector2i(\
	  _cursor_location.x, _get_ground(_cursor_location.x))))

func _is_space_below() -> bool:
	if _cursor_location.y < field_size.y - 1:
		return _block_matrix[_cursor_location.x][_cursor_location.y+1] == null
	else:
		return false

func _drop_cursor():
	if _is_space_below():
		_cursor_location.y += 1
		_update_cursor()
		match lockdown_style:
			LockTimerBehavior.ENTRY_RESET:
				_lock_timer.paused = true
			LockTimerBehavior.GRAV_RESET, LockTimerBehavior.MOVE_RESET:
				_lock_timer.stop()
		if _is_space_below():
			if _is_soft_dropping:
				soft_drop_row.emit()
				_grav_timer.start(_soft_drop_grav_time)
			else:
				_grav_timer.start(_normal_grav_time)
		elif lockdown_style != LockTimerBehavior.INSTANT_LOCK:
			_activate_lockdown_timer()
		else:
			_lock_down()
	else:
		_lock_down()

func _activate_lockdown_timer():
	_grav_timer.stop()
	match lockdown_style:
		LockTimerBehavior.INSTANT_LOCK:
			_lock_down()
		LockTimerBehavior.ENTRY_RESET:
			if not _lock_timer.is_stopped():
				if _lock_timer.paused:
					_lock_timer.paused = false
				else:
					print("_activate_lockdown_timer called when _lock_timer running!")
			else:
				# Okay, so start() *doesn't* unpause a Timer. Aaaaarrgh...
				_lock_timer.paused = false
				_lock_timer.start()
		_:
			_lock_timer.start()

func _lock_down():
	if _cursor.visible:
		_is_soft_dropping = false
		_grav_timer.stop()
		_lock_timer.stop()
		_cursor.hide()
		_ghost.hide()
		if _cursor_location.y >= 0:
			var all_placed = true
			for i in _current_triad.size():
				var loc = _cursor_location
				loc.y -= i
				all_placed = all_placed and put_block_at(_current_triad[-i-1],loc)
			if top_out_when == TopOutMode.ANY_OUTSIDE and not all_placed:
				print("This should only appear when the top out mode is ANY")
				_top_out()
			else:
				if _before_match_check.is_valid():
					_before_match_check.call()
				_combo_check()
		else:
			_top_out()

func _combo_check():
	var matches = _check_for_matches()
	while not matches.is_empty():
		_combo += 1
		match_made.emit(matches.size(), _combo)
		if _before_flash.is_valid():
			_before_flash.call()
		get_tree().call_group("matched", "flash")
		await get_tree().create_timer(flash_time).timeout
		#if the block flash doesn't include queue_free, this will clean em up
		get_tree().call_group("matched", "queue_free")
		#and if these blocks are still awaiting "freedom," let's pop em off the matrix:
		for i in matches:
			_block_matrix[i.x][i.y] = null
		_cascade_blocks()
		matches = _check_for_matches()
	if _combo > 0:
		combo_ended.emit()
	_advance_triad()
	_interval_timer.start()

func _get_ground(col: int) -> int:
	var occupied = _get_occupancy_array(col)
	var lowest = occupied.find(true)
	return lowest - 1 if (lowest >= 0) else field_size.y - 1

func _get_occupancy_array(col: int) -> Array[bool]:
	var occupied: Array[bool] = []
	occupied.resize(field_size.y)
	occupied.fill(false)
	for row in field_size.y:
		occupied[row] = false if _block_matrix[col][row] == null else true
	return occupied

func _check_for_matches() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in field_size.x:
		for j in field_size.y:
			if _block_matrix[i][j] != null:
				var current_kind = _block_matrix[i][j].kind
				#check horizontally
				if i in range(1, field_size.x - 1):
					_check_and_mark_match(Vector2i(i - 1, j), \
					  Vector2i(i, j), Vector2i(i + 1, j), current_kind, result)
				#check vertically
				if j in range(1, field_size.y - 1):
					_check_and_mark_match(Vector2i(i, j - 1), \
					  Vector2i(i, j), Vector2i(i, j + 1), current_kind, result)

				if allow_diagonal_matches and i in range(1, field_size.x - 1) \
				  and j in range(1, field_size.y - 1):
					_check_and_mark_match(Vector2i(i - 1, j - 1), \
					  Vector2i(i, j), Vector2i(i + 1, j + 1), current_kind, result)
					_check_and_mark_match(Vector2i(i + 1, j - 1), \
					  Vector2i(i, j), Vector2i(i - 1, j + 1), current_kind, result)

	return result

func _check_and_mark_match(a: Vector2i, b:Vector2i, c:Vector2i, to_match, list):
	if _block_matrix[a.x][a.y] != null and _block_matrix[c.x][c.y] != null:
		if _block_matrix[a.x][a.y].kind == to_match and _block_matrix[c.x][c.y].kind == to_match:
			print("match: ", a, b, c, to_match)
			_mark_matched(a, list)
			_mark_matched(b, list)
			_mark_matched(c, list)

func _mark_matched(loc: Vector2i, list: Array[Vector2i]):
	_block_matrix[loc.x][loc.y].add_to_group("matched")
	if loc not in list:
		print("adding to flash list: ", loc)
		list.append(loc)

func _cascade_blocks():
	for col in field_size.x:
		var lowest_space = -1
		var block_bottom = -1
		var block_top = -1
		var move_made = true
		var occupied = _get_occupancy_array(col)
		while move_made:
			move_made = false
			lowest_space = occupied.rfind(false)
			block_bottom = occupied.rfind(true, lowest_space)
			if block_bottom >= 0:
				var to_move = lowest_space - block_bottom
				move_made = true
				block_top=(occupied.rfind(false, block_bottom))
				for i in range(block_bottom, block_top, -1):
					_block_matrix[col][i+to_move] = _block_matrix[col][i]
					_block_matrix[col][i] = null
				occupied = _get_occupancy_array(col)
		for row in field_size.y:
			if _block_matrix[col][row] != null:
				_block_matrix[col][row].move_to(_playfield.tile_to_pixel(Vector2(col, row)))

func _top_out():
	print("topped out!")
	_grav_timer.stop()
	_lock_timer.stop()
	_interval_timer.stop()
	_game_active = false
	top_out.emit()

class Cursor extends Node2D:
	var top_sprite = Sprite2D.new()
	var mid_sprite = Sprite2D.new()
	var bottom_sprite = Sprite2D.new()
	var engine: Node
	var tile_size: int
	
	func _init(ts: int, eng: Node):
		tile_size = ts
		engine = eng
		top_sprite.centered = false
		mid_sprite.centered = false
		bottom_sprite.centered = false
		add_child(top_sprite)
		add_child(mid_sprite)
		add_child(bottom_sprite)
		mid_sprite.position = Vector2i(0, -1 * tile_size)
		top_sprite.position = Vector2i(0, -2 * tile_size)
		visible = false
	
	func update(triad, move_to: Vector2):
		top_sprite.texture = engine.get_block_texture(triad[0])
		mid_sprite.texture = engine.get_block_texture(triad[1])
		bottom_sprite.texture = engine.get_block_texture(triad[2])
		position = move_to
