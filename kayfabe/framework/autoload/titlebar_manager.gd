extends Node

var main_title: String: set = set_main_title
var status_title: String: set = set_status_title
var profile_name: String: set = set_profile_name
var render_tracker: String = "-": set = set_render_tracker

var _update_queued: bool = false

func _ready() -> void:
	main_title = get_window().title
	profile_name = PlayerProfileManager.profile_name
	_update()

func set_main_title(v: String) -> void:
	if main_title == v: return
	main_title = v
	_update()

func set_status_title(v: String) -> void:
	if status_title == v: return
	status_title = v
	_update()

func set_profile_name(v: String) -> void:
	if profile_name == v: return
	profile_name = v
	_update()

func set_render_tracker(v: String) -> void:
	if render_tracker == v: return
	render_tracker = v
	_update()

func _update() -> void:
	if _update_queued: return
	_update_queued = true
	(func ():
		get_window().title = "%s %s %s (%s)" % [main_title, render_tracker, status_title, profile_name]
		_update_queued = false
	).call_deferred()
