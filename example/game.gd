extends Node

@onready var engine = %Engine as Fbm3sEngine
@onready var debug_label = $Layout/RichTextLabel
@onready var play_button = $playButton
var active_time: float = 0.0
var max_combo = 0
var erased = 0
var is_comboing = false
var current_combo = 0
var current_combo_str = ""
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
	debug_label.add_text("Max Combo: %d\n" % max_combo)
	debug_label.add_text("Erased: %d\n" % erased)
	debug_label.add_text("%s Combo: %d (%s)\n\n" % ["Current" if is_comboing \
	  else "Last", current_combo, current_combo_str])
	debug_label.add_text("Current triad: %s\n" % str(engine.current_triad))
	debug_label.add_text("Next queue: %s\n" % str(engine.next_queue))
	debug_label.add_text("Cursor: %.v\n" % engine.cursor_location)
	debug_label.add_text("Grav: %0.3f\n" % engine.grav_time_left)
	debug_label.add_text("Lock: %0.3f\n" % engine.lock_time_left)
	debug_label.add_text("Flash: %0.3f\n" % engine.flash_time_left)
	debug_label.add_text("Interval: %0.3f" % engine.interval_time_left)


func _on_play_button_pressed():
	play_button.hide()
	active_time = 0.0
	max_combo = 0
	erased = 0
	is_comboing = false
	current_combo = 0
	current_combo_str = ""
	engine.reset_matrix()
	engine.start_game()


func _on_engine_combo_ended():
	pass # Replace with function body.


func _on_engine_match_made(blocks, combo):
	pass # Replace with function body.


func _on_engine_soft_drop_row():
	pass # Replace with function body.


func _on_engine_top_out():
	play_button.show()
