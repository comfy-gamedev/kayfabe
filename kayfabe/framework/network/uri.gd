class_name URI
extends RefCounted

static var _uri_regex: RegEx

static func parse_uri(uri: String) -> Dictionary:
	if not _uri_regex:
		_uri_regex = RegEx.create_from_string("(?:(\\w+):\\/\\/)?([^#\\?]+)?(?:\\?([^#]+))?(#.*)?")
	var m = _uri_regex.search(uri)
	if not m:
		return {}
	var path = m.strings[2].split("/")
	var host = path[0].split(":")
	return {
		protocol = m.strings[1],
		hostname = host[0],
		port = host[1] if host.size() > 1 else "",
		path = "/" + "/".join(path.slice(1)),
		query = m.strings[3],
		fragment = m.strings[4],
	}
