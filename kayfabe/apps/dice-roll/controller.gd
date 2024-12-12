@tool
extends AppWindow


var modifier: int = 0: set = set_modifier


@onready var dice := {
	"2": %D2,
	"4": %D4,
	"6": %D6,
	"8": %D8,
	"10": %D10,
	"12": %D12,
	"20": %D20,
	"F": %DF,
}

@onready var formula_line_edit: LineEdit = $PanelContainer/VBoxContainer/FormulaLineEdit
@onready var mod_minus_button: Button = %ModMinusButton
@onready var modifier_label: Label = %ModifierLabel
@onready var mod_plus_button: Button = %ModPlusButton
@onready var roll_open_button: Button = %RollOpenButton
@onready var roll_hidden_button: Button = %RollHiddenButton

func _ready() -> void:
	super()
	for k in ["2", "4", "6", "8", "10", "12", "20", "F"]:
		dice[k].count = 0
		dice[k].visible = false
		dice[k].gui_input.connect(_on_die_gui_input.bind(k))
	roll_open_button.disabled = true
	roll_hidden_button.disabled = true
	_refresh_formula()

func set_modifier(v: int) -> void:
	if modifier == v: return
	modifier = v
	modifier_label.text = "%+d" % [modifier]
	_refresh_formula()

func _refresh_formula() -> void:
	var formula = ""
	for k in dice:
		if dice[k].count:
			if formula:
				formula += " + "
			formula += "%sd%s" % [dice[k].count, k]
	if modifier:
		if modifier > 0:
			if formula:
				formula += " + "
		else:
			if formula:
				formula += " - "
		formula += str(absi(modifier))
	formula_line_edit.text = formula
	roll_open_button.disabled = formula == ""
	roll_hidden_button.disabled = formula == ""

func _add_die(kind: String) -> void:
	dice[kind].count += 1
	dice[kind].visible = true
	_refresh_formula()

func _remove_die(kind: String) -> void:
	dice[kind].count = maxi(dice[kind].count - 1, 0)
	dice[kind].visible = dice[kind].count > 0
	_refresh_formula()

func _on_die_gui_input(event: InputEvent, kind: String) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_remove_die(kind)
			dice[kind].accept_event()
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			_remove_die(kind)
			dice[kind].accept_event()

func _on_d_2_button_pressed() -> void:
	_add_die("2")

func _on_d_4_button_pressed() -> void:
	_add_die("4")

func _on_d_6_button_pressed() -> void:
	_add_die("6")

func _on_d_8_button_pressed() -> void:
	_add_die("8")

func _on_d_10_button_pressed() -> void:
	_add_die("10")

func _on_d_12_button_pressed() -> void:
	_add_die("12")

func _on_d_20_button_pressed() -> void:
	_add_die("20")

func _on_df_button_pressed() -> void:
	_add_die("F")

func _on_roll_open_button_pressed() -> void:
	service.roll_broadcast(formula_line_edit.text)

func _on_roll_hidden_button_pressed() -> void:
	service.roll(formula_line_edit.text)

func _on_reset_button_pressed() -> void:
	for i in dice:
		dice[i].count = 0
		dice[i].visible = false
	modifier = 0
	_refresh_formula()

func _on_mod_minus_button_pressed() -> void:
	modifier -= 1

func _on_mod_plus_button_pressed() -> void:
	modifier += 1

func _on_modifier_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			modifier = 0
	elif event is InputEventKey:
		if event.pressed and event.physical_keycode == KEY_SPACE:
			modifier = 0
