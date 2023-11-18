class_name SequenceGenerator
extends Resource

var kinds_count: int = 1

func get_sequence(length: int) -> Array[int]:
	var result = []
	assert(kinds_count > 0, "Don't use a non-positive kinds_count, doofus!")
	for i in length:
		result.append(randi() % kinds_count)
	return result
