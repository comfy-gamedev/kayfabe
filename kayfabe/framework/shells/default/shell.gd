extends Control

signal start_server()
signal stop_server()

@onready var desktop: Desktop = Desktop.current
@onready var desktop_button: Button = %DesktopButton
@onready var menu_button: Button = %MenuButton
@onready var app_item_list = %AppItemList
@onready var search_line_edit: LineEdit = %SearchLineEdit
@onready var menu_panel_container: PanelContainer = %MenuPanelContainer

@onready var desktop_panel_container: PanelContainer = %DesktopPanelContainer
@onready var new_desktop_button = %NewDesktopButton
@onready var new_desktop_popup_panel = %NewDesktopPopupPanel
@onready var new_desktop_name_input = %NewDesktopNameInput
@onready var join_server_button = %JoinServerButton
@onready var join_server_popup_panel = %JoinServerPopupPanel
@onready var join_server_url_input = %JoinServerUrlInput

@onready var network_panel_container: PanelContainer = %NetworkPanelContainer
var _score_cache: Dictionary

func _ready() -> void:
	desktop_panel_container.hide()
	menu_panel_container.hide()
	new_desktop_popup_panel.hide()
	join_server_popup_panel.hide()

func _score_func(app_key: StringName) -> float:
	var string: String = String(app_key)
	var query: String = search_line_edit.text
	
	var cached = _score_cache.get([query, string], null)
	if cached != null:
		return cached
	
	var matches: PackedInt32Array
	matches.resize(string.length())
	
	var s_i: int = 0
	var q_i: int = 0
	var match_i: int = 0
	
	while s_i < string.length() and q_i < query.length():
		if string[s_i].to_lower() == query[q_i].to_lower():
			matches[match_i] = s_i
			match_i += 1
			q_i += 1
		s_i += 1
	
	var score: int = 0
	
	for i in match_i:
		q_i = matches[i]
		var ch = string[s_i]
		
		score += maxi(0, 3 - s_i) * 15
		if i > 0 and matches[i - 1] == s_i - 1:
			score += 10
		if ch.to_upper() == ch:
			score += 15
	
	if match_i > 0:
		score -= matches[0] * 5
	
	if q_i < query.length():
		score -= (query.length() - q_i) * 1
	else:
		score = maxi(score, 1)
	
	_score_cache[[query, str]] = score
	
	return score

func _on_desktop_button_pressed() -> void:
	if desktop_button.button_pressed:
		desktop_panel_container.visible = true
	else:
		desktop_panel_container.visible = false

func _on_menu_button_pressed() -> void:
	if menu_button.button_pressed:
		menu_panel_container.visible = true
		search_line_edit.clear()
		search_line_edit.grab_focus()
	else:
		menu_panel_container.visible = false

func _on_search_line_edit_text_changed(new_text: String) -> void:
	app_item_list.score_func = _score_func if new_text != "" else Callable()
	app_item_list._update_layout()

func _on_app_item_list_app_clicked(app_key: StringName) -> void:
	desktop.app_services[app_key]._icon_activated()

func _on_search_line_edit_up_pressed() -> void:
	app_item_list.focused_child_index -= 1

func _on_search_line_edit_down_pressed() -> void:
	app_item_list.focused_child_index += 1

func _on_network_panel_container_start_server_pressed() -> void:
	start_server.emit()

func _on_network_panel_container_stop_server_pressed() -> void:
	stop_server.emit()

func _on_new_desktop_button_toggled(toggled_on):
	new_desktop_popup_panel.visible = toggled_on
	if toggled_on:
		new_desktop_name_input.grab_focus()
	else:
		new_desktop_name_input.text = ""

func _on_join_server_button_toggled(toggled_on):
	join_server_popup_panel.visible = toggled_on
	if toggled_on:
		join_server_url_input.grab_focus()
	else:
		join_server_url_input.text = ""
		
func _on_create_desktop_button_pressed():
	pass # TODO: Make this create a desktop
	new_desktop_button.button_pressed = false

func _on_join_server_connect_button_pressed():
	pass # TODO: Steal the client connect code and add to top of desktops
	join_server_button.button_pressed = false
