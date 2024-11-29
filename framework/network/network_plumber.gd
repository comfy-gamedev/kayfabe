class_name NetworkPlumber
extends Node

const CHANNEL = 1

var _peers: Dictionary # { [peer_id: int]: PlumberPeer }
var _next_pipe_id: int = 1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta: float) -> void:
	for peer_id in _peers:
		var peer := _peers[peer_id] as PlumberPeer
		
		var to_close: Array[NetworkPipe] = []
		
		for pipe_id in peer.pipes:
			var pipe: NetworkPipe = peer.get_pipe(pipe_id)
			
			# A refcount of 2 here implies two things:
			# 1. The pipe was created locally (remote pipes have an extra ref).
			# 2. The pipe is no longer held by user code (only this plumber).
			# Therefore, we close the pipe.
			# This may not always be desirable, but it is better than the
			# alternative in which pipes may never be closed.
			if pipe.get_reference_count() <= 2:
				to_close.append(pipe)
		
		for p in to_close:
			pipe_close(p)

func pipe_create(peer_id: int) -> NetworkPipe:
	if peer_id not in _peers:
		push_error("Invalid peer_id.")
		return null
	var peer := _peers[peer_id] as PlumberPeer
	var pipe := NetworkPipe.new()
	pipe.plumber = self
	pipe.pipe_id = _next_pipe_id
	pipe.remote_peer_id = peer_id
	_next_pipe_id += 1
	peer.add_pipe(pipe)
	_pipe_create_rpc.rpc_id(peer_id, pipe.pipe_id)
	return pipe

func pipe_get(peer_id: int, pipe_id: int) -> NetworkPipe:
	if peer_id not in _peers:
		push_error("Invalid peer_id.")
		return null
	var peer := _peers[peer_id] as PlumberPeer
	var pipe: NetworkPipe = peer.get_pipe(pipe_id)
	if not pipe:
		push_error("Invalid pipe id: ", pipe_id)
	return pipe

func pipe_close(pipe: NetworkPipe) -> void:
	if pipe.status == NetworkPipe.Status.CLOSED:
		return
	if pipe.remote_peer_id not in _peers:
		push_error("Invalid peer_id.")
		return
	var peer := _peers[pipe.remote_peer_id] as PlumberPeer
	peer.remove_pipe(pipe)
	pipe.status = NetworkPipe.Status.CLOSED
	_pipe_close_rpc.rpc_id(pipe.remote_peer_id, pipe.remote_pipe_id)

func pipe_send(pipe: NetworkPipe, message: TaggedMessage) -> Error:
	if pipe.status != NetworkPipe.Status.OPEN:
		push_error("Cannot send to pending or closed pipe.")
		return ERR_CONNECTION_ERROR
	assert(pipe.remote_peer_id in _peers)
	assert(_peers[pipe.remote_peer_id].get_pipe(pipe.pipe_id) == pipe)
	var message_packet := message.encode()
	#pipe.stats.total_up += message_packet.size()
	#pipe.stats.pipe_up += message_packet.size()
	_pipe_send_rpc.rpc_id(pipe.remote_peer_id, pipe.remote_pipe_id, message_packet)
	return OK

func pipe_send_raw(pipe: NetworkPipe, message: PackedByteArray) -> Error:
	if pipe.status != NetworkPipe.Status.OPEN:
		push_error("Cannot send to pending or closed pipe.")
		return ERR_CONNECTION_ERROR
	assert(pipe.remote_peer_id in _peers)
	assert(_peers[pipe.remote_peer_id].get_pipe(pipe.pipe_id) == pipe)
	#pipe.stats.total_up += message.size()
	#pipe.stats.pipe_up += message.size()
	_pipe_send_raw_rpc.rpc_id(pipe.remote_peer_id, pipe.remote_pipe_id, message)
	return OK

func _on_peer_connected(id: int) -> void:
	_peers[id] = PlumberPeer.new()

