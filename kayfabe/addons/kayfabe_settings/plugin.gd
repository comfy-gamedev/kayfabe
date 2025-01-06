@tool
extends EditorPlugin

var SETTINGS = {
	"kayfabe/networking/lobby_server_host": {
		basic = true,
		initial_value = "localhost:3000",
	},
	"kayfabe/networking/lobby_server_use_tls": {
		basic = true,
		initial_value = false,
	},
	"kayfabe/networking/webrtc_stun_servers": {
		basic = true,
		initial_value = PackedStringArray(["stun.l.google.com:19302"]),
	},
}

func _enter_tree() -> void:
	for key in SETTINGS:
		var setting = SETTINGS[key]
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, setting.initial_value)
		ProjectSettings.set_initial_value(key, setting.initial_value)
		ProjectSettings.set_as_basic(key, setting.basic)
		ProjectSettings.set_order(key, 0)

func _exit_tree() -> void:
	pass
