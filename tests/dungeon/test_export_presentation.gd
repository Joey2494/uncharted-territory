extends SceneTree
## 源项目和 Windows 测试包共用的界面验收，检查实物路牌及标签真实字符边界。

const DUNGEON := preload("res://scenes/dungeon/DungeonTest.tscn")
const START := "UILayer/StartScreen/Center/Card/Padding/Content/StartButton"
const GUIDE := "UILayer/RunOverlay/Corner/GuideButton"
const PROFILE := preload("res://scripts/integration/player_profile.gd")
const PROGRESS := preload("res://scripts/integration/campaign_progress.gd")
const SIGNS := {
	"Entrance": "地牢入口",
	"CourtyardEntrance": "北门封闭",
	"MainRoute": "清除中庭守卫 → 开启主路",
	"OptionalBranch": "← 支线 · 补给密室",
	"BossEntrance": "遗迹守门者",
	"BossExit": "出口封印 · 击败守门者后开启",
	"MapExit": "地牢出口 · 封印中",
}

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)


func settle_layout() -> void:
	for i in 8:
		await process_frame


## 使用 Label 实际整形后的字符边界，按字体与容器的真实宽度校验。
func check_label(label: Label, name: String) -> void:
	var right := 0.0
	var glyphs := 0
	for index in label.text.length():
		var bounds := label.get_character_bounds(index)
		if bounds.has_area():
			glyphs += 1
			right = maxf(right, bounds.end.x)
	check(label.is_visible_in_tree() and glyphs > 0 and right <= label.size.x + 2.0,
		"%s 字符右边界 %.1f，面板正文宽度 %.1f" % [name, right, label.size.x])
	check(label.get_visible_line_count() == label.get_line_count(),
		"%s 全部 %d 行可见" % [name, label.get_line_count()])


func check_signs(dungeon: Node, stage: String) -> void:
	for path in SIGNS:
		var banner := dungeon.get_node("Doorways/" + path + "/Banner") as Label3D
		check(banner.text == SIGNS[path], "%s %s 路牌应为「%s」，实际为「%s」" % [stage, path, SIGNS[path], banner.text])


## 场景再次打包时，门框实例的子节点文字仍应保留本地图的覆盖值。
func check_repacked_signs() -> void:
	var dungeon := DUNGEON.instantiate()
	var packed := PackedScene.new()
	var error := packed.pack(dungeon)
	dungeon.free()
	check(error == OK, "地牢场景可再次打包")
	if error != OK:
		return
	var cloned := packed.instantiate()
	check_signs(cloned, "重打包场景")
	cloned.free()


func run() -> void:
	var run_id := str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	PROFILE.override_path = "user://presentation-test-profile-" + run_id + ".cfg"
	PROGRESS.override_path = "user://presentation-test-progress-" + run_id + ".cfg"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://Main.tscn")
	await settle_layout()
	var first := current_scene
	check_signs(first.get_node("DungeonTest"), "主场景")
	check_repacked_signs()
	await check_guide(first, "第一关")

	change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
	await settle_layout()
	var second := current_scene
	check_label(second.get_node("UILayer/StartScreen/Center/Card/Padding/Content/Description"), "第二关菜单")
	await check_guide(second, "第二关")
	root.size = Vector2i(720, 720)
	second._boss_bar.show()
	await settle_layout()
	var camera := second.get_node("DungeonTest/Camera3D")
	var compact_frame: Rect2 = camera.get_safe_frame()
	check(compact_frame.size.y >= 0.45, "方窗为第二关战斗预留至少 45% 高度")
	second._hud.show_item_message("前厅与档案室已供能 · 演示槽内能源可按 E 取回")
	await settle_layout()
	check(camera.get_safe_frame().is_equal_approx(compact_frame), "临时提示不会改变窄窗战斗取景")
	print("EXPORT_PRESENTATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)


## 整合版通过设置打开可滚动的操作指南，检查实际可见的按键说明。
func check_guide(host: Node, title: String) -> void:
	host.get_node(START).pressed.emit()
	host.get_node(GUIDE).pressed.emit()
	var settings: Control = host.get_node("MenuNavigation").settings_screen
	settings.get_node("%ControlsGuideButton").pressed.emit()
	await settle_layout()
	var guide := settings.get_node("ControlsGuide")
	var first_detail := guide.find_child("Bindings", true, false).get_child(0).get_child(1).get_child(1) as Label
	check_label(first_detail, title + "操作指南")
	settings.go_back()
	settings.go_back()
