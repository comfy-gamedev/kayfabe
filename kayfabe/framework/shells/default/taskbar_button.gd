class_name TaskbarButton
extends Button

var app_window: AppWindow 

# Called when the node enters the scene tree for the first time.
func _ready():
	text = app_window.frame.title
	app_window.closing_window.connect(_on_window_closed)
	app_window.minimizing_window.connect(_on_window_minimized)
	button_pressed = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_window_minimized():
	button_pressed = false
	
func _on_window_closed():
	queue_free()

func _on_toggled(toggled_on):
	if toggled_on:
		app_window.visible = true
		app_window.bring_to_front()
	elif button_group.get_pressed_button() == null:
		app_window.minimize()
