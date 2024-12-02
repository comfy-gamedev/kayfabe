class_name TaggedMessage
extends RefCounted

var tag: StringName
var data: Variant

func _to_string() -> String:
	return str({ tag = tag, data = data })

func encode() -> PackedByteArray:
	return var_to_bytes([tag, data])

func decode(pkt: PackedByteArray, byte_offset: int = 0) -> bool:
	var msg = pkt.decode_var(byte_offset)
	if msg is not Array or msg.size() != 2:
		return false
	if msg[0] is not StringName:
		return false
	tag = msg[0]
	data = msg[1]
	return true
