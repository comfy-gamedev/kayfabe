extends PanelContainer

const SUFFIXES = ["B", "K", "M", "G"]

@onready var send_label: Label = $HBoxContainer/VBoxContainer/SendContainer/SendLabel
@onready var recv_label: Label = $HBoxContainer/VBoxContainer/RecvContainer/RecvLabel
@onready var download_indicator = $HBoxContainer/DownloadIndicator
@onready var upload_indicator = $HBoxContainer/UploadIndicator

func _ready() -> void:
	multiplayer.connected_to_server.connect(_update)
	multiplayer.server_disconnected.connect(_update)
	_update()

func _update() -> void:
	if not multiplayer.get_peers().is_empty():
		var stats = NetworkStats.new() # TODO
		send_label.text = _format_size(stats.total_up)
		recv_label.text = _format_size(stats.total_down)
		_apply_panel_theme(download_indicator, "idle", "NetworkDownloadIndicator")
		_apply_panel_theme(upload_indicator, "idle", "NetworkUploadIndicator")

	else:
		_apply_panel_theme(download_indicator, "disconnected", "NetworkDownloadIndicator")
		_apply_panel_theme(upload_indicator, "disconnected", "NetworkUploadIndicator")
		send_label.text = _format_size(0)
		recv_label.text = _format_size(0)
#
func _format_size(sz: int) -> String:
	if sz == 0: return "0 "
	var suff = 0
	while sz >= 1024:
		sz /= 1024
		suff += 1
	return str(sz) + SUFFIXES[suff]

func _apply_panel_theme(panel, p_name, type_variation):
	panel.add_theme_stylebox_override("panel", get_theme_stylebox(p_name, type_variation))
