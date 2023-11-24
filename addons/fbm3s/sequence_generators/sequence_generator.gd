class_name SequenceGenerator
extends Resource
## A basic pure random sequence generator.
##
## This sequence generator does not hold a sequence or history. 
## Instead, it just generates an array of random numbers.

## How many different kinds can be generated.
var kinds_count: int = 1

## Returns a random array of numbers.
func get_sequence(length: int) -> Array[int]:
	var result: Array[int] = []
	assert(kinds_count > 0, "Don't use a non-positive kinds_count, doofus!")
	for i in length:
		result.append(randi() % kinds_count)
	return result

func reset_sequence():
	pass
