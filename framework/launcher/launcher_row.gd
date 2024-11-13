extends PanelContainer

signal activated()
signal name_edited(new_name: String)

@onready var icon_texture_rect: TextureRect = %IconTextureRect
@onready var name_label: Label = %NameLabel
@onready var launch_button: Button = %LaunchButton
@onready var name_line_edit: LineEdit = %NameLineEdit

var _theme_style_focus: StyleBox

func _ready() -> void:
	_update_theme_cache()
	theme_changed.connect(_update_theme_cache)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.double_click:
			activated.emit()

func _draw() -> void:
	if has_focus() and _theme_style_focus:
		draw_style_box(_theme_style_focus, Rect2(Vector2.ZERO, size))

func edit_name() -> void:
	name_line_edit.text = name_label.text
	name_line_edit.show()
	name_line_edit.grab_focus()
	name_line_edit.select_all()

func _on_launch_button_pressed() -> void:
	activated.emit()

func _update_theme_cache() -> void:
	_theme_style_focus = get_theme_stylebox("focus") if has_theme_stylebox("focus") else null
	queue_redraw()


func _on_name_line_edit_focus_exited() -> void:
	name_line_edit.hide()
	name_edited.emit(name_line_edit.text)


func _on_name_line_edit_text_submitted(new_text: String) -> void:
	name_line_edit.hide()
	name_edited.emit(new_text)
