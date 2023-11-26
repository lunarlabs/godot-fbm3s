class_name Fbm3sBlock
extends Sprite2D

var kind: int

func flash():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.4)
	tween.tween_callback(queue_free)

func move_to(where: Vector2):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", where, 0.05).set_trans(Tween.TRANS_BOUNCE)