func _on_peer_disconnected(id: int) -> void:
	var peer := _peers.get(id) as PlumberPeer
	if not peer:
		return
	for pipe_id in peer.pipes:
		var pipe: NetworkPipe = peer.get_pipe(pipe_id)
		pipe.status = NetworkPipe.Status.CLOSED
	_peers.erase(id)

func _on_server_disconnected() -> void:
	for id in _peers:
		_on_peer_disconnected(id)
	_peers.clear()

@rpc("any_peer", "call_remote", "reliable", CHANNEL)
func _pipe_create_rpc(remote_pipe_id: int):
	var sender := multiplayer.get_remote_sender_id()
	if sender not in _peers:
		return
	var peer := _peers[sender] as PlumberPeer
	var pipe := NetworkPipe.new()
	pipe.plumber = self
	pipe.pipe_id = _next_pipe_id
	pipe.remote_peer_id = sender
	pipe.remote_pipe_id = remote_pipe_id
	pipe.was_created_remotely = true
	pipe.status = NetworkPipe.Status.OPEN
	_next_pipe_id += 1
	peer.add_pipe(pipe)
	_pipe_create_ack_rpc.rpc_id(sender, remote_pipe_id, pipe.pipe_id)

@rpc("any_peer", "call_remote", "reliable", CHANNEL)
func _pipe_create_ack_rpc(pipe_id: int, remote_pipe_id: int):
	var sender := multiplayer.get_remote_sender_id()
	if sender not in _peers:
		return
	var peer := _peers[sender] as PlumberPeer
	var pipe: NetworkPipe = peer.get_pipe(pipe_id)
	if not pipe:
		return
	pipe.remote_pipe_id = remote_pipe_id
	pipe.status = NetworkPipe.Status.OPEN

@rpc("any_peer", "call_remote", "reliable", CHANNEL)
func _pipe_close_rpc(pipe_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender not in _peers:
		return
	var peer := _peers[sender] as PlumberPeer
	var pipe: NetworkPipe = peer.get_pipe(pipe_id)
	if not pipe:
		return
	assert(pipe.status != NetworkPipe.Status.CLOSED)
	peer.remove_pipe(pipe)
	pipe.status = NetworkPipe.Status.CLOSED

@rpc("any_peer", "call_remote", "reliable", CHANNEL)
func _pipe_send_rpc(pipe_id: int, message: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender not in _peers:
		return
	var peer := _peers[sender] as PlumberPeer
	var pipe: NetworkPipe = peer.get_pipe(pipe_id)
	if not pipe:
		return
	var msg := TaggedMessage.new()
	if not msg.decode(message):
		return
	assert(pipe.status != NetworkPipe.Status.CLOSED)
	pipe._recv(msg)

@rpc("any_peer", "call_remote", "reliable", CHANNEL)
func _pipe_send_raw_rpc(pipe_id: int, message: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender not in _peers:
		return
	var peer := _peers[sender] as PlumberPeer
	var pipe: NetworkPipe = peer.get_pipe(pipe_id)
	if not pipe:
		return
	assert(pipe.status != NetworkPipe.Status.CLOSED)
	pipe._recv_raw(message)

class PlumberPeer:
	var pipes: Dictionary # { [pipe_id: int]: NetworkPipe }
	var extra_refs: Dictionary # { [pipe_id: int]: NetworkPipe }
	
	func get_pipe(pipe_id: int) -> NetworkPipe:
		return pipes.get(pipe_id)
	
	func add_pipe(pipe: NetworkPipe) -> void:
		pipes[pipe.pipe_id] = pipe
		if pipe.was_created_remotely:
			extra_refs[pipe.pipe_id] = pipe
	
	func remove_pipe(pipe: NetworkPipe) -> void:
		pipes.erase(pipe.pipe_id)
		extra_refs.erase(pipe.pipe_id)
