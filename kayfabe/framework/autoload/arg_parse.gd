extends Node
## 
## Handles command line argument parsing.
## 
## To add a new parameter, add it to the [member _params] dictionary.
## Each entry must have either a "type" or "const_value".
##
## If the entry has a "type", the parser will expect that the next command line argument
## is the parameter's value, and will cast it according to this specified type.
##
## If the entry has a "const_value", then no additional command line argument is expected,
## instead the const_value will be used as the argument value.
##

var _params := {
	"--player_profile": { type = TYPE_STRING },
}

var _arg_values := {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := args[i]
		
		if not arg in _params:
			_error("Unknown command line argument: " + arg)
			i += 1
			continue
		
		var param: Dictionary = _params[arg]
		
		if "const_value" in param:
			_arg_values[arg] = param.const_value
			i += 1
			continue
		
		assert("type" in param)
		
		i += 1
		
		if not i < args.size():
			_error("Argument " + arg + " requires a value.")
			break
		
		match param.type:
			TYPE_INT:
				_arg_values[arg] = int(args[i])
			TYPE_FLOAT:
				_arg_values[arg] = float(args[i])
			TYPE_STRING:
				_arg_values[arg] = String(args[i])
			TYPE_BOOL:
				_arg_values[arg] = args[i].to_lower() in ["true", "yes", "1"]
			_:
				_error("Unsupported command line parameter type for " + arg)
		
		i += 1
		continue
	
	print("Parsed command line arguments: ", _arg_values)

## Returns true if the given argument was found on the command line.
func has_arg(arg: String) -> bool:
	if not arg in _params:
		push_error("Invalid argument string: ", arg)
		return false
	
	return arg in _arg_values

## Returns the value of the given argument name. The argument must exist.
func get_arg_value(arg: String) -> Variant:
	if not has_arg(arg):
		push_error("Command line argument ", arg, " is absent.")
		return null
	
	return _arg_values[arg]

func _error(msg: String) -> void:
	OS.alert(msg, "INVALID ARGUMENT")
	get_tree().quit(1)
