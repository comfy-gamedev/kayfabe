extends Node

var profile_name: String
var profile_root: String
var profile: PlayerProfile

func _ready() -> void:
	profile_name = "default"
	if ArgParse.has_arg("--player_profile"):
		var arg := ArgParse.get_arg_value("--player_profile") as String
		if not arg.is_valid_filename():
			push_error("Invalid profile name: ", arg)
			OS.alert("Invalid profile name: " + arg, "ERROR")
			get_tree().quit(1)
			return
		profile_name = arg
	
	assert(profile_name)
	profile_root = "user://profile_%s" % [profile_name]
	
	DirAccess.make_dir_recursive_absolute(profile_root)
	
	var player_profile_path = profile_root.path_join("player_profile.json")
	
	if FileAccess.file_exists(player_profile_path):
		profile = JsonResource.load_json(player_profile_path, PlayerProfile)
	else:
		profile = PlayerProfile.new()
		profile.id = UUID.v7()
		profile.name = profile.id
		var err = JsonResource.save_json(profile, player_profile_path)
		if err != OK:
			push_error("Failed to save profile %s: %s" % [player_profile_path, error_string(err)])
