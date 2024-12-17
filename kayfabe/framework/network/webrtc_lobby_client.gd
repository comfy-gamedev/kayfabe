extends "web_socket_client.gd"

signal client_identified()
signal recv_offer(id: int, sdp: String)
signal recv_answer(id: int, sdp: String)
signal recv_ice_candidate(id: int, media: String, index: int, name: String)

var peer_id: int

var host_uuid: String;
var desktop_uuid: String

func _init() -> void:
	connected.connect(_on_connected)
	disconnected.connect(_on_disconnected)
	recv_text.connect(_on_recv)

func host(p_host_uuid: String, p_desktop_uuid: String) -> void:
	peer_id = 1
	host_uuid = p_host_uuid
	desktop_uuid = p_desktop_uuid
	connect_to_url("ws://localhost:3000/lobby_ws")

func join(p_host_uuid: String, p_desktop_uuid: String) -> void:
	peer_id = 0
	host_uuid = p_host_uuid
	desktop_uuid = p_desktop_uuid
	connect_to_url("ws://localhost:3000/join/%s/%s" % [host_uuid, desktop_uuid])

func send_offer(id: int, sdp: String) -> void:
	send_text(JSON.stringify({
		"id": id,
		"data": { "Offer": { "sdp": sdp } }
	}))

func send_answer(id: int, sdp: String) -> void:
	send_text(JSON.stringify({
		"id": id,
		"data": { "Answer": { "sdp": sdp } }
	}))

func send_ice_candidate(id: int, media: String, index: int, p_name: String) -> void:
	send_text(JSON.stringify({
		"id": id,
		"data": { "IceCandidate": { "media": media, "index": index, "name": p_name } }
	}))

func _on_connected() -> void:
	print("_on_connected()")
	
	if peer_id == 1:
		send_text(JSON.stringify({
			"id": 1,
			"data": { "ServerAnnounce": { "host_uuid": host_uuid, "desktop_uuid": desktop_uuid } }
		}))

func _on_disconnected() -> void:
	print("_on_disconnected()")
	pass

func _on_recv(message_text: String) -> void:
	print("[%s] _on_recv(%s)" % [peer_id, message_text])
	
	var message = JSON.parse_string(message_text)
	
	match message.data.keys()[0]:
		"ClientIdentity":
			if peer_id == 0:
				peer_id = message.data.ClientIdentity.client_id
				client_identified.emit(peer_id)
		"Offer":
			recv_offer.emit(message.id, message.data.Offer.sdp)
		"Answer":
			recv_answer.emit(message.id, message.data.Answer.sdp)
		"IceCandidate":
			var ic = message.data.IceCandidate
			recv_ice_candidate.emit(message.id, ic.media, ic.index, ic.name)
		
	
