extends Control

const LobbyClient = preload("webrtc_lobby_client.gd")

var c: LobbyClient
var m: WebRTCMultiplayerPeer

var _ping_t: int

func _ready() -> void:
	c = LobbyClient.new()
	c.recv_offer.connect(_on_recv_offer)
	c.recv_answer.connect(_on_recv_answer)
	c.recv_ice_candidate.connect(_on_recv_ice_candidate)
	
	multiplayer.connected_to_server.connect(func ():
		print("[%s] Connected to server!" % [c.peer_id])
		if multiplayer.is_server():
			_spawn_player(1)
		
		if multiplayer.is_server():
			# ping loop forever
			while true:
				await get_tree().create_timer(1.0).timeout
				_ping_t = Time.get_ticks_usec()
				_ping_rpc.rpc()
	)
	
	multiplayer.connection_failed.connect(func ():
		print("[%s] connection_failed" % [c.peer_id])
	)
	
	multiplayer.peer_connected.connect(func (id: int):
		print("[%s] peer_connected (%s)" % [c.peer_id, id])
		if multiplayer.is_server():
			_spawn_player(id)
	)
	
	multiplayer.peer_disconnected.connect(func (id: int):
		print("[%s] peer_disconnected (%s)" % [c.peer_id, id])
	)
	
	multiplayer.server_disconnected.connect(func ():
		print("[%s] server_disconnected" % [c.peer_id])
	)

func _process(_delta: float) -> void:
	if c: c.poll()


func _spawn_player(id: int) -> void:
	pass # TODO

func _on_host_button_pressed() -> void:
	c.host("host1", "desktop1")
	
	m = WebRTCMultiplayerPeer.new()
	m.create_server()
	multiplayer.multiplayer_peer = m
	
	multiplayer.connected_to_server.emit()


func _on_join_button_pressed() -> void:
	c.join("host1", "desktop1")
	
	await c.client_identified
	
	(func ():
		m = WebRTCMultiplayerPeer.new()
		m.create_client(c.peer_id)
		multiplayer.multiplayer_peer = m
		
		var w = _create_peer(1)
		w.create_offer()
	).call_deferred()

func _create_peer(id: int) -> WebRTCPeerConnection:
	var w = WebRTCPeerConnection.new()
	w.session_description_created.connect(_on_session_description_created.bind(id))
	w.ice_candidate_created.connect(_on_ice_candidate_created.bind(id))
	w.data_channel_received.connect(_on_data_channel_received.bind(id))
	
	w.initialize({
		"iceServers": [
			{
				"urls": [ "stun:stun.l.google.com:19302" ],
			}
		]
	})
	
	m.add_peer(w, id)
	
	return w


func _on_recv_offer(id: int, sdp: String) -> void:
	assert(not m.has_peer(id))
	var w = _create_peer(id)
	w.set_remote_description("offer", sdp)

func _on_recv_answer(id: int, sdp: String) -> void:
	m.get_peer(id).connection.set_remote_description("answer", sdp)

func _on_recv_ice_candidate(id: int, media: String, index: int, p_name: String) -> void:
	m.get_peer(id).connection.add_ice_candidate(media, index, p_name)


func _on_session_description_created(type: String, sdp: String, id: int) -> void:
	print("[%s] _on_session_description_created(%s, %s, %s)" % [c.peer_id, type, sdp, id])
	
	m.get_peer(id).connection.set_local_description(type, sdp)
	
	match type:
		"offer":
			assert(id == 1)
			c.send_offer(id, sdp)
		"answer":
			c.send_answer(id, sdp)

func _on_ice_candidate_created(media: String, index: int, p_name: String, id: int) -> void:
	print("[%s] _on_ice_candidate_created(%s, %s, %s, %s)" % [c.peer_id, media, index, p_name, id])
	c.send_ice_candidate(id, media, index, p_name)

func _on_data_channel_received(channel: WebRTCDataChannel, id: int) -> void:
	print("[%s] _on_data_channel_received(%s, %s, %s)" % [c.peer_id, channel, id])


@rpc("authority", "call_remote", "unreliable")
func _ping_rpc() -> void:
	_pong_rpc.rpc_id(1)

@rpc("any_peer", "call_remote", "unreliable")
func _pong_rpc() -> void:
	var t = float(Time.get_ticks_usec() - _ping_t) / 1000.0
	print("[%s] ping-pong (%s): %4.3f ms" % [multiplayer.get_unique_id(), multiplayer.get_remote_sender_id(), t])
