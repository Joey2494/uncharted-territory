extends RefCounted
## Shared wording for contextual lessons and the complete controls guide.
const LESSONS := {
	"move": {"keys": ["W", "A", "S", "D"], "title": "练习四向移动", "detail": "分别单独按 W、A、S、D 并移动，完成全部四个方向。", "number": 1},
	"interact": {"keys": ["E"], "title": "拾取眼前的道具", "detail": "靠近道具后按 E 拾取，成功收入背包即可完成。", "number": 2},
	"attack": {"keys": ["J"], "title": "普通攻击", "detail": "按 J 挥动武器，迎击眼前的敌人。", "number": 3},
	"spell": {"keys": ["K"], "title": "释放法术", "detail": "按 K 发射法术小球，攻击远处的敌人。", "number": 4},
	"dodge": {"keys": ["SPACE"], "title": "闪避攻击", "detail": "按空格向移动方向闪避，避开敌人的攻击。", "number": 5},
	"heal": {"keys": ["R"], "title": "使用生命药剂", "detail": "生命不足时按 R，消耗药剂恢复生命。", "number": 6},
	"rune": {"keys": ["F"], "title": "使用强化符文", "detail": "按 F 使用符文，暂时强化普攻与法术伤害。", "number": 7},
}
const GUIDE := [
	["W A S D / ↑ ↓ ← →", "移动", "沿对应方向移动，探索遗迹。"],
	["SHIFT + 方向键", "奔跑", "按住 Shift 加快移动。"],
	["J / 鼠标左键", "普通攻击", "挥动武器攻击近处的敌人。"],
	["K / Q", "法术小球", "发射法术小球；冷却结束后可再次释放。"],
	["SPACE", "闪避", "向移动方向闪避；静止时沿面朝方向闪避。"],
	["E", "拾取 / 交互", "靠近补给、符文台或宝箱后交互。"],
	["R", "生命药剂", "生命不足且持有药剂时使用，恢复生命。"],
	["F", "强化符文", "持有符文时使用，暂时提升攻击伤害。"],
	["ENTER", "跳过教程", "结束本局全部新手教学；游戏中可用。"],
	["ESC", "暂停 / 返回", "暂停游戏、继续游戏，或返回上一级菜单。"],
]

static func keycap(text: String, font_size: int = 28) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(42 if text.length() == 1 else 100, 48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("28251dcc")
	style.border_color = Color("a58a50")
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f1dba2"))
	panel.add_child(label)
	return panel
