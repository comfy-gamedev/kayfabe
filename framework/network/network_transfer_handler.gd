class_name NetworkTransferHandler
extends Node

signal download_started(transfer: NetworkTransfer)

const TRACE = true
const MSG_TRANSFER = &"_FWK_NTH_TRANSFER"

@export var network_plumber: NetworkPlumber

var _peers: Dictionary # { [peer_id: int]: TransferPeer }

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta: float) -> void:
	for peer_id: int in _peers:
		var peer := _peers[peer_id] as TransferPeer
		
		if not peer.current:
			var pending := peer.queue.pop_front() as PendingTransfer
			if pending:
				var pipe := network_plumber.pipe_create(peer_id)
				pending.pipe = pipe
				peer.current = pending
		
		if peer.current:
			var transfer = peer.current.transfer
			if not transfer:
				if peer.current.pipe.is_open():
					transfer = NetworkTransfer.new()
					peer.current.transfer = transfer
					_start_transfer_rpc.rpc_id(peer_id, peer.current.pipe.remote_pipe_id, peer.current.document_uuid)
					var sha256 = Desktop.current.filesystem.open(peer.current.document_uuid).version.sha256
					transfer.begin_upload(
						peer.current.pipe, peer.current.document_uuid, peer.current.sha256)
					peer.current.started.emit()
			else:
				if not transfer.is_done():
					var err = transfer.process()
					if err != OK:
						push_error("Outbound Transfer failed: ", error_string(err))
						peer.current.pipe.close()
						peer.current = null
				if transfer.is_done():
					peer.current = null
		
		var inbound_done = []
		for inbound: NetworkTransfer in peer.inbound:
			if TRACE: print_verbose("NetworkTransferHandler: process inbound %s." % inbound.document_uuid)
			if not inbound.is_done():
				var err = inbound.process()
				if err != OK:
					push_error("Inbound Transfer failed: ", error_string(err))
					inbound.pipe.close()
					if TRACE: print_verbose("NetworkTransferHandler: inbound error %s (%s)." % [inbound.document_uuid, error_string(err)])
					inbound_done.append(inbound)
			if inbound.is_done():
				if TRACE: print_verbose("NetworkTransferHandler: inbound completed %s." % inbound.document_uuid)
				inbound_done.append(inbound)
		for inbound in inbound_done:
			peer.inbound.erase(inbound)

func enqueue_upload_async(peer_id: int, document: Document) -> NetworkTransfer:
	var peer = _peers.get(peer_id) as TransferPeer
	if not peer:
		push_error("Invalid peer_id.")
		return null
	
	var sha256 = document.version.sha256
	
	var pending: PendingTransfer
	for i in peer.queue.size():
		if peer.queue[i].peer_id == peer_id and peer.queue[i].document_uuid == document.uuid:
			pending = peer.queue[i]
			if pending.sha256 != sha256:
				pending.sha256 = sha256
	
	if not pending:
		pending = PendingTransfer.new()
		pending.peer_id = peer_id
		pending.document_uuid = document.uuid
		pending.sha256 = sha256
		pending.transfer = null
		peer.queue.append(pending)
	
	await pending.started
	return pending.transfer

func request_transfer_async(document_uuid: StringName) -> NetworkTransfer:
	if multiplayer.is_server():
		push_error("Server cannot request transfers.")
		return null
	
	_request_transfer_rpc.rpc_id(1, document_uuid)
	
	var xfer: NetworkTransfer = await download_started
	
	# This is kind of a scary infinite loop but I genuinely don't think
	# there's any other way to do this. We could immediately create a
	# paired NetworkTransfer to return, but that'd just be kicking the can
	# down the road to the caller. As long as the server is processing
	# transfers, this SHOULD eventually yield.
	while xfer.document_uuid != document_uuid:
		xfer = await download_started
	
	return xfer

func _on_peer_connected(id: int) -> void:
	assert(id not in _peers)
	_peers[id] = TransferPeer.new()

func _on_peer_disconnected(id: int) -> void:
	var peer := _peers.get(id) as TransferPeer
	if not peer:
		return
	if peer.current:
		peer.current.transfer.finished.emit(false)
		peer.current = null
	while not peer.queue.is_empty() or not peer.inbound.is_empty():
		var pending_xfer := peer.queue.pop_front() as PendingTransfer
		while pending_xfer:
			pending_xfer.transfer.finished.emit(false)
			pending_xfer = peer.queue.pop_front()
		var inbound_xfer := peer.inbound.pop_front() as NetworkTransfer
		while inbound_xfer:
			inbound_xfer.finished.emit(false)
			inbound_xfer = peer.inbound.pop_front()
	_peers.erase(id)

func _on_server_disconnected() -> void:
	for id in _peers.keys():
		_on_peer_disconnected(id)
	_peers.clear()

@rpc("any_peer", "call_remote", "reliable")
func _request_transfer_rpc(document_uuid: StringName) -> void:
	if not multiplayer.is_server():
		push_error("Only the server can be requested to initiate a transfer.")
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	
	var doc = Desktop.current.filesystem.open(document_uuid)
	if not doc:
		push_error("Document not found: ", document_uuid)
		return
	
	Desktop.current.network_transfer_handler.enqueue_upload_async(peer_id, doc)

@rpc("any_peer", "call_remote", "reliable", NetworkPlumber.CHANNEL)
func _start_transfer_rpc(pipe_id: int, document_uuid: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var pipe := network_plumber.pipe_get(peer_id, pipe_id)
	var peer := _peers.get(peer_id) as TransferPeer
	var transfer := NetworkTransfer.new()
	var sha256 := Desktop.current.filesystem.open(document_uuid).version.sha256
	peer.inbound.append(transfer)
	transfer.begin_download(pipe, document_uuid, sha256)
	download_started.emit(transfer)

class PendingTransfer:
	signal started()
	var peer_id: int
	var document_uuid: StringName
	var sha256: String
	var pipe: NetworkPipe
	var transfer: NetworkTransfer

class TransferPeer:
	var current: PendingTransfer
	var queue: Array[PendingTransfer]
	var inbound: Array[NetworkTransfer]
