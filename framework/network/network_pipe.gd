class_name NetworkPipe
extends RefCounted

signal opened()
signal message_received(message: TaggedMessage)
signal raw_received(message: PackedByteArray)
signal closed()

enum Status {
	PENDING,
	OPEN,
	CLOSED,
}

var status: Status = Status.PENDING: set = _set_status
var pipe_id: int
var remote_peer_id: int
var remote_pipe_id: int
var was_created_remotely: bool
var stats: NetworkStats
var plumber: NetworkPlumber

func is_open() -> bool:
	return status == Status.OPEN

func send(message: TaggedMessage) -> Error:
	return plumber.pipe_send(self, message)

func send_raw(message: PackedByteArray) -> Error:
	return plumber.pipe_send_raw(self, message)

func close() -> void:
	plumber.pipe_close(self)

func _set_status(v: Status) -> void:
	if status == v: return
	status = v
	match status:
		Status.OPEN:
			opened.emit()
		Status.CLOSED:
			closed.emit()

func _recv(message: TaggedMessage) -> void:
	message_received.emit(message)

func _recv_raw(message: PackedByteArray) -> void:
	raw_received.emit(message)
