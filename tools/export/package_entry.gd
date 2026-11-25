extends Node
## 导出模板不接受 --script；测试包只允许白名单自检，不接受外部脚本路径。
const SUITES := ["test_secret_door", "test_room_progress", "test_gate_lifecycle",
	"test_gate_integration", "test_level02_layout",
	"test_energy_relay", "test_level02_integration", "test_level02_navigation", "test_level02_spawn",
	"test_campaign_flow", "test_export_presentation", "capture_campaign",
	"test_level04_routes", "test_level04_combat", "test_level04_camera_run", "test_level04_menu",
	"test_level04_geometry", "test_level04_instruments", "test_level04_dome_visibility", "test_level04_campaign",
	"test_level04_campaign_routes"]

func _ready() -> void:
	_launch.call_deferred()

func _launch() -> void:
	var tree := get_tree()
	var args := OS.get_cmdline_user_args()
	var suite_flag := "--observatory-test" if args.has("--observatory-test") else "--week09-test"
	if not args.has(suite_flag):
		var scene := "res://scenes/dungeon/Level04Practice.tscn" if args.has("--observatory") else "res://scenes/ui/LoadingEntry.tscn"
		var error := tree.change_scene_to_file(scene)
		if error != OK:
			push_error("无法加载 %s（%s）" % [scene, error_string(error)])
			tree.quit(1)
		return
	var index := args.find(suite_flag) + 1
	if index >= args.size() or (args[index] != "smoke" and not args[index] in SUITES):
		push_error("无效的测试包自检名称")
		tree.quit(2)
		return
	var path := "res://tools/export/package_smoke.gd" if args[index] == "smoke" else "res://tests/dungeon/%s.gd" % args[index]
	var script := load(path) as Script
	if script == null:
		push_error("测试资源加载失败：" + path)
		tree.quit(2)
		return
	# 复用源码的 SceneTree 验收脚本，避免维护两套断言。先移除启动场景。
	tree.current_scene = null
	queue_free()
	tree.set_script(script)
	tree.call("_initialize")
