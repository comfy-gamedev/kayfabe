extends Control

@onready var desktop: Desktop = Desktop.current
@onready var menu_button: Button = %MenuButton
@onready var desktop_name_label: Label = %DesktopNameLabel
@onready var app_item_list = %AppItemList
@onready var search_line_edit: LineEdit = %SearchLineEdit
@onready var menu_panel_container: PanelContainer = %MenuPanelContainer

var _score_cache: Dictionary

func _score_func(app_key: StringName) -> float:
	var str: String = String(app_key)
	var pat: String = search_line_edit.text
	
	var cached = _score_cache.get([pat, str], null)
	if cached != null:
		return cached
	
	var matches: PackedInt32Array
	matches.resize(str.length())
	
	var str_i: int = 0
	var pat_i: int = 0
	var match_i: int = 0
	
	while str_i < str.length() and pat_i < pat.length():
		if str[str_i].to_lower() == pat[pat_i].to_lower():
			matches[match_i] = str_i
			match_i += 1
			pat_i += 1
		str_i += 1
	
	var score: float = 0.0
	
	for i in match_i:
		str_i = matches[i]
		var ch = str[str_i]
		
		score += maxi(0, 3 - str_i) * 15
		if i > 0 and matches[i - 1] == str_i - 1:
			score += 10
		if ch.to_upper() == ch:
			score += 15
	
	if match_i > 0:
		score -= matches[0] * 5
	
	if pat_i < pat.length():
		score -= (pat.length() - pat_i) * 1
	else:
		score = maxi(score, 1)
	
	_score_cache[[pat, str]] = score
	
	return score

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
