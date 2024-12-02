extends Control

const SUFFIXES = ["B", "K", "M", "G"]

const SEND_RECV_IDLE = preload("res://framework/shells/default/send_recv_idle.tres")
const SEND_RECV_OFFLINE = preload("res://framework/shells/default/send_recv_offline.tres")
const SEND_RECV_DOWN_LOW = preload("res://framework/shells/default/send_recv_down_low.tres")
const SEND_RECV_DOWN_HIGH = preload("res://framework/shells/default/send_recv_down_high.tres")
const SEND_RECV_UP_LOW = preload("res://framework/shells/default/send_recv_up_low.tres")
const SEND_RECV_UP_HIGH = preload("res://framework/shells/default/send_recv_up_high.tres")

@onready var base: TextureRect = $Base
@onready var send_overlay: TextureRect = $Base/SendOverlay
@onready var recv_overlay: TextureRect = $Base/RecvOverlay
@onready var send_label: Label = $VBoxContainer/SendContainer/SendLabel
@onready var recv_label: Label = $VBoxContainer/RecvContainer/RecvLabel

func _ready() -> void:
	multiplayer.connected_to_server.connect(_update)
	multiplayer.server_disconnected.connect(_update)
	_update()

func _update() -> void:
	if not multiplayer.get_peers().is_empty():
		var stats = NetworkStats.new() # TODO
		base.texture = SEND_RECV_IDLE
		send_overlay.texture = SEND_RECV_UP_LOW if stats.transfer_up == 0 else SEND_RECV_UP_HIGH
		recv_overlay.texture = SEND_RECV_DOWN_LOW if stats.transfer_down == 0 else SEND_RECV_DOWN_HIGH
		
		send_label.text = _format_size(stats.total_up)
		recv_label.text = _format_size(stats.total_down)
	else:
		base.texture = SEND_RECV_OFFLINE
		send_overlay.texture = null
		recv_overlay.texture = null
		send_label.text = _format_size(0)
		recv_label.text = _format_size(0)

func _format_size(sz: int) -> String:
	if sz == 0: return "0 "
	var suff = 0
	while sz >= 1024:
		sz /= 1024
		suff += 1
	return str(sz) + SUFFIXES[suff]
