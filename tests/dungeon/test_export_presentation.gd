extends SceneTree
## 源项目和 Windows 测试包共用的界面验收，检查实物路牌及标签真实字符边界。

const DUNGEON := preload("res://scenes/dungeon/DungeonTest.tscn")
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
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://Main.tscn")
	await settle_layout()
	var first := current_scene
	check_signs(first.get_node("DungeonTest"), "主场景")
	check_repacked_signs()
	first.get_node("UILayer/StartScreen/Center/Card/Padding/Content/StartButton").pressed.emit()
	first.get_node("UILayer/RunOverlay/Corner/GuideButton").pressed.emit()
	await settle_layout()
	check_label(first.get_node("UILayer/RunOverlay/Modal/Center/Card/Content/Body"), "第一关指引")
	first.close_guide()

	change_scene_to_file("res://tests/scenes/Level02Preview.tscn")
	await settle_layout()
	var second := current_scene
	check_label(second.get_node("%OverlayBody"), "第二关菜单")
	second.get_node("%Primary").pressed.emit()
	second.get_node("%GuideButton").pressed.emit()
	await settle_layout()
	check_label(second.get_node("UI/Overlay/Center/Modal/Content/GuideDetails/SealRule"), "第二关区域指引")
	second.close_guide()
	print("EXPORT_PRESENTATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
