extends PanelContainer

signal start_server_pressed()
signal stop_server_pressed()

@onready var offline_view: Control = $OfflineView
@onready var server_view: Control = $ServerView
@onready var client_view: Control = $ClientView
@onready var url_line_edit: LineEdit = %UrlLineEdit
@onready var players_list: ItemList = %PlayersList

func _ready() -> void:
	multiplayer.connected_to_server.connect(_update)
	multiplayer.server_disconnected.connect(_update)
	multiplayer.peer_connected.connect(_update.unbind(1))
	multiplayer.peer_disconnected.connect(_update.unbind(1))
	_update()

func _update() -> void:
	if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer and multiplayer.is_server():
		offline_view.hide()
		server_view.show()
		client_view.hide()
		players_list.clear()
		url_line_edit.text = Desktop.current.desktop_multiplayer.server_url
		for i in multiplayer.get_peers():
			players_list.add_item(multiplayer.get_player_info(i).name)
	elif not multiplayer.get_peers().is_empty():
		offline_view.hide()
		server_view.hide()
		client_view.show()
		players_list.clear()
	else:
		offline_view.show()
		server_view.hide()
		client_view.hide()
		players_list.clear()


func _on_start_server_button_pressed() -> void:
	start_server_pressed.emit()


func _on_stop_server_button_pressed() -> void:
	stop_server_pressed.emit()

var __t: float = -1

func _on_url_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			DisplayServer.clipboard_set(url_line_edit.text)
			var tween = create_tween()
			tween.tween_method(func (t: float):
				__t = t
				url_line_edit.queue_redraw()
			, 0.0, 1.0, 1.0)
			tween.tween_property(self, "__t", -1, 0)

func _on_url_line_edit_draw() -> void:
	if __t < 0:
		return
	var font = get_theme_font("font")
	var sz = font.get_string_size("Copied!")
	url_line_edit.draw_set_transform(url_line_edit.get_rect().size / 2.0)
	url_line_edit.draw_string(font, -sz/2.0, "Copied!", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 16, Color(1, 0, 1, 1.0 - ease(__t, 4.0)))
