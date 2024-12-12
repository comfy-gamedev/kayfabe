@tool
class_name DiceRoll
extends RefCounted

enum Tok {
	END,
	INT,
	UNARY_SUFFIX,
	BINOP,
	HIGHLOW,
	OF,
	LPAREN,
	RPAREN,
}

enum Ast {
	INT,
	UNARYOP,
	BINOP,
	HIGHLOW,
}

enum Type {
	NIL,
	INT,
	ROLL,
	ARRAY,
}

const OP_PREC = {
	"d": 10,
	"dF": 10,
	"!": 9,
	"and": 5,
	"*": 2,
	"/": 2,
	"+": 1,
	"-": 1,
}

static var tokdefs: Dictionary = {
	Tok.END: RegEx.create_from_string("\\G\\s*\\K$"),
	Tok.INT: RegEx.create_from_string("\\G\\s*\\K[0-9]+"),
	Tok.UNARY_SUFFIX: RegEx.create_from_string("\\G\\s*\\K(?:dF|\\!)"),
	Tok.BINOP: RegEx.create_from_string("\\G\\s*\\K(?:<=|>=|[+\\-/*d<>=])"),
	Tok.HIGHLOW: RegEx.create_from_string("\\G\\s*\\K(?:highest|lowest)"),
	Tok.OF: RegEx.create_from_string("\\G\\s*\\Kof"),
	Tok.LPAREN: RegEx.create_from_string("\\G\\s*\\K[(]"),
	Tok.RPAREN: RegEx.create_from_string("\\G\\s*\\K[)]"),
}

var source: String = ""
var ops: Array[Dictionary] = []
var errors: PackedStringArray
var root: Dictionary

var _in_progress: bool = false

var _next: Dictionary # { tok: Tok, str: String, pos: int }

var _roller: AbstractRoller
var _rolls: Dictionary

static func create_from_string(src: String) -> DiceRoll:
	var d := DiceRoll.new()
	if not d.parse(src):
		push_error("DiceRoll error: ", d.errors)
		return null
	return d

func parse(s: String) -> bool:
	source = s
	ops.clear()
	errors.clear()
	_next = {}
	_consume()
	root = _parse_expr()
	return root != {}

func dump_ast(ast: Dictionary = root) -> String:
	match ast.ast:
		Ast.INT:
			return str(ast.value)
		Ast.UNARYOP:
			return "(%s %s)" % [ast.op, dump_ast(ast.lhs)]
		Ast.BINOP:
			return "(%s %s %s)" % [ast.op, dump_ast(ast.lhs), dump_ast(ast.rhs)]
		Ast.HIGHLOW:
			return "(%s %s %s)" % [ast.highlow, dump_ast(ast.n), dump_ast(ast.rhs)]
	return "?"

func eval(roller: AbstractRoller = DefaultRoller.new(), pre_rolls: Dictionary = {}) -> Result:
	if _in_progress:
		push_error("DiceRoll is already in progress!")
		return null
	_in_progress = true
	var roller_initial_state = roller.get_rng_state()
	_rolls = pre_rolls.duplicate()
	_roller = roller
	var value: int = _total(_eval(root)).value
	var result := Result.new()
	result.value = value
	result.rolls = _rolls
	result.roller = _roller
	result.roller_initial_state = roller_initial_state
	_in_progress = false
	return result

