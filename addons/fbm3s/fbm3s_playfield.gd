class_name Fbm3sPlayfield
extends Node2D

## A simple playfield generator. Handles locations and draws a simple checkerboard.

var _origin: Vector2
var _playfield_size: Vector2i
var _tile_size
var _checkerboard_drawable = false

#this is just for testing, comment it out afterwards
#func _ready():
#	setup(Vector2i(6,12),64)
#	queue_redraw()

func _draw():
	if _checkerboard_drawable:
		var paint: Color
		var area: Rect2
		var size = Vector2(_tile_size, _tile_size)
		var start: Vector2
		for i in _playfield_size.x:
			for j in _playfield_size.y:
				paint = Color.WHITE if (i % 2) ^ (j % 2) else Color.BLACK
				start = _origin + Vector2(i * _tile_size, j * _tile_size)
				area = Rect2(start, size)
				draw_rect(area, paint)

func setup(playfield_size: Vector2i, tile_size):
	print("setting up basic playfield")
	_playfield_size = playfield_size
	_tile_size = tile_size
	_origin = get_viewport_rect().size/2 - (Vector2(_playfield_size) * tile_size)/2
	_checkerboard_drawable = true
	queue_redraw()

func get_origin():
	return _origin

func tile_to_pixel(where: Vector2i):
	return _origin + (where * _tile_size)
	
