class_name Desktop
extends Resource

@export var name: String = "Desktop"
@export var uid: String = ""

static func create() -> Desktop:
	var d = Desktop.new()
	
	Time.get_unix_time_from_system()
	
	var unix_time_bytes = PackedByteArray()
	unix_time_bytes.resize(8)
	unix_time_bytes.encode_s64(0, int(Time.get_unix_time_from_system()))
	unix_time_bytes.reverse()
	var crypto = Crypto.new()
	var uid_bytes = crypto.generate_random_bytes(8)
	var uid_str = unix_time_bytes.hex_encode() + uid_bytes.hex_encode()
	d.uid = uid_str.lstrip("0")
	
	return d
