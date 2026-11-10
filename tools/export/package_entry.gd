extends Node
## 导出模板不接受 --script；测试包只允许白名单自检，不接受外部脚本路径。
const SUITES := ["test_secret_door", "test_room_progress", "test_gate_lifecycle",
	"test_gate_integration", "test_tutorial", "test_level02_layout",
	"test_energy_relay", "test_level02_integration", "test_level02_navigation",
	"test_campaign_flow"]

func _ready() -> void:
	_launch.call_deferred()

func _launch() -> void:
	var tree := get_tree()
	var args := OS.get_cmdline_user_args()
	if not args.has("--week09-test"):
		var error := tree.change_scene_to_file("res://Main.tscn")
		if error != OK:
			push_error("无法加载第一关：%s" % error)
			tree.quit(1)
		return
	var index := args.find("--week09-test") + 1
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
