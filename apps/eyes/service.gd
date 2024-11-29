extends AppService

const EYES = preload("eyes.tscn")

var _player_cursors = {}

func _process(delta: float) -> void:
	_update_cursor_rpc.rpc(get_viewport().get_mouse_position())

func _icon_activated() -> void:
	var window = EYES.instantiate()
	window_open(window)

func get_cursors() -> Dictionary:
	return _player_cursors

@rpc("any_peer", "call_local", "unreliable_ordered")
func _update_cursor_rpc(pos: Vector2) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	_player_cursors[peer_id] = pos
