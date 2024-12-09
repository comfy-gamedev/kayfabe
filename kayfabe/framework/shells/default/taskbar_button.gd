class_name TaskbarButton
extends Button

var app_window: AppWindow 

# Called when the node enters the scene tree for the first time.
func _ready():
	text = app_window.frame.title

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
