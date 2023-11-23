class_name BagGenerator
extends SequenceGenerator

@export_range(1,10,4) var type_instances_per_bag

var _sequence = []

func get_sequence(length: int) -> Array[int]:
	var result: Array[int] = []
	assert(kinds_count > 0, "Don't use a non-positive kinds_count, doofus!")
	if length > 0:
		if length > _sequence.size():
			_sequence = _generate_new_bag() + _sequence
		result = _sequence.slice(-1 * length)
		_sequence.resize(_sequence.size()-length)
		return result
	else:
		push_warning("Get_sequence was called with a non-positive length argument.")
		return []
		
func _generate_new_bag():
	print("shuffling new bag")
	var result = []
	for i in kinds_count:
		var j = []
		j.resize(type_instances_per_bag)
		j.fill(i)
		result.append_array(j)
	result.shuffle()
	return result

func reset_sequence():
	_sequence = _generate_new_bag()
