extends Control
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const WEAPONS = preload("res://scenes/weapons/weapon_catalog.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const DOSSIERS = preload("res://scenes/ui/character_dossiers.gd")
const STAT_RANGES = preload("res://scenes/ui/character_stat_ranges.gd")
signal character_confirmed(character_id: StringName)
signal character_purchased
signal back_requested
var _index := 0
var _confirm_sent := false
var _layout_pending := false

func _ready() -> void:
	PROFILE.events.changed.connect(func(_balance: int) -> void:
		if is_visible_in_tree(): _refresh())
	var edge_shader := Shader.new()
	edge_shader.code = "shader_type canvas_item; void fragment() { vec4 scene = texture(TEXTURE, UV); float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.10, 1.0-UV.x) * smoothstep(0.0, 0.10, UV.y) * smoothstep(0.0, 0.14, 1.0-UV.y); COLOR = vec4(scene.rgb, scene.a * edge); }"
	var edge_material := ShaderMaterial.new()
	edge_material.shader = edge_shader
	$Preview.material = edge_material
	resized.connect(_queue_layout)
	%PreviousButton.pressed.connect(_cycle.bind(-1))
	%NextButton.pressed.connect(_cycle.bind(1))
	%ConfirmButton.pressed.connect(_confirm)
	%UnlockButton.pressed.connect(_purchase)
	%SkillJump.pressed.connect(func() -> void: _jump_to(%SkillTitleRow))
	%WeaponsJump.pressed.connect(func() -> void: _jump_to(%WeaponSection))
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	visibility_changed.connect(_update_preview)
	_update_preview()
	_queue_layout()

func show_selection(id: String = "knight") -> void:
	_index = maxi(0, CATALOG.IDS.find(id))
	_confirm_sent = false
	show()
	_refresh()
	_focus_action.call_deferred(true)

func get_selected_id() -> String:
	return CATALOG.IDS[_index]

func show_confirmation_error(message: String) -> void:
	_confirm_sent = false
	%StatusLabel.text = message

func _cycle(direction: int) -> void:
	if not is_visible_in_tree() or _confirm_sent:
		return
	_index = posmod(_index + direction, CATALOG.IDS.size())
	_refresh()

func _refresh() -> void:
	var id := get_selected_id()
	var data: Dictionary = CATALOG.definition(id)
	var ability := CATALOG.ability_definition(id)
	var dossier: Dictionary = DOSSIERS.entry(id)
	var owned := PROFILE.owns(id)
	%CharacterName.text = dossier.name
	%CharacterDescription.text = dossier.summary
	%RoleLabel.text = dossier.role
	var baseline: Dictionary = CATALOG.definition("knight")
	var stat_cards := {"attack": %AttackStat,"hp": %HealthStat,"shield": %ShieldStat,"speed": %SpeedStat}
	for attribute: String in stat_cards:
		stat_cards[attribute].set_stat(STAT_RANGES.value_for(data,attribute),STAT_RANGES.maximum_for(attribute),STAT_RANGES.value_for(baseline,attribute))
	%SpeedStat.tooltip_text += "\n疾跑速度：%.1f 米/秒" % data.run
	%CharacterCounter.text = "%02d / %02d" % [_index + 1, CATALOG.IDS.size()]
	%SkillName.text = ability.name
	%SkillDescription.text = _highlight_stat_values(ability.description)
	%PassiveDescription.text = _highlight_stat_values(ability.passive_description)
	_refresh_weapons(id)
	%SkillIcon.texture = ability.icon
	%SkillTitleRow.tooltip_text = "%s\n%s\n初始法力 %d" % [ability.name, ability.description, int(data.energy)]
	%SkillCooldown.text = _highlight_stat_values("冷却 %s 秒" % CATALOG.seconds(ability.cooldown)) if ability.active else "无独立主动技能"
	%InfoScroll.scroll_vertical = 0
	%ActionLabel.text = {"knight":"沉身蓄力 · 破势斜斩", "lan":"移动瞄准 · 专注射击", "iron":"迅捷举盾 · 沉劲重击", "astra":"蓝光流转 · 奥术凝聚"}[id]
	%ConfirmButton.disabled = not owned
	%UnlockButton.visible = not owned
	%UnlockButton.text = "解锁角色 · %d 金币" % PROFILE.PRICES.get(id, 0)
	%UnlockButton.disabled = PROFILE.coins < int(PROFILE.PRICES.get(id, 0))
	%StatusLabel.text = "已解锁 · 可出征" if owned else "角色未解锁 · 持有金币 %d" % PROFILE.coins
	%PreviewStage.show_character(id)
	_sync_action_focus()
	_queue_layout()

func _sync_action_focus() -> void:
	for button: Button in [%ConfirmButton, %UnlockButton]:
		var available := button.visible and not button.disabled
		if not available and button.has_focus(): button.release_focus()
		button.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	_focus_action.call_deferred()

func _focus_action(force_default: bool = false) -> void:
	if not is_visible_in_tree() or _confirm_sent: return
	var current := get_viewport().gui_get_focus_owner()
	# Preserve usable navigation focus when refreshing or browsing characters.
	if not force_default and current != null and is_ancestor_of(current) and current.is_visible_in_tree() \
		and not (current is BaseButton and current.disabled):
		return
	var target: Button = %BackButton
	if not %ConfirmButton.disabled:
		target = %ConfirmButton
	elif %UnlockButton.visible and not %UnlockButton.disabled:
		target = %UnlockButton
	target.grab_focus()

func _purchase() -> void:
	if not is_visible_in_tree() or _confirm_sent:
		return
	if PROFILE.unlock_character(get_selected_id()):
		character_purchased.emit()
		_focus_action.call_deferred(true)
	_refresh()
	if not PROFILE.message.is_empty():
		%StatusLabel.text = PROFILE.message

func _confirm() -> void:
	if not is_visible_in_tree() or _confirm_sent or not PROFILE.owns(get_selected_id()):
		return
	_confirm_sent = true
	character_confirmed.emit(StringName(get_selected_id()))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo():
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_cycle(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_cycle(1)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()

func _update_preview() -> void:
	if not is_node_ready():
		return
	var active := is_visible_in_tree()
	%PreviewViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	%PreviewStage.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _queue_layout() -> void:
	if _layout_pending: return
	_layout_pending = true
	_layout_page.call_deferred()

func _layout_page() -> void:
	_layout_pending = false
	var portrait := size.y > size.x * 1.25
	var margin := 28.0 if size.x < 1000 else 64.0
	var info_width := size.x - margin*2 if portrait else clampf(size.x*0.40,320,520)
	var panel_top := 110.0
	var panel_height := minf(560,maxf(532,size.y*0.42)) if portrait else size.y-panel_top-84
	%CharacterName.add_theme_font_size_override("font_size",30 if size.x < 1000 else 32)
	_place(%Eyebrow,Vector2(margin,28),Vector2(size.x-margin*2,20))
	_place(%TitleLabel,Vector2(margin,56),Vector2(info_width,42))
	_place(%InfoStone,Vector2(margin,panel_top),Vector2(info_width,panel_height))
	_place(%InfoCard,Vector2(margin,panel_top),Vector2(info_width,panel_height))
	_place(%PanelAccent,Vector2(margin+20,panel_top),Vector2(64,2))
	%UnlockButton.custom_minimum_size.y = 44
	var preview_top := panel_top+panel_height+12 if portrait else 0.0
	var preview_left := 0.0 if portrait else margin+info_width+18
	_place($Preview,Vector2(preview_left,preview_top),Vector2(size.x-preview_left,size.y-158-preview_top))
	_place(%ActionLabel,Vector2(preview_left,size.y-160),Vector2(size.x-preview_left,22))
	_place(%Navigation, Vector2(size.x*0.5-132 if portrait else preview_left+(size.x-preview_left)*0.5-132, size.y-130), Vector2(264,44))
	_place(%BackButton, Vector2(margin,size.y-74), Vector2(160,44))
	var confirm_width := minf(300, size.x-margin*2-176)
	_place(%ConfirmButton, Vector2(size.x-margin-confirm_width,size.y-74), Vector2(confirm_width,44))
	_place(%HintLabel, Vector2(margin,size.y-24), Vector2(size.x-margin*2,20))

func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions

func _jump_to(section: Control) -> void:
	%InfoScroll.scroll_vertical = roundi(section.position.y)

func _refresh_weapons(id: String) -> void:
	for old in %WeaponCards.get_children():
		%WeaponCards.remove_child(old)
		old.queue_free()
	for index in 2:
		var weapon_id: String = WEAPONS.LOADOUTS[id][index]
		var data: Dictionary = WEAPONS.definition(weapon_id)
		var card := PanelContainer.new()
		card.name = weapon_id
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var style := StyleBoxEmpty.new()
		style.content_margin_top = 8
		style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel",style)
		%WeaponCards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",6)
		content.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(content)
		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_constant_override("separation",10)
		content.add_child(header)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/weapons/icons/"+weapon_id+".svg")
		icon.custom_minimum_size = Vector2(34,34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon)
		var title := Label.new()
		title.text = ("主武器 · " if index == 0 else "备用武器 · ")+data.name
		title.add_theme_font_size_override("font_size",16)
		title.add_theme_color_override("font_color",Color("ead39e"))
		header.add_child(title)
		var description := RichTextLabel.new()
		description.name = "WeaponDescription"
		description.bbcode_enabled = true
		description.fit_content = true
		description.scroll_active = false
		description.text = _highlight_stat_values(WEAPONS.description(weapon_id,id))
		description.add_theme_font_size_override("normal_font_size",14)
		description.add_theme_color_override("default_color",Color("e5c17c"))
		description.add_theme_constant_override("line_separation",3)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(description)

func _highlight_stat_values(value: String) -> String:
	# Actual attributes use the summary's gray; calculation factors stay gold.
	var numbers := RegEx.new()
	numbers.compile("[0-9]+(?:\\.[0-9]+)?(?:%|°)?")
	var calculation := RegEx.new()
	calculation.compile("(?:÷|除以|×|乘以)\\s*$")
	var ordinals := RegEx.new()
	ordinals.compile("第\\s*[0-9]+(?:\\s*/\\s*[0-9]+)*\\s*秒")
	var ordinal_spans := ordinals.search_all(value)
	var output := ""
	var cursor := 0
	for number in numbers.search_all(value):
		var start: int = number.get_start()
		var end: int = number.get_end()
		var explanatory := calculation.search(value.left(start)) != null
		for span in ordinal_spans:
			if start >= span.get_start() and end <= span.get_end(): explanatory = true
		output += value.substr(cursor,start-cursor)
		output += number.get_string() if explanatory else "[color=#b3b3a6]"+number.get_string()+"[/color]"
		cursor = end
	return output+value.substr(cursor)
