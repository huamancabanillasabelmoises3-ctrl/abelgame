extends RigidBody3D

@export var impulse_strength := 10.0

func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	print(event.get_class())
	if event is InputEventScreenTouch and event.pressed:
		var dir : Vector3 = (event_position - camera.global_position).normalized()
		apply_impulse(dir * impulse_strength, event_position - global_position)
		print("Fui empujado")
