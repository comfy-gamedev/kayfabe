@tool
extends EditorScript

#const SIZE = Vector2(16, 16)
const MODES = ["normal", "pressed", "hover", "disabled"]

# Titlebar buttons
#const ORIGIN = Vector2(64, 48)
#const BUTTONS = ["Minimize", "Close", "Maximize", "Smile"]

# User buttons
#const SIZE = Vector2(16, 16)
#const ORIGIN = Vector2(64, 0)
#const BUTTONS = ["User"]
const SIZE = Vector2(22, 16)
const ORIGIN = Vector2(64, 16)
const BUTTONS = ["UserLast"]

# Arrow buttons
#const ORIGIN = Vector2(128, 48)
#const BUTTONS = ["Left", "Right", "Down", "Up"]

# Called when the script is executed (using File -> Run in Script Editor).
func _run() -> void:
	var theme: Theme = load("res://themes/cyberfire/theme.tres")
	var texture: Texture2D = load("res://themes/cyberfire/cyberfire_icons.png")
	
	assert(theme)
	assert(texture)
	
	var p = ORIGIN
	for button in BUTTONS:
		var type = StringName("AppWindow%sButton" % button)
		
		if type not in theme.get_type_list():
			theme.add_type(type)
			theme.set_type_variation(type, "Button")
		
		p.x = ORIGIN.x
		for mode in MODES:
			var sbt: StyleBoxTexture
			if not theme.has_stylebox(mode, type):
				sbt = StyleBoxTexture.new()
				theme.set_stylebox(mode, type, sbt)
			else:
				var sb = theme.get_stylebox(mode, type)
				if sb is StyleBoxTexture:
					sbt = sb
			if sbt:
				sbt.texture = texture
				sbt.region_rect = Rect2(p, SIZE)
			p.x += SIZE.x
			if sbt.resource_path:
				ResourceSaver.save(sbt)
		p.y += SIZE.y
	
	ResourceSaver.save(theme)
