extends AppService

const CONTROLLER = preload("res://apps/dice-roll/controller.tscn")
const ROLL_WINDOW = preload("res://apps/dice-roll/roll_window.tscn")

var rng: RandomNumberGenerator

var _controller: AppWindow

func _init() -> void:
	rng = RandomNumberGenerator.new()

func _icon_activated() -> void:
	if is_instance_valid(_controller):
		_controller.bring_to_front()
		return
	_controller = CONTROLLER.instantiate()
	window_open(_controller)

func roll_broadcast(src: String) -> void:
	if not multiplayer.is_server():
		_roll_server_rpc.rpc_id(0, src)
	else:
		var result = roll(src)
		_roll_client_rpc.rpc(src, result.roller_initial_state)

func roll(src: String, roller_initial_state: Variant = null) -> DiceRoll.Result:
	var d := DiceRoll.create_from_string(src)
	if not d:
		push_error("Invalid roll syntax")
		return
	
	var roller := DiceRoll.DefaultRoller.new()
	if roller_initial_state:
		roller.reset_rng_state(roller_initial_state)
	
	var result := d.eval(roller)
	print("Rolled %s! (%s)" % [result.value, src])
	
	var w = ROLL_WINDOW.instantiate()
	w.dice_roll = d
	w.result = result
	window_open(w)
	w.roll()
	
	return result

@rpc("any_peer", "call_remote", "reliable")
func _roll_server_rpc(src: String) -> void:
	roll_broadcast(src)

@rpc("authority", "call_remote", "reliable")
func _roll_client_rpc(src: String, roller_initial_state: Variant) -> void:
	roll(src, roller_initial_state)
