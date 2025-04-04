class_name DesktopMultiplayer
extends MultiplayerAPIExtension

const WebRTCLobbyClient = preload("webrtc_lobby_client.gd")

const TRACE = true
const KEY_PATH = "user://server_certificate_private.key"
const CRT_PATH = "user://server_certificate_public.crt"
const PORT = 8675

var scene_multiplayer = SceneMultiplayer.new()
var peer: WebRTCMultiplayerPeer

var server_url: String

var _lobby_server: WebRTCLobbyClient

var _player_infos: Dictionary # { [peer_id: int]: PlayerInfo }
var _server_info: ServerInfo

func _init() -> void:
	scene_multiplayer.connected_to_server.connect(WeakCallable.make_weak(_on_connected_to_server))
	scene_multiplayer.connection_failed.connect(WeakCallable.make_weak(_on_connection_failed))
	scene_multiplayer.peer_connected.connect(WeakCallable.make_weak(_on_peer_connected))
	scene_multiplayer.peer_disconnected.connect(WeakCallable.make_weak(_on_peer_disconnected))
	scene_multiplayer.server_disconnected.connect(WeakCallable.make_weak(_on_server_disconnected))
	scene_multiplayer.peer_authenticating.connect(WeakCallable.make_weak(_on_peer_authenticating))
	scene_multiplayer.peer_authentication_failed.connect(WeakCallable.make_weak(_on_peer_authentication_failed))
	scene_multiplayer.peer_packet.connect(WeakCallable.make_weak(_on_peer_packet))
	
	scene_multiplayer.auth_callback = WeakCallable.make_weak(_auth_callback)
	
	_lobby_server = WebRTCLobbyClient.new()
	_lobby_server.recv_offer.connect(WeakCallable.make_weak(_on_lobby_server_recv_offer))
	_lobby_server.recv_answer.connect(WeakCallable.make_weak(_on_lobby_server_recv_answer))
	_lobby_server.recv_ice_candidate.connect(WeakCallable.make_weak(_on_lobby_server_recv_ice_candidate))

func _poll() -> Error:
	_lobby_server.poll()
	return scene_multiplayer.poll()

func _rpc(peer: int, object: Object, method: StringName, args: Array) -> Error:
	#if TRACE: print_verbose("DesktopMultiplayer._rpc(%s, %s, %s, %s)" % [peer, object, method, args])
	return scene_multiplayer.rpc(peer, object, method, args)

func _set_multiplayer_peer(p_peer: MultiplayerPeer) -> void:
	scene_multiplayer.multiplayer_peer = p_peer

func _get_multiplayer_peer() -> MultiplayerPeer:
	return scene_multiplayer.multiplayer_peer

func _get_unique_id() -> int:
	return scene_multiplayer.get_unique_id()

func _get_peer_ids() -> PackedInt32Array:
	return scene_multiplayer.get_peers()

func _get_remote_sender_id() -> int:
	return scene_multiplayer.get_remote_sender_id()

func _object_configuration_add(object: Object, config: Variant) -> Error:
	if TRACE: print_verbose("DesktopMultiplayer._object_configuration_add(%s, %s)" % [object, config])
	if object == null:
		return scene_multiplayer.object_configuration_add(object, config)
	elif object is MultiplayerSynchronizer:
		return scene_multiplayer.object_configuration_add(object, config)
	elif object is MultiplayerSpawner:
		return scene_multiplayer.object_configuration_add(object, config)
	else:
		push_error("Not implemented")
		return ERR_BUG

func _object_configuration_remove(object: Object, config: Variant) -> Error:
	if TRACE: print_verbose("DesktopMultiplayer._object_configuration_remove(%s, %s)" % [object, config])
	if object == null:
		return scene_multiplayer.object_configuration_add(object, config)
	elif object is MultiplayerSynchronizer:
		return scene_multiplayer.object_configuration_remove(object, config)
	elif object is MultiplayerSpawner:
		return scene_multiplayer.object_configuration_remove(object, config)
	else:
		push_error("Not implemented")
		return ERR_BUG


