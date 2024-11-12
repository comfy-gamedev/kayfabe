@tool
class_name ObjectJSON
extends RefCounted

const SCRIPT_PROPERTY = &"script"

static func stringify(obj: Object, indent: String = "") -> String:
	var packed = {}
	for p in obj.get_property_list():
		if p.name == SCRIPT_PROPERTY:
			continue
		if not p.usage & PROPERTY_USAGE_STORAGE:
			continue
		packed[p.name] = obj[p.name]
	return JSON.stringify(packed, indent)

static func parse(str: String, type: Object) -> Object:
	if type is not Script and type.get_class() != "GDScriptNativeClass":
		push_error("Invalid parse type")
		return null
	var packed = JSON.parse_string(str)
	if packed == null:
		return null
	var obj = type.new()
	for p in obj.get_property_list():
		if p.name == SCRIPT_PROPERTY:
			continue
		if not p.usage & PROPERTY_USAGE_STORAGE:
			continue
		if p.name not in packed:
			continue
		obj[p.name] = packed[p.name]
	return obj

static func stringify_to_file(obj: Object, path: String) -> Error:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	var str = stringify(obj, "\t")
	file.store_string(str)
	return OK

static func parse_from_file(path: String, type: Object) -> Object:
	var str = FileAccess.get_file_as_string(path)
	if not str:
		var err = FileAccess.get_open_error()
		if err != OK:
			push_error("Failed to open file %s: %s" % [path, error_string(err)])
		else:
			push_error("File is empty: ", path)
		return null
	return parse(str, type)
