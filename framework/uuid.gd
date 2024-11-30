@tool
class_name UUID
extends RefCounted

static var re: RegEx

static func _static_init() -> void:
	re = RegEx.create_from_string("^(?:R-)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

static func is_valid(uuid: String) -> bool:
	return re.search(uuid) != null

const ZERO = "00000000-0000-0000-0000-000000000000"

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
	
	var hex = bytes.hex_encode()
	hex = hex.insert(8, "-")
	hex = hex.insert(13, "-")
	hex = hex.insert(18, "-")
	hex = hex.insert(23, "-")
	
	return hex
