@tool
extends AppWindow

const DieRollResultControl = preload("res://apps/dice-roll/die_roll_result_control.gd")

@onready var dice: HFlowContainer = %Dice
@onready var result_line_edit: LineEdit = %ResultLineEdit

var dice_roll: DiceRoll
var result: DiceRoll.Result

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	for k in result.rolls:
		var kind = result.rolls[k].kind
		for i in result.rolls[k].rolls.size():
			var face = result.rolls[k].rolls[i]
			var d = DieRollResultControl.new()
			d.set_meta("dice_keys", [k, i])
			d.kind = kind
			d.face = face
			d.visual_face_updated.connect(_on_visual_face_updated)
			d.landed.connect(_on_landed)
			dice.add_child(d)
	
	unfocused.connect(_on_unfocused)

func _on_landed() -> void:
	_update_result()
	print("Landed ", result_line_edit.text)

func _on_visual_face_updated() -> void:
	_update_result()

func _update_result() -> void:
	var roller = result.roller
	roller.reset_rng_state(result.roller_initial_state)
	
	var pre_rolls = result.rolls.duplicate(true)
	for d in dice.get_children():
		var keys = d.get_meta("dice_keys")
		pre_rolls[keys[0]].rolls[keys[1]] = d.get_visual_face()
	
	var fake_result = dice_roll.eval(roller, pre_rolls)
	result_line_edit.text = str(fake_result.value)

func roll() -> void:
	if not result:
		result = dice_roll.eval()
	for d in dice.get_children():
		d.roll()

func _on_unfocused() -> void:
	close()
