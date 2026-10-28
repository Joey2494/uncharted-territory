extends CharacterBody3D

## 张宏伟独立测试场景用的简易玩家（仅验证门逻辑与传送用）
## WASD 移动；正式玩家由俞吉依在 scenes/player 下实现

const SPEED: float = 6.0


func _physics_process(_delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	var dir := Vector3(input.x, 0.0, -input.y).normalized()
	velocity = dir * SPEED
	move_and_slide()
