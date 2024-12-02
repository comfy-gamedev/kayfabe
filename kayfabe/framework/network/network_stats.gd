class_name NetworkStats
extends RefCounted

var total_up: int
var total_down: int

var pipe_up: int
var pipe_down: int

var transfer_up: int
var transfer_down: int

func clear() -> void:
	total_up = 0
	total_down = 0
	pipe_up = 0
	pipe_down = 0
	transfer_up = 0
	transfer_down = 0

func duplicate() -> NetworkStats:
	var dup := NetworkStats.new()
	dup.total_up = total_up
	dup.total_down = total_down
	dup.pipe_up = pipe_up
	dup.pipe_down = pipe_down
	dup.transfer_up = transfer_up
	dup.transfer_down = transfer_down
	return dup
