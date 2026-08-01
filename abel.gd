extends CharacterBody3D

@onready var aim: Node3D = $"../Aim"

const SPEED := 8.0
const JUMP_VELOCITY := 12.0
const MASS := 2.0
const ROTATION_SPEED := 0.4


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement()
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * MASS * delta


func _handle_jump() -> void:
	if Input.is_action_pressed("gm_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY


func _handle_movement() -> void:
	var input := Input.get_vector("gm_left", "gm_right", "gm_up", "gm_down")

	if input == Vector2.ZERO:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		return

	var abasis := aim.global_transform.basis
	var direction := (abasis * Vector3(input.x, 0.0, input.y)).normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	var target_rotation := Quaternion(Basis.looking_at(direction))
	quaternion = quaternion.slerp(target_rotation, ROTATION_SPEED)
