extends Node3D
class_name Soul

@export var controlled : CharacterBody3D

func _process(_delta: float) -> void:
	if controlled:
		global_transform.origin = controlled.global_transform.origin