func _eval(ast: Dictionary) -> Dictionary:
	match ast.ast:
		Ast.INT:
			return { type = Type.INT, value = ast.value }
		Ast.UNARYOP:
			match ast.op:
				"dF":
					var lhs = _total(_eval(ast.lhs))
					return _roll("F", ast.pos, 0, lhs.value)
				"!":
					var lhs = _eval(ast.lhs)
					if lhs.type != Type.ARRAY:
						return lhs
					var i = 0
					var stage = 1
					while i < lhs.values.size():
						var explode = {}
						while i < lhs.values.size():
							var v = lhs.values[i]
							var explodes = false
							if v.type == Type.ROLL:
								match v.kind:
									"F":
										if v.value == 1:
											explodes = true
									_:
										if v.value == int(v.kind):
											explodes = true
							if explodes:
								var id = Vector2i(v.roll_id, v.stage)
								explode[id] = explode.get(id, 0) + 1
							i += 1
						for id in explode:
							_append(lhs, _roll(_rolls[id].kind, id.x, id.y + 1, explode[id]))
					return lhs
		Ast.BINOP:
			match ast.op:
				"+":
					var result = { type = Type.ARRAY, values = [] }
					_append(result, _eval(ast.lhs))
					_append(result, _eval(ast.rhs))
					return result
				"-":
					var lhs = _total(_eval(ast.lhs))
					var rhs = _total(_eval(ast.rhs))
					return { type = Type.INT, value = lhs.value - rhs.value }
				"*":
					var lhs = _total(_eval(ast.lhs))
					var rhs = _total(_eval(ast.rhs))
					return { type = Type.INT, value = lhs.value * rhs.value }
				"/":
					var lhs = _total(_eval(ast.lhs))
					var rhs = _total(_eval(ast.rhs))
					return { type = Type.INT, value = lhs.value / rhs.value }
				"d":
					var lhs = _total(_eval(ast.lhs))
					var rhs = _total(_eval(ast.rhs))
					return _roll(str(rhs.value), ast.pos, 0, lhs.value)
		Ast.HIGHLOW:
			var n = _eval(ast.n)
			var rhs = _eval(ast.rhs)
			if rhs.type != Type.ARRAY:
				return rhs
			rhs.values.sort_custom(func (a, b): return _total(a).value < _total(b).value)
			match ast.highlow:
				"highest":
					rhs.values = rhs.values.slice(-n)
				"lowest":
					rhs.values = rhs.values.slice(n)
			return rhs
	
	breakpoint
	return { type = Type.NIL }

func _roll(kind: String, roll_id: int, stage: int, count: int) -> Dictionary:
	var dice = _rolls.get(Vector2i(roll_id, stage), {})
	if not dice:
		dice = { kind = kind, rolls = [] }
		_rolls[Vector2i(roll_id, stage)] = dice
	
	var result = { type = Type.ARRAY, values = [] }
	
	if dice.kind != kind:
		dice.kind = kind
		dice.rolls.clear()
	
	for i in count:
		if i >= dice.rolls.size():
			dice.rolls.append(_roller.throw_die(kind))
		result.values.append({
			type = Type.ROLL,
			value = dice.rolls[i],
			kind = kind,
			roll_id = roll_id,
			stage = stage
		})
	
	return result

func _total(v: Dictionary) -> Dictionary:
	match v.type:
		Type.INT:
			return v
		Type.ROLL:
			return { type = Type.INT, value = v.value }
		Type.ARRAY:
			var sum := 0
			for vv in v.values:
				sum += _total(vv).value
			return { type = Type.INT, value = sum }
	print("eh? ", v)
	breakpoint
	return { type = Type.INT, value = 0 }

func _append(arr: Dictionary, rhs: Dictionary) -> void:
	assert(arr.type == Type.ARRAY)
	match rhs.type:
		Type.INT:
			arr.values.append(rhs)
		Type.ROLL:
			arr.values.append(rhs)
		Type.ARRAY:
			arr.values.append_array(rhs.values)

func _error(msg: String, start: int, end: int = start) -> void:
	if start == end:
		errors.append("%s: %s" % [start, msg])
	else:
		errors.append("%s-%s: %s" % [start, end, msg])

#region Parser

func _consume() -> void:
	var i: int = _next.end if _next else 0
	_next = {}
	for tok in tokdefs:
		var regex: RegEx = tokdefs[tok]
		var m := regex.search(source, i)
		if m:
			_next = {
				"tok": tok,
				"str": m.get_string(0),
				"start": m.get_start(0),
				"end": m.get_end(0),
			}
			break
	if not _next:
		_next = { "tok": Tok.END, "str": "", "start": i, "end": i }
		_error("Unknown token", i, i)

