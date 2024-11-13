@tool
extends EditorPlugin

const SwatchPalette = preload("res://addons/swatch_palette/palette.gd")

const TOOL_NAME = "Swatch Palette"

enum {
	BTN_SAVE,
	BTN_LOAD,
}

var popup: PopupMenu

var save_dialog: EditorFileDialog
var load_dialog: EditorFileDialog

var _current_palette_file: String

func _enter_tree() -> void:
	save_dialog = EditorFileDialog.new()
	save_dialog.current_file = _current_palette_file
	save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	save_dialog.file_selected.connect(_on_save_dialog_file_selected)
	save_dialog.add_filter("*.tres, *.res")
	add_child(save_dialog)
	
	load_dialog = EditorFileDialog.new()
	load_dialog.current_file = _current_palette_file
	load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	load_dialog.file_selected.connect(_on_load_dialog_file_selected)
	add_child(load_dialog)
	
	popup = PopupMenu.new()
	popup.name = "SwatchPaletteMenuPopup"
	popup.add_item("Save Palette...", BTN_SAVE)
	popup.add_item("Load Palette...", BTN_LOAD)
	popup.id_pressed.connect(_on_submenu_id_pressed)
	add_tool_submenu_item(TOOL_NAME, popup)
	

func _exit_tree() -> void:
	remove_tool_menu_item(TOOL_NAME)
	load_dialog.queue_free()
	save_dialog.queue_free()

func _on_submenu_id_pressed(id: int) -> void:
	match id:
		BTN_SAVE: _btn_save()
		BTN_LOAD: _btn_load()

func _btn_save() -> void:
	save_dialog.current_dir = _current_palette_file.get_base_dir()
	save_dialog.current_file = _current_palette_file.get_file()
	save_dialog.popup_file_dialog()

func _btn_load() -> void:
	load_dialog.current_dir = _current_palette_file.get_base_dir()
	load_dialog.current_file = _current_palette_file.get_file()
	load_dialog.popup_file_dialog()

func _on_save_dialog_file_selected(path: String) -> void:
	_current_palette_file = path
	save_dialog.hide()
	
	var color_picker_presets: PackedColorArray = (
		get_editor_interface()
		.get_editor_settings()
		.get_project_metadata("color_picker", "presets"))
	
	var palette = SwatchPalette.new()
	palette.colors = color_picker_presets
	palette.resource_path = path
	ResourceSaver.save(palette, path)

func _on_load_dialog_file_selected(path: String) -> void:
	_current_palette_file = path
	load_dialog.hide()
	
	var palette: SwatchPalette = ResourceLoader.load(path, "SwatchPalette", ResourceLoader.CACHE_MODE_IGNORE)
	
	if not palette:
		return
	
	(get_editor_interface()
		.get_editor_settings()
		.set_project_metadata("color_picker", "presets", palette.colors))
	
	print("Loaded palette")
	
	var title_bars = get_editor_interface().get_base_control().find_children("*", "EditorTitleBar", true, false)
	var menu_bar = title_bars[0].find_children("*", "MenuBar", false, false)[0]
	menu_bar.get_node("Project").id_pressed.emit(39)
	
