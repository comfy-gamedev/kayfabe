class_name DesktopMultiplayer
extends MultiplayerAPIExtension

const TRACE = true
const KEY_PATH = "user://server_certificate_private.key"
const CRT_PATH = "user://server_certificate_public.crt"
const PORT = 8675

var scene_multiplayer = SceneMultiplayer.new()

var server_url: String

var certificate_key: CryptoKey
var certificate: X509Certificate

var _player_infos: Dictionary[int, PlayerInfo]
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

func _poll() -> Error:
	return scene_multiplayer.poll()

func _rpc(peer: int, object: Object, method: StringName, args: Array) -> Error:
	if TRACE: print_verbose("DesktopMultiplayer._rpc(%s, %s, %s, %s)" % [peer, object, method, args])
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
	_load_certificate()
	var peer = WebSocketMultiplayerPeer.new()
	var tls_options = TLSOptions.server(certificate_key, certificate)
	var err = peer.create_server(PORT, "*", tls_options)
	if err != OK:
		if TRACE: print_verbose("DesktopMultiplayer.start_server(): Error %s" % [error_string(err)])
		return err
	server_url = "wss://localhost:%s/" % [PORT]
	multiplayer_peer = peer
	connected_to_server.emit()
	return OK

func start_client(url: String) -> Error:
	if TRACE: print_verbose("DesktopMultiplayer.start_client(%s)" % [url])
	var peer = WebSocketMultiplayerPeer.new()
	var tls_options = TLSOptions.client_unsafe()
	var err = peer.create_client(url, tls_options)
	if err != OK:
		if TRACE: print_verbose("DesktopMultiplayer.start_client(%s): Error %s" % [url, error_string(err)])
		return err
	server_url = url
	multiplayer_peer = peer
	return OK

func shutdown() -> void:
	if multiplayer_peer.get_connection_status() != MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED:
		multiplayer_peer.close()


func get_player_info(peer_id: int) -> PlayerInfo:
	return _player_infos.get(peer_id)

func get_server_info() -> ServerInfo:
	return _server_info

func _load_certificate() -> void:
	if certificate and certificate_key:
		return
	
	if not FileAccess.file_exists(KEY_PATH) or not FileAccess.file_exists(CRT_PATH):
		if FileAccess.file_exists(KEY_PATH):
			var i = 1
			var bak = KEY_PATH + ".bak" + str(i)
			while FileAccess.file_exists(bak):
				i += 1
				bak = KEY_PATH + ".bak" + str(i)
			DirAccess.rename_absolute(KEY_PATH, bak)
		if FileAccess.file_exists(CRT_PATH):
			var i = 1
			var bak = CRT_PATH + ".bak" + str(i)
			while FileAccess.file_exists(bak):
				i += 1
				bak = CRT_PATH + ".bak" + str(i)
			DirAccess.rename_absolute(CRT_PATH, bak)
		
		var crypto = Crypto.new()
		certificate_key = crypto.generate_rsa(4096)
		certificate = crypto.generate_self_signed_certificate(certificate_key, "CN=self-signed.kayfabe.cloud,O=Kayfabe,C=US")
		
		certificate_key.save(KEY_PATH)
		certificate.save(CRT_PATH)
	else:
		certificate_key = CryptoKey.new()
		certificate_key.load(KEY_PATH)
		certificate = X509Certificate.new()
		certificate.load(CRT_PATH)

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


class PlayerInfo:
	var id: StringName
	var name: String


class ServerInfo:
	var packed_desktop_metadata: Dictionary