func _expect(tok: Tok) -> bool:
	if _next.tok == tok:
		_consume()
		return true
	_error("Expected " + Tok.find_key(tok), _next.start)
	return false

func _parse_expr(min_prec: int = 0) -> Dictionary:
	var lhs := _parse_atom()
	if not lhs:
		return {}
	
	while _next and _next.tok == Tok.BINOP:
		var op: String = _next.str
		var op_pos: int = _next.start
		var prec: int = OP_PREC[op]
		if prec <= min_prec:
			break
		
		_consume()
		
		var rhs := _parse_expr(prec)
		if not rhs:
			return {}
		
		lhs = _ast_binop(op, lhs, rhs, op_pos)
	
	while _next and _next.tok == Tok.UNARY_SUFFIX:
		var op: String = _next.str
		var op_pos: int = _next.start
		var prec: int = OP_PREC[op]
		if prec <= min_prec:
			break
		
		_consume()
		
		lhs = _ast_unary(op, lhs, op_pos)
	
	return lhs

func _parse_atom() -> Dictionary:
	var val = {}
	match _next.tok:
		Tok.LPAREN:
			_consume()
			val = _parse_expr()
			if not _expect(Tok.RPAREN):
				return {}
		Tok.INT:
			val = _ast_int(int(_next.str))
			_consume()
		Tok.HIGHLOW:
			var highlow: String = _next.str
			_consume()
			var n := _parse_atom()
			if not n:
				return {}
			_expect(Tok.OF)
			var expr := _parse_expr(OP_PREC["and"] - 1)
			if not expr:
				return {}
			val = _ast_highlow(highlow, n, expr)
	
	return val

func _ast_int(v: int) -> Dictionary:
	return { "ast": Ast.INT, "value": v }

func _ast_binop(op: String, lhs: Dictionary, rhs: Dictionary, pos: int) -> Dictionary:
	return { "ast": Ast.BINOP, "op": op, "lhs": lhs, "rhs": rhs, "pos": pos }

func _ast_unary(op: String, lhs: Dictionary, pos: int) -> Dictionary:
	return { "ast": Ast.UNARYOP, "op": op, "lhs": lhs, "pos": pos }

func _ast_highlow(highlow: String, n: Dictionary, rhs: Dictionary) -> Dictionary:
	return { "ast": Ast.HIGHLOW, "highlow": highlow, "n": n, "rhs": rhs }

#endregion Parser

class Result:
	var value: int
	var rolls: Dictionary
	var roller: AbstractRoller
	var roller_initial_state: Variant

class AbstractRoller:
	func get_rng_state() -> Variant: # VIRTUAL
		push_error("Not implemented")
		breakpoint
		return null
	
	@warning_ignore("unused_parameter")
	func reset_rng_state(state: Variant) -> void: # VIRTUAL
		push_error("Not implemented")
		breakpoint
		pass
	
	@warning_ignore("unused_parameter")
	func throw_die(kind: String) -> int: # VIRTUAL
		push_error("Not implemented")
		breakpoint
		return 0

class DefaultRoller extends AbstractRoller:
	var _rng: RandomNumberGenerator
	
	func _init(rng: RandomNumberGenerator = null) -> void:
		_rng = rng if rng else RandomNumberGenerator.new()
	
	func get_rng_state() -> Variant:
		return Vector2i(_rng.seed, _rng.state)
	
	func reset_rng_state(state: Variant) -> void:
		_rng.seed = state.x
		_rng.state = state.y
	
	func throw_die(kind: String) -> int:
		var face_range = [-1, 1] if kind == "F" else [1, int(kind)]
		return _rng.randi_range(face_range[0], face_range[1])
