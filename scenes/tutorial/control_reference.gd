extends RefCounted
## Shared wording for contextual lessons and the complete controls guide.
const LESSONS := {
	"move": {"keys": ["W", "A", "S", "D"], "title": "练习四向移动", "detail": "分别单独按 W、A、S、D 并移动，完成全部四个方向。", "number": 1},
	"interact": {"keys": ["E"], "title": "拾取眼前的道具", "detail": "靠近道具后按 E 拾取，成功收入背包即可完成。", "number": 2},
	"attack": {"keys": ["J"], "title": "普通攻击", "detail": "按 J 挥动武器，迎击眼前的敌人。", "number": 3},
	"spell": {"keys": ["I", "J"], "title": "切换战术武器", "detail": "按 I 切换武器，再按 J 发射战术弹丸。", "number": 4},
	"dodge": {"keys": ["SPACE"], "title": "闪避攻击", "detail": "按空格向移动方向闪避，避开敌人的攻击。", "number": 5},
	"heal": {"keys": ["R"], "title": "使用生命药剂", "detail": "生命不足时按 R，消耗药剂恢复生命。", "number": 6},
	"rune": {"keys": ["F"], "title": "使用强化符文", "detail": "按 F 使用符文，暂时强化普攻与法术伤害。", "number": 7},
	"rune_pickup": {"keys": ["E"], "title": "拾取支线强化符文", "detail": "靠近眼前的强化符文按 E 拾取，再按 F 使用，暂时强化攻击。", "number": 7},
}
const GUIDE := [
	["W A S D / 方向键", "移动", "Shift 奔跑。"],
	["J", "当前武器攻击", "使用角色当前的专属武器；枪械消耗弹匣，法杖使用蓝条。"],
	["I", "切换武器", "切换0.2秒，各自保留弹匣和攻击冷却。"],
	["K", "换弹 / 补蓝", "枪械装填对应备用弹药；法杖使用星蓝药剂恢复蓝条。"],
	["L", "角色技能", "旅人补给、岚专注、铁誓盾反、星烬法阵；技能不耗能。"],
	["SPACE", "闪避", "可取消攻击后摇及换弹。"],
	["E", "交互", "拾取、开箱、购物、启动挑战与出口；角色武器不可购买或替换。"],
	["R / F / G", "道具", "生命药剂 / 强化符文 / 守护符文；道具栏支持鼠标与数字键。"],
	["P", "商城", "购买本局补给。"],
	["ENTER", "跳过教程", "结束本局教学。"],
	["ESC", "暂停", "继续游戏、查看操作或返回菜单。"],
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
