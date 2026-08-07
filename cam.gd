extends Camera3D

@onready var aim : Node3D = get_parent().get_parent()
@onready var aim2 : Node3D = aim.get_parent()
@export var sense : float = 0.01
@export var limit : float = PI/2

func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag = -event.relative * sense
		aim.rotation.x = clamp(aim.rotation.x + drag.y,-limit,limit)
		aim2.rotate_y(drag.x)
