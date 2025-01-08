extends RefCounted

signal recv_text(message: String)
signal recv_binary(message: PackedByteArray)
signal connected()
signal disconnected()

const TRACE = true

var socket: WebSocketPeer

var _last_state := WebSocketPeer.STATE_CLOSED

func connect_to_url(url: String) -> Error:
	if TRACE: print_verbose("WebSocketClient: connect_to_url(%s)" % [url])
	
	var tls_options := TLSOptions.client() if OS.has_feature("web") else TLSOptions.client_unsafe()
	
	socket = WebSocketPeer.new()
	
	var err := socket.connect_to_url(url, tls_options)
	if err != OK:
		push_error("Failed to open socket: ", error_string(err))
		return err
	
	_last_state = socket.get_ready_state()
	if TRACE: print_verbose("WebSocketClient: connect_to_url(%s) -> OK" % [url])
	return OK

func close(code: int = 1000, reason: String = "") -> void:
	if TRACE: print_verbose("WebSocketClient: close(%s, %s)" % [code, reason])
	if socket:
		socket.close(1000, reason)

func send_text(message: String) -> Error:
	if TRACE: print_verbose("WebSocketClient: send_text(%s)" % [message])
	return socket.send_text(message)

func send_binary(message: PackedByteArray) -> Error:
	if TRACE: print_verbose("WebSocketClient: send_binary(%s)" % [message])
	return socket.send(message)

func poll() -> void:
	if not socket:
		return
	
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.poll()
	
	var state := socket.get_ready_state()
	
	if _last_state != state:
		if TRACE: print_verbose("WebSocketClient: state changed (%s => %s)" % [_last_state, state])
		_last_state = state
		if state == WebSocketPeer.STATE_OPEN:
			connected.emit()
		elif state == WebSocketPeer.STATE_CLOSED:
			disconnected.emit()
			socket = null
			return
	
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count() > 0:
		var pkt: PackedByteArray = socket.get_packet()
		if socket.was_string_packet():
			recv_text.emit(pkt.get_string_from_utf8())
		else:
			recv_binary.emit(pkt)
