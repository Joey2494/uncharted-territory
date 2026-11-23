extends Control
const CATALOG = preload("res://scenes/player/character_catalog.gd")
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
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	%MechanicsButton.pressed.connect(_show_mechanics)
	%CloseMechanicsButton.pressed.connect(_close_mechanics)
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
	%SkillIcon.texture = ability.icon
	%SkillTitleRow.tooltip_text = "%s\n%s\n初始能量 %d" % [ability.name, ability.description, int(data.energy)]
	%SkillCooldown.text = CATALOG.cooldown_text(id)
	%MechanicsTitle.text = dossier.name + " · 机制说明"
	%MechanicsText.text = DOSSIERS.mechanics_text(id)
	%InfoScroll.scroll_vertical = 0
	%ActionLabel.text = "外观动作预览 · " + {"knight":"剑盾演示", "lan":"双刃演示", "iron":"举盾演示", "astra":"施法演示"}[id]
	%ConfirmButton.disabled = not owned
	%UnlockButton.visible = not owned
	%UnlockButton.text = "解锁角色 · %d 金币" % PROFILE.PRICES.get(id, 0)
	%UnlockButton.disabled = PROFILE.coins < int(PROFILE.PRICES.get(id, 0))
	%StatusLabel.text = "已解锁 · 可出征" if owned else "角色未解锁 · 持有金币 %d" % PROFILE.coins
	%PreviewStage.show_character(id)
	_sync_action_focus()
	_queue_layout()

func _show_mechanics() -> void:
	%MechanicsScroll.scroll_vertical = 0
	%MechanicsOverlay.show()
	%CloseMechanicsButton.grab_focus()

func _close_mechanics() -> void:
	%MechanicsOverlay.hide()
	if is_visible_in_tree(): %MechanicsButton.grab_focus()

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
	if not is_visible_in_tree():
		return
	if %MechanicsOverlay.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_mechanics()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			%MechanicsScroll.scroll_vertical += -64 if event.is_action_pressed("ui_up") else 64
		elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			get_viewport().set_input_as_handled()
			if %CloseMechanicsButton.has_focus():
				%MechanicsScroll.grab_focus()
			else:
				%CloseMechanicsButton.grab_focus()
		return
	if event.is_echo(): return
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
	if not active: %MechanicsOverlay.hide()
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
	var info_width := size.x - margin*2 if portrait else clampf(size.x*0.34,320,440)
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
	var details_size := Vector2(minf(760,size.x-40),minf(700,size.y-40))
	_place(%MechanicsPanel,(size-details_size)*0.5,details_size)

func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
