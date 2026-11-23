extends "res://tests/scenes/character_skill_consistency_tests.gd"
## 实际角色选择机制窗口，避免扩大到不相关的角色动作换绑回归。
func run() -> void:
	PROFILE.override_path = "res://.godot/review-mechanics-profile.cfg"
	PROGRESS.override_path = "res://.godot/review-mechanics-progress.cfg"
	PROFILE.set_coins(1000)
	for id in ["lan","iron","astra"]: PROFILE.unlock_character(id)
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host=current_scene
	await preview_roles()
	await finish()
