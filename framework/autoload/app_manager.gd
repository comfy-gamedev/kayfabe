extends Node

const APPS_DIR = "res://apps/"

var _apps: Dictionary = {}

func _ready() -> void:
	rescan()

func rescan() -> void:
	for d: StringName in DirAccess.get_directories_at(APPS_DIR):
		if d in _apps:
			continue
		var app_manifest_path := APPS_DIR.path_join(d).path_join("app_manifest.tres")
		if not FileAccess.file_exists(app_manifest_path):
			push_error("App %s has no manifest!" % [d])
			continue
		var app_manifest: AppManifest = ResourceLoader.load(app_manifest_path, "AppManifest")
		if not app_manifest:
			push_error("App %s's manifest is invalid!" % [d])
			continue
		_apps[d] = app_manifest
		print("Found app %s (%s)" % [app_manifest.name, d])

func get_app_keys() -> Array[StringName]:
	return Array(_apps.keys(), TYPE_STRING_NAME, &"", null)

func get_app_manifest(app_key: StringName) -> AppManifest:
	var app_manifest: AppManifest = _apps.get(app_key)
	if app_manifest == null:
		push_error("App %s has not been discovered." % [app_key])
	return app_manifest