func start_server() -> Error:
	if TRACE: print_verbose("DesktopMultiplayer.start_server()")
	
	var x = ProjectSettings.has_setting("kayfabe/networking/lobby_server_host")
	var lobby_server_host: String = ProjectSettings.get_setting_with_override("kayfabe/networking/lobby_server_host")
	var lobby_server_use_tls: bool = ProjectSettings.get_setting_with_override("kayfabe/networking/lobby_server_use_tls")
	var host_uuid: String = PlayerProfileManager.profile.id
	var desktop_uuid: String = Desktop.current.uuid
	
	var err = _lobby_server.host(lobby_server_host, lobby_server_use_tls, host_uuid, desktop_uuid)
	if err != OK:
		if TRACE: print_verbose("DesktopMultiplayer.start_server(): Error %s" % [error_string(err)])
		return err
	
	peer = WebRTCMultiplayerPeer.new()
	err = peer.create_server()
	if err != OK:
		if TRACE: print_verbose("DesktopMultiplayer.start_server(): Error %s" % [error_string(err)])
		return err
	
	server_url = _lobby_server.get_join_url(lobby_server_host, lobby_server_use_tls, host_uuid, desktop_uuid)
	
	multiplayer_peer = peer
	connected_to_server.emit()
	return OK

func start_client_async(url: String) -> Error:
	if TRACE: print_verbose("DesktopMultiplayer.start_client(%s)" % [url])
	
	var err: Error = _lobby_server.join(url)
	if err != OK:
		if TRACE: print_verbose("DesktopMultiplayer.start_server(): Error %s" % [error_string(err)])
		return err
	
	if TRACE: print_verbose("DesktopMultiplayer.start_server(): CLIENT AWAITING IDENTIFICATION" % [])
	await _lobby_server.client_identified
	if TRACE: print_verbose("DesktopMultiplayer.start_server(): CLIENT IDENTIFIED" % [])
	
	peer = WebRTCMultiplayerPeer.new()
	err = peer.create_client(_lobby_server.peer_id)
	if err != OK:
		if TRACE: print_verbose("DesktopMultiplayer.start_client(%s): Error %s" % [url, error_string(err)])
		return err
	
	server_url = url
	
	var w = _create_webrtc_peer_connection(1)
	w.create_offer()
	
	multiplayer_peer = peer
	return OK

func shutdown() -> void:
	if multiplayer_peer.get_connection_status() != MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED:
		multiplayer_peer.close()


func get_player_info(peer_id: int) -> PlayerInfo:
	return _player_infos.get(peer_id)

func get_server_info() -> ServerInfo:
	return _server_info

func _on_connected_to_server() -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_connected_to_server()")
	connected_to_server.emit()

func _on_connection_failed() -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_connection_failed()")
	connection_failed.emit()

func _on_peer_connected(id: int) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_peer_connected(%s)" % [id])
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_peer_disconnected(%s)" % [id])
	peer_disconnected.emit(id)

func _on_server_disconnected() -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_server_disconnected()")
	server_disconnected.emit()

func _on_peer_authenticating(id: int) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_peer_authenticating(%s)" % [id])
	
	if not is_server():
		var player_info = {
			player_id = PlayerProfileManager.profile.id,
			player_name = PlayerProfileManager.profile.name,
		}
		if TRACE: print_verbose("DesktopMultiplayer._on_peer_authenticating(%s): Sending Client auth." % [id])
		scene_multiplayer.send_auth(id, var_to_bytes(player_info))

func _on_peer_authentication_failed(id: int) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_peer_authentication_failed(%s)" % [id])
	pass

func _on_peer_packet(id: int, packet: PackedByteArray) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_peer_packet(%s, <%s bytes>)" % [id, packet.size()])
	pass

