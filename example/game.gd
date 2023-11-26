extends Node

@onready var engine = %Engine as Fbm3sEngine
@onready var debug_label = $Layout/RichTextLabel
var active_time: float = 0.0
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if engine.game_active:
		active_time += delta
	debug_label.text = ""
	debug_label.clear()
	debug_label.add_text("Game time: %0.3f\n" % active_time)
	debug_label.add_text("Active: %s\n" % str(engine.game_active))
	debug_label.add_text("Current triad: %s\n" % str(engine.current_triad))
	debug_label.add_text("Next queue: %s\n" % str(engine.next_queue))
	debug_label.add_text("Cursor: %s\n" % str(engine.cursor_location))
	debug_label.add_text("Grav: %0.3f\n" % engine.grav_time_left)
	debug_label.add_text("Lock: %0.3f\n" % engine.lock_time_left)
	debug_label.add_text("Flash: %0.3f\n" % engine.flash_time_left)
	debug_label.add_text("Interval: %0.3f\n" % engine.interval_time_left)
