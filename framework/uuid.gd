@tool
class_name UUID
extends RefCounted

static var re: RegEx

static func _static_init() -> void:
	re = RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

static func is_valid(str: String) -> bool:
	return re.search(str) != null

static func v7() -> String:
	var unix_timestamp_ms = floori(Time.get_unix_time_from_system() * 1000.0)
	
	var timestamp_bytes = PackedByteArray()
	timestamp_bytes.resize(8)
	timestamp_bytes.encode_s64(0, unix_timestamp_ms)
	
	var bytes = Crypto.new().generate_random_bytes(16)
	for i in 6:
		bytes[i] = timestamp_bytes[5 - i]
	bytes[6] = (bytes[6] & 0b00001111) | 0b01110000
	bytes[8] = (bytes[8] & 0b00111111) | 0b10000000
	
	var str = bytes.hex_encode()
	str = str.insert(8, "-")
	str = str.insert(13, "-")
	str = str.insert(18, "-")
	str = str.insert(23, "-")
	
	return str
