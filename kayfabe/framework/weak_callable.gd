class_name WeakCallable
extends RefCounted

static func make_weak(callable: Callable) -> Callable:
	assert(callable.get_argument_count() <= 4)
	match callable.get_argument_count():
		0: return _make_weak_0(callable)
		1: return _make_weak_1(callable)
		2: return _make_weak_2(callable)
		3: return _make_weak_3(callable)
		4: return _make_weak_4(callable)
	return Callable()

static func _make_weak_0(callable: Callable) -> Callable:
	var obj_weak: WeakRef = weakref(callable.get_object())
	var method: StringName = callable.get_method()
	var bound_args: Array = callable.get_bound_arguments()
	
	return func ():
		var obj: Object = obj_weak.get_ref()
		if obj:
			return obj.callv(method, bound_args)

static func _make_weak_1(callable: Callable) -> Callable:
	var obj_weak: WeakRef = weakref(callable.get_object())
	var method: StringName = callable.get_method()
	var bound_args: Array = callable.get_bound_arguments()
	
	return func (arg1):
		var obj: Object = obj_weak.get_ref()
		if obj:
			return obj.callv(method, [arg1] + bound_args)

static func _make_weak_2(callable: Callable) -> Callable:
	var obj_weak: WeakRef = weakref(callable.get_object())
	var method: StringName = callable.get_method()
	var bound_args: Array = callable.get_bound_arguments()
	
	return func (arg1, arg2):
		var obj: Object = obj_weak.get_ref()
		if obj:
			return obj.callv(method, [arg1, arg2] + bound_args)

static func _make_weak_3(callable: Callable) -> Callable:
	var obj_weak: WeakRef = weakref(callable.get_object())
	var method: StringName = callable.get_method()
	var bound_args: Array = callable.get_bound_arguments()
	
	return func (arg1, arg2, arg3):
		var obj: Object = obj_weak.get_ref()
		if obj:
			return obj.callv(method, [arg1, arg2, arg3] + bound_args)

static func _make_weak_4(callable: Callable) -> Callable:
	var obj_weak: WeakRef = weakref(callable.get_object())
	var method: StringName = callable.get_method()
	var bound_args: Array = callable.get_bound_arguments()
	
	return func (arg1, arg2, arg3, arg4):
		var obj: Object = obj_weak.get_ref()
		if obj:
			return obj.callv(method, [arg1, arg2, arg3, arg4] + bound_args)