func _auth_callback(id: int, data: PackedByteArray) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._auth_callback(%s, <%s bytes>)" % [id, data.size()])
	
	if is_server():
		var auth = bytes_to_var(data)
		if TRACE: print_verbose("\tDesktopMultiplayer._auth_callback: Server received auth = %s" % [auth])
		
		if auth is not Dictionary \
			or "player_id" not in auth or auth.player_id is not StringName \
			or auth.player_id == StringName() \
			or "player_name" not in auth or auth.player_name is not String \
			or auth.player_name == "":
				scene_multiplayer.disconnect_peer(id)
				return
		
		var player_info = PlayerInfo.new()
		player_info.id = auth.player_id
		player_info.name = auth.player_name
		
		_player_infos[id] = player_info
		
		var server_info = {
			packed_desktop_metadata = JsonResource.pack(Desktop.current.filesystem.metadata),
		}
		scene_multiplayer.send_auth(id, var_to_bytes(server_info))
		scene_multiplayer.complete_auth(id)
	else:
		var auth = bytes_to_var(data)
		if TRACE: print_verbose("\tDesktopMultiplayer._auth_callback: auth = %s" % [auth])
		
		if auth is not Dictionary \
			or "packed_desktop_metadata" not in auth or auth.packed_desktop_metadata is not Dictionary:
				scene_multiplayer.disconnect_peer(id)
				return
		
		_server_info = ServerInfo.new()
		_server_info.packed_desktop_metadata = auth.packed_desktop_metadata
		
		scene_multiplayer.complete_auth(id)

#region WebRTC

func _on_lobby_server_recv_offer(id: int, sdp: String) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_lobby_server_recv_offer(%s, %s)" % [id, sdp])
	if peer.has_peer(id):
		return
	var conn = _create_webrtc_peer_connection(id)
	conn.set_remote_description("offer", sdp)
	peer.add_peer(conn, id)

func _on_lobby_server_recv_answer(id: int, sdp: String) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_lobby_server_recv_answer(%s, %s)" % [id, sdp])
	if peer.has_peer(id):
		peer.get_peer(id).connection.set_remote_description("answer", sdp)

func _on_lobby_server_recv_ice_candidate(id: int, media: String, index: int, name: String) -> void:
	if TRACE: print_verbose("DesktopMultiplayer._on_lobby_server_recv_ice_candidate(%s, %s, %s, %s)" % [id, media, index, name])
	if peer.has_peer(id):
		peer.get_peer(id).connection.add_ice_candidate(media, index, name)

func _create_webrtc_peer_connection(id: int) -> WebRTCPeerConnection:
	var conn = WebRTCPeerConnection.new()
	conn.session_description_created.connect(_on_connection_session_description_created.bind(id))
	conn.ice_candidate_created.connect(_on_connection_ice_candidate_created.bind(id))
	
	var stun_servers := Array(ProjectSettings.get_setting_with_override("kayfabe/networking/webrtc_stun_servers"))
	stun_servers = stun_servers.map(func (s): return "stun:" + s)
	
	conn.initialize({
		"iceServers": [
			{
				"urls": stun_servers,
			}
		]
	})
	
	peer.add_peer(conn, id)
	
	return conn

func _on_connection_session_description_created(type: String, sdp: String, id: int) -> void:
	if peer.has_peer(id):
		peer.get_peer(id).connection.set_local_description(type, sdp)
	
	match type:
		"offer":
			_lobby_server.send_offer(id, sdp)
		"answer":
			_lobby_server.send_answer(id, sdp)

func _on_connection_ice_candidate_created(media: String, index: int, name: String, id: int) -> void:
	_lobby_server.send_ice_candidate(id, media, index, name)

#endregion WebRTC

class PlayerInfo:
	var id: StringName
	var name: String


class ServerInfo:
	var packed_desktop_metadata: Dictionary
