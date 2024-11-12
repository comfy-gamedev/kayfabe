class_name AppManifest
extends Resource

@export var name: String = "My App"
@export var icon: Texture2D
@export_file var service_node_path: String

var app_key: StringName:
	get:
		if app_key == StringName():
			app_key = resource_path.get_base_dir().get_file()
		return app_key
